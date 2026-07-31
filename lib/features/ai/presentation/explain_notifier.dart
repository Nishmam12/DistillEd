// Drives one Explain request into the sidebar:
//   idle → preparing → [confirmCloud → (confirm)] → streaming(partial) → ready(full)
//            ↘ downloadingModel(progress) → (re-run) …
//            ↘ error(message, retryable, offerModelDownload)
//
// Content is resolved lazily (a selection extraction, or a knowledge-gap term)
// so a retry re-reads it; the streamed reply accumulates into the state so the
// view can render live token output. The LLM download is never silent — a
// missing model surfaces as an error offering the (explicit) download.
//
// Phase 3: when Explain is wired to a [RoutedAiProvider] (see
// `ai_providers.dart`), [evaluateCloudRoute] lets this notifier pause on
// [ExplainConfirmCloud] before the network call, rather than the routing
// decision being invisible inside the provider — "never silently send to
// cloud" has to be enforced here, at the one place that can show UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/llm_exceptions.dart';
import '../data/llm/model_download_manager.dart';
import '../domain/ai_provider.dart';
import '../domain/features/explainer.dart';
import '../domain/quality/ai_quality_guard.dart';
import '../domain/routing/intelligent_router.dart' show CloudRouteDecision, CloudTier;

sealed class ExplainState {
  const ExplainState();
}

class ExplainIdle extends ExplainState {
  const ExplainIdle();
}

/// Resolving the passage to explain (e.g. reading the selected notes).
class ExplainPreparing extends ExplainState {
  const ExplainPreparing();
}

class ExplainStreaming extends ExplainState {
  final String text;
  final ExplainMode mode;

  /// Whether this answer is (or will be) coming from the cloud tier —
  /// drives the persistent cloud-in-flight badge in the view.
  final bool fromCloud;
  const ExplainStreaming(this.text, this.mode, {this.fromCloud = false});
}

class ExplainReady extends ExplainState {
  final String text;
  final ExplainMode mode;
  final bool fromCloud;

  /// Which tier the student is actually reading, per the accuracy fail-safe.
  /// [AnswerTier.localLowConfidence] means the on-device model produced
  /// something the quality check rejected and no cloud run was permitted — the
  /// view must warn rather than present it as settled teaching.
  final AnswerTier tier;

  /// The local explanation failed its check and the cloud could re-run it, but
  /// the user's `askEachTime` setting means they have to say so first.
  final bool canRetryOnCloud;

  const ExplainReady(
    this.text,
    this.mode, {
    this.fromCloud = false,
    this.tier = AnswerTier.local,
    this.canRetryOnCloud = false,
  });
}

class ExplainDownloadingModel extends ExplainState {
  final int progress; // 0–100
  const ExplainDownloadingModel(this.progress);
}

/// Paused before a cloud call, waiting on the user to confirm or cancel.
/// [isFirstEver] flags the app's very first cloud call for a longer,
/// more educational message (subsequent confirmations are terser).
class ExplainConfirmCloud extends ExplainState {
  final CloudTier tier;
  final bool isFirstEver;
  const ExplainConfirmCloud({required this.tier, required this.isFirstEver});
}

class ExplainError extends ExplainState {
  final String message;
  final bool retryable;

  /// When true the UI offers the on-device model download as the fix.
  final bool offerModelDownload;
  const ExplainError(
    this.message, {
    this.retryable = true,
    this.offerModelDownload = false,
  });
}

/// What the notifier needs to (re-)run one explanation. [resolveContent] is
/// called fresh on every attempt (a selection is re-read; a gap term is
/// returned verbatim) so retries and mode-changes always see current content.
class ExplainRequest {
  final Future<String> Function() resolveContent;
  final ExplainMode mode;
  const ExplainRequest({required this.resolveContent, required this.mode});
}

class ExplainNotifier extends StateNotifier<ExplainState> {
  final Explainer _explainer;
  final ModelDownloadManager _downloads;

