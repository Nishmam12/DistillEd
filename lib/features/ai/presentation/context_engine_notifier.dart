// Debounced live analysis of the page being edited.
//
// Trigger: the editor's scene state, observed read-only through a listener in
// the provider wiring (ai_providers.dart) — the editor itself is never
// touched. Analysis runs [debounce] after the last change, is skipped when
// the page's content signature hasn't changed, and the last successful
// [PageContext] is cached per page (in [PageContextCache]) so switching away
// and back is instant. Persistence of contexts belongs to Phase 2's Learning
// Memory — this cache is session-lifetime only.
//
// Cost control: the provider that owns this notifier is autoDispose, so the
// engine analyzes only while something (the AI sidebar) is actually watching.
// Pages with no readable content short-circuit to [PageContext.empty] without
// touching recognition or the model.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/model/scene_element.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../domain/context_engine/context_engine.dart';
import '../domain/context_engine/page_context.dart';
import '../domain/page_content.dart';
import '../domain/page_content_extractor.dart';

/// Session-lifetime cache of the last successful analysis per page, keyed by
/// the content signature it was computed from.
class PageContextCache {
  final _entries = <int, ({String signature, PageContext context})>{};

  ({String signature, PageContext context})? find(int pageId) =>
      _entries[pageId];

  void save(int pageId, String signature, PageContext context) =>
      _entries[pageId] = (signature: signature, context: context);
}

/// Cheap change detector over a page's elements: which content-bearing
/// elements exist and what text-bearing state they carry. Pure geometry moves
/// don't change what the engine would read (recognition is
/// translation-invariant; deliberate tradeoff), so they don't invalidate —
/// text edits, stroke add/remove, and text reordering do.
String sceneContentSignature(List<SceneElement> elements) {
  final parts = <String>[];
  for (final e in elements) {
    if (e is FreehandElement) {
      if (e.isEraser || e.points.isEmpty) continue;
      parts.add('f:${e.id}:${e.points.length}');
    } else if (e is TextElement) {
      if (e.text.trim().isEmpty) continue;
      // Position included because reading order feeds typedText concatenation.
      parts.add('t:${e.id}:${e.geometryData[0].round()},'
          '${e.geometryData[1].round()}:${e.text}');
    } else if (e is ImageElement) {
      parts.add('i:${e.id}');
    }
  }
  return parts.join('|');
}

class ContextEngineNotifier extends StateNotifier<AsyncValue<PageContext>> {
  final ContextEngine _engine;
  final PageContentExtractor _extractor;
  final HandwritingRecognitionService _recognition;
  final PageContextCache _cache;
  final int _pageId;

  /// Read at analysis time so a settings change applies to the next run.
  final String Function() _languageCode;

  /// Fired with the freshly extracted page content after each debounced pass
  /// (empty when the page has nothing readable). Lets a sibling feature — the
  /// Writing Assistant — run off THIS debounce and extraction instead of its
  /// own polling loop. Never allowed to break analysis (see [_notifyContent]).
  final void Function(PageContent content)? _onContent;

  /// Fired with each freshly analyzed [PageContext]. Lets Phase 2's Learning
  /// Memory record concept exposure off this same debounce — again, no second
  /// analysis loop. Never allowed to break analysis (see [_notifyContext]).
  final void Function(PageContext context)? _onContext;

  /// How long after the last scene change analysis fires. Injectable for
  /// tests; ~2.5s per the phase spec ("after the user pauses, not per stroke").
  final Duration debounce;

  Timer? _timer;
  List<SceneElement> _elements = const [];

  /// Signature of the last ATTEMPTED analysis (success or failure) — failures
  /// aren't retried until the content changes or [refresh] is called, so a
  /// missing model doesn't get hammered on every pause.
  String? _lastAttemptedSignature;

  bool _running = false;
  bool _rerunWhenDone = false;
  bool _forceNext = false;

