// Drives one Research request into the sidebar (Phase 3, Loop 3.4):
//   idle → composing → [confirmCloud → (confirm)] → streaming(toolsUsed) → ready
//            ↘ unavailable (privacy is localOnly — no local fallback exists
//              for tool calling this loop)
//            ↘ error(message, retryable)
//
// `composing` mirrors `ask_notes_notifier.dart`'s open-query-box step (a
// state, not a UI flag, so the sidebar's body-swap keys off `state is!
// ResearchIdle` the same way it does for Ask/Explain). The confirm-cloud gate
// mirrors `explain_notifier.dart` — same "never silently send to cloud" rule,
// same first-ever-call messaging — but Research has no local route at all,
// so there is no download/local-retry branch, and every request is
// cloud-mid (never frontier, never local).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart' show CloudPrivacy;
import '../domain/ai_provider.dart' show AiException;
import '../domain/features/researcher.dart';

sealed class ResearchState {
  const ResearchState();
}

class ResearchIdle extends ResearchState {
  const ResearchIdle();
}

/// The query box is open, awaiting a question — nothing asked yet.
class ResearchComposing extends ResearchState {
  const ResearchComposing();
}

/// Paused before a cloud call, waiting on the user to confirm or cancel —
/// every Research request needs this gate, since there is no local route.
class ResearchConfirmCloud extends ResearchState {
  final bool isFirstEver;
  const ResearchConfirmCloud({required this.isFirstEver});
}

class ResearchStreaming extends ResearchState {
  final String text;
  final List<String> toolsUsed;
  const ResearchStreaming(this.text, {this.toolsUsed = const []});
}

class ResearchReady extends ResearchState {
  final String text;
  final List<String> toolsUsed;
  const ResearchReady(this.text, {this.toolsUsed = const []});
}

class ResearchError extends ResearchState {
  final String message;
  final bool retryable;
  const ResearchError(this.message, {this.retryable = true});
}

/// Privacy is `localOnly` — Research has no on-device fallback this loop
/// (see `researcher.dart`'s header), so it reports itself unavailable
/// rather than silently answering without tool access.
class ResearchUnavailable extends ResearchState {
  const ResearchUnavailable();
}

class ResearchNotifier extends StateNotifier<ResearchState> {
  final Researcher _researcher;
  final CloudPrivacy Function() _privacy;
  final bool Function() _hasSeenFirstCloudCall;
  final Future<void> Function() _markFirstCloudCallSeen;

  ResearchNotifier({
    required Researcher researcher,
    required CloudPrivacy Function() privacy,
    bool Function()? hasSeenFirstCloudCall,
    Future<void> Function()? markFirstCloudCallSeen,
  })  : _researcher = researcher,
        _privacy = privacy,
        _hasSeenFirstCloudCall = hasSeenFirstCloudCall ?? (() => true),
        _markFirstCloudCallSeen = markFirstCloudCallSeen ?? (() async {}),
        super(const ResearchIdle());

  String? _lastQuestion;
  bool _running = false;
  StreamSubscription<ResearchEvent>? _sub;
  Completer<void>? _completer;

  /// Opens the query box (footer "Research" chip). No-op mid-run.
  void startComposing() {
    if (!_running) state = const ResearchComposing();
  }

  /// [cloudConfirmed] skips the confirm gate — set only by
  /// [confirmCloudAndAsk], after the user has already said yes once for this
  /// specific question.
  Future<void> ask(String question, {bool cloudConfirmed = false}) async {
    if (_running) return;
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    _lastQuestion = trimmed;

    if (_privacy() == CloudPrivacy.localOnly) {
      state = const ResearchUnavailable();
      return;
    }

    if (!cloudConfirmed) {
      state = ResearchConfirmCloud(isFirstEver: !_hasSeenFirstCloudCall());
      return;
    }

    _running = true;
    final buffer = StringBuffer();
    final toolsUsed = <String>[];
    state = const ResearchStreaming('');

    // A `.listen()` (rather than `await for`) so a long, multi-hop research
    // run can be abandoned mid-stream: `stop()`/`reset()` cancel [_sub] and
    // complete [_completer], which nothing outside an `await for` loop could
    // do. A hop is a full cloud round-trip plus a tool call, up to three of
    // them, so "wait for it to finish" is not an acceptable only-exit.
    final completer = Completer<void>();
    _completer = completer;
    _sub = _researcher.research(trimmed).listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case ResearchTextChunk(:final text):
            buffer.write(text);
          case ResearchToolUsed(:final toolName):
            if (!toolsUsed.contains(toolName)) toolsUsed.add(toolName);
        }
        state = ResearchStreaming(buffer.toString(),
            toolsUsed: List.unmodifiable(toolsUsed));
      },
      onError: (Object e) {
        if (mounted) state = _mapError(e);
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (mounted) {
          final text = buffer.toString().trim();
          state = text.isEmpty
              ? const ResearchError(
                  "The model didn't return an answer. Try again.")
              : ResearchReady(text, toolsUsed: List.unmodifiable(toolsUsed));
        }
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
    _sub = null;
    _completer = null;
    _running = false;
  }

  /// The user said yes on [ResearchConfirmCloud].
  Future<void> confirmCloudAndAsk() async {
    final question = _lastQuestion;
    if (question == null || _running) return;
    await _markFirstCloudCallSeen();
    await ask(question, cloudConfirmed: true);
  }

  /// The user said no on [ResearchConfirmCloud] — back to idle, nothing sent.
  void cancelCloud() {
    if (!_running) state = const ResearchIdle();
  }

  /// Re-runs the last question — goes through the confirm gate again rather
  /// than skipping it, same as [ExplainNotifier.retry]: a retry is still a
  /// new network call, not a continuation of an already-confirmed one.
  Future<void> retry() async {
    final question = _lastQuestion;
    if (question != null && !_running) await ask(question);
  }

  /// Stops an in-flight request but keeps Research open at the query box, so
  /// the user can immediately ask something else. Works *during* streaming —
  /// the one exit a long, multi-hop research run needs.
  void stop() {
    if (!_running) return;
    _cancelInFlight();
    state = const ResearchComposing();
  }

  /// Dismisses the answer — or an in-flight stream — and returns the sidebar
  /// to its default surface. Cancels a running request too, so the Close
  /// button is never dead mid-stream.
  void reset() {
    _cancelInFlight();
    state = const ResearchIdle();
  }

  /// Abandons the in-flight research stream and clears the run flag.
  ///
  /// Deliberately does NOT await `subscription.cancel()`. Cancelling a
  /// subscription to an `async*` parked in an `await for` (which both
  /// [Researcher.research] and the gateway's `generateWithTools` are) doesn't
  /// complete its cancel future until the inner stream next emits or closes —
  /// so awaiting it would hang the UI during a cold start, the exact moment a
  /// user most wants out. `cancel()` still stops event delivery immediately
  /// (no `onData`/`onDone` fires afterward), so state can move on now; the
  /// underlying request unwinds and aborts via its `CancelToken` when the next
  /// byte arrives or the socket closes.
  void _cancelInFlight() {
    _sub?.cancel();
    _sub = null;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    _running = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  ResearchState _mapError(Object e) {
    return switch (e) {
      AiException(:final message) => ResearchError(message),
      _ => const ResearchError('Something went wrong while researching.'),
    };
  }
}
