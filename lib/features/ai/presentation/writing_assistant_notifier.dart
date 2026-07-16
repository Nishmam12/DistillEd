// Holds the current Writing Assistant suggestions for one page.
//
// It has NO timer of its own: it is fed the already-extracted page content by
// the Context Engine's debounced pass (see [ContextEngineNotifier.onContent]),
// so there is exactly one debounce driving both features — never a second
// polling loop. Only TYPED text is reviewed. Failures are quiet (advisory
// feature: show no suggestions rather than a red error).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/features/writing_assistant.dart';
import '../domain/page_content.dart';

/// Session cache of the last suggestions per page, keyed by the typed-text
/// signature they were computed from — so switching away and back is instant
/// (durable persistence belongs to Phase 2's Learning Memory).
class PageWritingCache {
  final _entries =
      <int, ({String signature, List<WritingSuggestion> suggestions})>{};

  ({String signature, List<WritingSuggestion> suggestions})? find(int pageId) =>
      _entries[pageId];

  void save(int pageId, String signature, List<WritingSuggestion> suggestions) =>
      _entries[pageId] = (signature: signature, suggestions: suggestions);
}

class WritingAssistantNotifier extends StateNotifier<List<WritingSuggestion>> {
  final WritingAssistant _assistant;
  final PageWritingCache _cache;
  final int _pageId;

  /// The typed text (which is itself the signature) of the last review.
  String? _lastSignature;
  bool _running = false;
  PageContent? _pending;

  WritingAssistantNotifier({
    required WritingAssistant assistant,
    required PageWritingCache cache,
    required int pageId,
  })  : _assistant = assistant,
        _cache = cache,
        _pageId = pageId,
        super(const []) {
    final cached = _cache.find(pageId);
    if (cached != null) {
      _lastSignature = cached.signature;
      state = cached.suggestions;
    }
  }

  /// Fed by the Context Engine's debounced onContent. Reviews only the typed
  /// text; skips when it hasn't changed since the last review.
  void review(PageContent content) {
    final signature = content.typedText.trim();
    if (signature == _lastSignature) return;
    if (_running) {
      _pending = content;
      return;
    }
    unawaited(_run(content, signature));
  }

  Future<void> _run(PageContent content, String signature) async {
    _running = true;
    _lastSignature = signature;
    try {
      final suggestions = await _assistant.review(content.typedText);
      _cache.save(_pageId, signature, suggestions);
      if (mounted) state = suggestions;
    } catch (_) {
      // Advisory: a model/parse failure means "no suggestions", never an error
      // banner. Cache the empty result so it isn't retried until content changes.
      _cache.save(_pageId, signature, const []);
      if (mounted) state = const [];
    } finally {
      _running = false;
      final pending = _pending;
      _pending = null;
      if (pending != null) review(pending);
    }
  }

  /// Removes one suggestion the user dismissed. A later content change can
  /// legitimately re-raise it.
  void dismiss(WritingSuggestion suggestion) {
    state = [
      for (final s in state)
        if (!identical(s, suggestion)) s,
    ];
  }
}