  /// Null when Explain isn't routed (e.g. any test/caller not wired to the
  /// Phase 3 router) — the cloud-confirm gate is then simply skipped,
  /// preserving pre-Phase-3 behavior exactly.
  final Future<CloudRouteDecision?> Function(String content)? _evaluateCloudRoute;
  final bool Function() _hasSeenFirstCloudCall;
  final Future<void> Function() _markFirstCloudCallSeen;

  /// The accuracy fail-safe. Optional, so a caller that hasn't wired it keeps
  /// the plain local stream.
  ///
  /// Skipped entirely when the request is already going to the cloud: routing
  /// there means the cloud tier IS the generator, and re-checking its output in
  /// order to escalate it to itself would be pointless.
  final AiQualityGuard? _guard;

  ExplainNotifier({
    required Explainer explainer,
    required ModelDownloadManager downloads,
    Future<CloudRouteDecision?> Function(String content)? evaluateCloudRoute,
    bool Function()? hasSeenFirstCloudCall,
    Future<void> Function()? markFirstCloudCallSeen,
    AiQualityGuard? guard,
  })  : _explainer = explainer,
        _downloads = downloads,
        _guard = guard,
        _evaluateCloudRoute = evaluateCloudRoute,
        _hasSeenFirstCloudCall = hasSeenFirstCloudCall ?? (() => true),
        _markFirstCloudCallSeen = markFirstCloudCallSeen ?? (() async {}),
        super(const ExplainIdle());

  ExplainRequest? _last;
  bool _running = false;