  ContextEngineNotifier({
    required ContextEngine engine,
    required PageContentExtractor extractor,
    required HandwritingRecognitionService recognition,
    required PageContextCache cache,
    required int pageId,
    required String Function() languageCode,
    void Function(PageContent content)? onContent,
    void Function(PageContext context)? onContext,
    this.debounce = const Duration(milliseconds: 2500),
  })  : _engine = engine,
        _extractor = extractor,
        _recognition = recognition,
        _cache = cache,
        _pageId = pageId,
        _languageCode = languageCode,
        _onContent = onContent,
        _onContext = onContext,
        super(const AsyncValue.loading()) {
    final cached = _cache.find(pageId);
    if (cached != null) state = AsyncValue.data(cached.context);
  }

  /// Fed by the read-only listener on the page's scene state.
  void onSceneChanged(List<SceneElement> elements) {
    _elements = elements;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_analyzeIfChanged()));
  }

  /// Forces a re-run even when the content signature is unchanged — e.g.
  /// after the user downloads the model a failed run was missing.
  Future<void> refresh() {
    _timer?.cancel();
    _forceNext = true;
    return _analyzeIfChanged();
  }

  Future<void> _analyzeIfChanged() async {
    if (_running) {
      _rerunWhenDone = true;
      return;
    }
    final force = _forceNext;
    _forceNext = false;
    final signature = sceneContentSignature(_elements);
    if (!force && signature == _lastAttemptedSignature) return;

    final cached = _cache.find(_pageId);
    if (!force && cached != null && cached.signature == signature) {
      _lastAttemptedSignature = signature;
      if (mounted) state = AsyncValue.data(cached.context);
      return;
    }

    _running = true;
    _lastAttemptedSignature = signature;
    try {
      if (!_hasReadableContent(_elements)) {
        _cache.save(_pageId, signature, PageContext.empty);
        if (mounted) state = const AsyncValue.data(PageContext.empty);
        _notifyContent(PageContent.empty);
        return;
      }

      if (mounted) {
        state = const AsyncValue<PageContext>.loading().copyWithPrevious(state);
      }
      final language = _languageCode();
      await _recognition.ensureModelDownloaded(language);
      final content =
          await _extractor.extractPage(_pageId, languageCode: language);
      final context =
          await _engine.analyze(content, previousContext: cached?.context);
      _cache.save(_pageId, signature, context);
      if (mounted) state = AsyncValue.data(context);
      // Durable concept exposure (Phase 2 Learning Memory) — only for a real
      // analysis; the empty short-circuit above has nothing to remember.
      _notifyContext(context);
      // Fan out the already-extracted content to the Writing Assistant, off the
      // same debounce. After analysis, so the two model calls run in sequence
      // (the local runtime serialises them anyway) rather than contending.
      _notifyContent(content);
    } catch (e, st) {
      // Surfaced, not swallowed: the sidebar renders the failure kind
      // (model missing → download hint; anything else → gentle retry).
      if (mounted) {
        state = AsyncValue<PageContext>.error(e, st).copyWithPrevious(state);
      }
    } finally {
      _running = false;
      if (_rerunWhenDone) {
        _rerunWhenDone = false;
        // Content changed mid-run; the signature check decides if it matters.
        unawaited(_analyzeIfChanged());
      }
    }
  }

  /// Invokes [_onContent], swallowing any failure: the Writing Assistant is
  /// advisory and must never take down the Context Engine's analysis.
  void _notifyContent(PageContent content) {
    final onContent = _onContent;
    if (onContent == null) return;
    try {
      onContent(content);
    } catch (_) {
      // Deliberately ignored — a misbehaving sibling can't break analysis.
    }
  }

  /// Invokes [_onContext], swallowing any failure: remembering concepts is a
  /// background nicety and must never take down the page's analysis.
  void _notifyContext(PageContext context) {
    final onContext = _onContext;
    if (onContext == null) return;
    try {
      onContext(context);
    } catch (_) {
      // Deliberately ignored — see [_notifyContent].
    }
  }

  static bool _hasReadableContent(List<SceneElement> elements) =>
      elements.any((e) =>
          (e is FreehandElement && !e.isEraser && e.points.isNotEmpty) ||
          (e is TextElement && e.text.trim().isNotEmpty));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
