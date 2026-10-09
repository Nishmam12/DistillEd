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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
  /// The context the panel last showed. Loading and error states carry no value
  /// of their own, so readers fall back to this to keep the last good context
  /// on screen during a re-analysis. Riverpod 3 made copyWithPrevious internal.
  PageContext? _shown;

  /// The context to show now: the current value, or the one shown before a
  /// loading or error state replaced it.
  PageContext? get shown => state.value ?? _shown;

  /// Remembers what is on screen before a state with no value replaces it.
  void _keepShown() => _shown = state.value ?? _shown;

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

  /// Whether the heavy Gemma-vision read has run for this page yet. The first
  /// readable analysis (sidebar open) and every [refresh] (Re-read) use Gemma
  /// as the primary recogniser; edits in between use the light ML Kit path so a
  /// 2.4 GB model isn't loaded on every writing pause.
  bool _visionReadDone = false;

  ContextEngineNotifier({
    required this._engine,
    required this._extractor,
    required this._recognition,
    required this._cache,
    required int pageId,
    required this._languageCode,
    this._onContent,
    this._onContext,
    this.debounce = const Duration(milliseconds: 2500),
  })  : _pageId = pageId,
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

  /// Forces a re-run even when the content signature is unchanged — the Re-read
  /// button, and the post-download / post-error retries.
  Future<void> refresh() async {
    _timer?.cancel();
    _forceNext = true;
    // Immediate, unmistakable feedback: flip to the re-reading state the moment
    // Re-read is tapped. The loading indicator inside [_analyzeIfChanged] sits
    // BEHIND guards (a read already in flight — and a full read does two long
    // model passes — or unchanged content), so without this the tap could
    // return with nothing on screen changing at all.
    if (mounted) {
      _keepShown();
      state = const AsyncValue<PageContext>.loading();
    }
    await _analyzeIfChanged();
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
        _keepShown();
        state = const AsyncValue<PageContext>.loading();
      }
      final language = _languageCode();
      // The ink model is only needed to read handwriting. A typed-only or
      // imported page must still be read (and its text saved for search) when
      // offline with no model, so a failed download is not fatal for it.
      final hasInk = _elements.any(
          (e) => e is FreehandElement && !e.isEraser && e.points.isNotEmpty);
      try {
        await _recognition.ensureModelDownloaded(language);
      } catch (_) {
        if (hasInk) rethrow;
      }
      // Gemma vision is the primary read on first open and on every forced
      // Re-read; intermediate edits fall to the light ML Kit path.
      final useVision = force || !_visionReadDone;
      // A forced re-read of a page Gemma has ALREADY read is the user asking to
      // "read it again" — sample a fresh reading so the result can actually
      // change, rather than repeating the identical deterministic pass. The
      // first successful read (incl. after a model download) stays deterministic.
      final varyVision = force && _visionReadDone;
      final content = await _extractor.extractPage(_pageId,
          languageCode: language,
          useVision: useVision,
          varyVision: varyVision);
      _visionReadDone = true;
      final PageContext context;
      try {
        context =
            await _engine.analyze(content, previousContext: cached?.context);
      } catch (_) {
        // Analysis needs the LLM; search text does not. Hand the extracted
        // content on anyway so a missing model or an OOM cannot leave the
        // page unfindable.
        _notifyContent(content);
        rethrow;
      }
      // Answers "did this page go to the cloud?" from `adb logcat` alone.
      // Deliberately not debug-gated: this is a privacy fact about the user's
      // own notes, and a release build should be able to demonstrate it.
      debugPrint('[AiProvenance] page=$_pageId analysis ranOn=${context.ranOn.name} '
          'leftDevice=${context.ranOn.leftDevice}');
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
      // Debug-only: diagnosing the on-device validation pass (2026-07-18) —
      // remove once the STOP CONDITION investigation wraps up.
      if (kDebugMode) {
        debugPrint('[ContextEngine] analyze FAILED (page=$_pageId): '
            '${e.runtimeType}: $e\n$st');
      }
      // Surfaced, not swallowed: the sidebar renders the failure kind
      // (model missing → download hint; anything else → gentle retry).
      if (mounted) {
        _keepShown();
        state = AsyncValue<PageContext>.error(e, st);
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
          (e is TextElement && e.text.trim().isNotEmpty) ||
          // An imported PDF page or photo is readable too: the extractor OCRs
          // it. Without this an image-only page short-circuits to empty here,
          // before the extractor runs — which is why the insights panel stayed
          // blank on imported pages even though OCR worked when called directly.
          (e is ImageElement && e.relativeImagePath.isNotEmpty));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