  /// [cloudConfirmed] skips a re-check of [_evaluateCloudRoute] — set only by
  /// [confirmCloudAndRun], after the user has already said yes once for this
  /// specific request.
  Future<void> run(ExplainRequest request, {bool cloudConfirmed = false}) async {
    if (_running) return;
    _last = request;
    _running = true;
    try {
      state = const ExplainPreparing();
      final content = await request.resolveContent();
      if (content.trim().isEmpty) {
        state = const ExplainError(
          "There's nothing to explain here yet — select some notes first.",
          retryable: false,
        );
        return;
      }

      var fromCloud = false;
      final evaluate = _evaluateCloudRoute;
      if (evaluate != null) {
        final decision = await evaluate(content);
        fromCloud = decision != null;
        if (decision != null && !cloudConfirmed) {
          state = ExplainConfirmCloud(
            tier: decision.tier,
            isFirstEver: !_hasSeenFirstCloudCall(),
          );
          return;
        }
      }

      state = ExplainStreaming('', request.mode, fromCloud: fromCloud);
      final result =
          await _generate(content, request.mode, fromCloud: fromCloud);

      if (!mounted) return;
      final text = result.text.trim();
      state = text.isEmpty
          ? const ExplainError("The model didn't return an explanation. "
              'Try again.')
          : ExplainReady(
              text,
              request.mode,
              fromCloud: fromCloud || result.tier == AnswerTier.cloudVerified,
              tier: result.tier,
              canRetryOnCloud: result.canRetryOnCloud,
            );
    } catch (e) {
      if (!mounted) return;
      state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  /// Streams one explanation, through the quality guard when there is one.
  ///
  /// [fromCloud] means the Phase-3 router already chose the cloud tier for this
  /// request, in which case the guard is bypassed — see [_guard].
  ///
  /// The explanation is checked as UNGROUNDED output ([QualityContext.ungrounded]):
  /// Explain is allowed to bring in widely-known background, so an answer that
  /// shares little vocabulary with a two-word selected term is correct, not
  /// unsourced. Only the broken-output checks (empty, looping, degenerate)
  /// apply here.
  Future<GuardedResult> _generate(
    String content,
    ExplainMode mode, {
    required bool fromCloud,
  }) async {
    void onPartial(String partial) {
      if (mounted) {
        state = ExplainStreaming(partial, mode, fromCloud: fromCloud);
      }
    }

    final guard = _guard;
    if (guard != null && !fromCloud) {
      return guard.run(
        prompt: Explainer.promptFor(content),
        systemPrompt: Explainer.systemPromptFor(mode),
        options: Explainer.explainOptions,
        onPartial: onPartial,
      );
    }

    final buffer = StringBuffer();
    await for (final chunk
        in _explainer.explain(ExplainInput(content: content, mode: mode))) {
      if (!mounted) break;
      buffer.write(chunk);
      onPartial(buffer.toString());
    }
    return GuardedResult(text: buffer.toString(), tier: AnswerTier.local);
  }

  /// Re-runs the current explanation on the cloud tier, on an explicit user tap.
  ///
  /// The `askEachTime` half of the privacy contract: [AiQualityGuard] refuses to
  /// escalate on its own under that setting, so this is what the button behind
  /// [ExplainReady.canRetryOnCloud] calls. Nothing reaches the network until it
  /// is pressed.
  Future<void> verifyWithCloud() async {
    final current = state;
    final guard = _guard;
    if (guard == null || _running || current is! ExplainReady) return;
    if (!current.canRetryOnCloud) return;

    final last = _last;
    if (last == null) return;

    _running = true;
    try {
      // The passage is re-resolved rather than cached: the same rule the retry
      // and mode-change paths follow, so a cloud check always reads what is on
      // the page now.
      final content = await last.resolveContent();
      if (content.trim().isEmpty || !mounted) return;

      final result = await guard.retryOnCloud(
        prompt: Explainer.promptFor(content),
        systemPrompt: Explainer.systemPromptFor(current.mode),
        options: Explainer.explainOptions,
        onPartial: (partial) {
          if (mounted) {
            state = ExplainStreaming(partial, current.mode, fromCloud: true);
          }
        },
        localText: current.text,
      );
      if (!mounted) return;
      final text = result.text.trim();
      state = ExplainReady(
        text.isEmpty ? current.text : text,
        current.mode,
        fromCloud: result.tier == AnswerTier.cloudVerified,
        tier: result.tier,
      );
    } catch (e) {
      if (mounted) state = _mapError(e);
    } finally {
      _running = false;
    }
  }

  /// Re-runs the current passage in a different mode.
  Future<void> changeMode(ExplainMode mode) async {
    final last = _last;
    if (last == null || _running) return;
    await run(ExplainRequest(resolveContent: last.resolveContent, mode: mode));
  }

  Future<void> retry() async {
    final last = _last;
    if (last != null) await run(last);
  }

  /// Starts the LLM download (explicit user action) and re-runs when it lands.
  Future<void> downloadModelAndRetry() async {
    final last = _last;
    if (last == null || _running) return;

    state = const ExplainDownloadingModel(0);
    final sub = _downloads.progress.listen((p) {
      if (mounted && state is ExplainDownloadingModel) {
        state = ExplainDownloadingModel(p);
      }
    });
    try {
      await _downloads.download();
    } catch (e) {
      if (mounted) state = _mapError(e);
      return;
    } finally {
      await sub.cancel();
    }
    if (!mounted) return;
    await run(last);
  }

  void cancelModelDownload() => _downloads.cancelDownload();

  /// The user said yes on [ExplainConfirmCloud] — proceeds with the same
  /// request, skipping the confirm gate this one time.
  Future<void> confirmCloudAndRun() async {
    final last = _last;
    if (last == null || _running) return;
    await _markFirstCloudCallSeen();
    await run(last, cloudConfirmed: true);
  }

  /// The user said no on [ExplainConfirmCloud] — back to idle, nothing sent.
  void cancelCloud() {
    if (!_running) state = const ExplainIdle();
  }

  /// Dismisses the explanation and returns the sidebar to the live context.
  void reset() {
    if (!_running) state = const ExplainIdle();
  }

  ExplainState _mapError(Object e) {
    return switch (e) {
      AiModelNotReadyException _ => const ExplainError(
          'The on-device model needs to be downloaded first.',
          offerModelDownload: true),
      AiException(:final message) => ExplainError(message),
      RecognitionException(:final message) => ExplainError(message),
      InsufficientStorageException(:final message) =>
        ExplainError('Not enough storage for the model. $message'),
      ModelDownloadCancelledException _ => const ExplainIdle(),
      LlmException(:final message) => ExplainError(message),
      _ => const ExplainError('Something went wrong while explaining.'),
    };
  }
}
