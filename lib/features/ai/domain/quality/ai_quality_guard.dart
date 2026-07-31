// The accuracy fail-safe: run locally, check what came back, and escalate to
// the cloud when it is broken.
//
// Implemented ONCE, here, rather than per feature. Explain, Ask, Summarize and
// the Context Engine all had the same shape of problem — a small on-device
// model produces something wrong and the UI presents it as settled teaching —
// and four copies of the fix would have drifted apart the way the tutor voice
// did before `tutor_voice.dart`.
//
// THE PRIVACY CONTRACT IS THE HARD PART, and it is the reason this class has
// the shape it does. A quality failure is not consent. The existing invariant
// (see `ai_router.dart` and `settings_provider.dart`) is that note content
// reaches the network only on an explicit user decision, and "the local answer
// looked bad" is not one. So escalation is gated on the user's own setting, and
// the three settings mean three genuinely different things:
//
//   localOnly                 → never escalate. Show the low-confidence
//                               warning and stop. The student chose this.
//   allowCloudForNonSensitive → escalate automatically. The student has
//                               pre-authorised exactly this.
//   askEachTime (the default) → do NOT escalate on our own initiative. Return
//                               the local answer flagged low-confidence WITH
//                               [GuardedResult.canRetryOnCloud] set, so the UI
//                               can offer a button. The cloud call then happens
//                               because someone pressed something.
//
// Silently escalating under `askEachTime` would be the easy implementation and
// would break the one invariant this codebase is most careful about. It is not
// done here.
//
// Streaming is preserved. Features stream local output token by token through
// [onPartial] while it is being checked, so the fail-safe costs nothing in
// perceived latency for the overwhelmingly common case where the local answer
// is fine. When an escalation does happen, [onPartial] is called again from
// empty — the UI replaces the bad answer rather than appending to it.

import 'dart:async';

import '../../../../core/providers/settings_provider.dart';
import '../ai_provider.dart';
import 'output_quality.dart';

/// Which tier produced the text the student is looking at.
enum AnswerTier {
  /// The on-device model, and it passed the quality check.
  local,

  /// The cloud model, run because the local answer failed the check. The UI
  /// must say so — the same "clearly indicate when cloud AI is being used" rule
  /// the Explain surface already follows.
  cloudVerified,

  /// The on-device model, and it FAILED the check, but no cloud run was
  /// possible or permitted. The UI must show a low-confidence warning rather
  /// than presenting this as reliable.
  localLowConfidence,
}

/// One guarded generation.
class GuardedResult {
  final String text;
  final AnswerTier tier;

  /// What was wrong with the local output, when something was. Kept even on
  /// [AnswerTier.cloudVerified] so a debug surface can show why the escalation
  /// happened.
  final QualityIssue? issue;

  /// True when the local answer failed and the cloud could fix it, but the
  /// user's `askEachTime` setting means they have to say so. The UI offers a
  /// "check this with the cloud model" action; nothing goes over the network
  /// until it is pressed.
  final bool canRetryOnCloud;

  const GuardedResult({
    required this.text,
    required this.tier,
    this.issue,
    this.canRetryOnCloud = false,
  });

  /// True when the student must be told not to trust this at face value.
  bool get isLowConfidence => tier == AnswerTier.localLowConfidence;
}

/// Wraps a local generation with a quality check and an optional cloud retry.
///
/// Storage- and widget-free: the cloud provider, the privacy setting and the
/// reachability probe all arrive as injected callbacks, so the whole escalation
/// policy is unit-tested with fakes and no network.
class AiQualityGuard {
  final AiProvider _local;

  /// The cloud tier used for a re-run. Null disables escalation entirely (the
  /// guard then only ever downgrades to [AnswerTier.localLowConfidence]).
  final AiProvider? _cloud;

  /// Read at call time, not captured: toggling cloud AI in Settings must take
  /// effect on the next request without rebuilding anything.
  final bool Function() _cloudEnabled;
  final CloudPrivacy Function() _privacy;
  final Future<bool> Function() _isOnline;

  AiQualityGuard({
    required AiProvider local,
    AiProvider? cloud,
    required bool Function() cloudEnabled,
    required CloudPrivacy Function() privacy,
    required Future<bool> Function() isOnline,
  })  : _local = local,
        _cloud = cloud,
        _cloudEnabled = cloudEnabled,
        _privacy = privacy,
        _isOnline = isOnline;

  /// Generates locally, checks the result, and escalates when policy allows.
  ///
  /// [onPartial] receives the accumulating text as it streams. It is called
  /// with '' at the start of each attempt, so a UI that renders it directly
  /// clears the failed local answer before the cloud one starts arriving.
  Future<GuardedResult> run({
    required String prompt,
    String? systemPrompt,
    AiGenerationOptions? options,
    QualityContext quality = QualityContext.ungrounded,
    void Function(String partial)? onPartial,
  }) async {
    final local = await _generate(_local, prompt, systemPrompt, options,
        onPartial: onPartial);
    final verdict = checkOutputQuality(local, context: quality);
    if (verdict.passed) {
      return GuardedResult(text: local, tier: AnswerTier.local);
    }

    final issue = verdict.issue!;
    if (!await _mayEscalateAutomatically()) {
      return GuardedResult(
        text: local,
        tier: AnswerTier.localLowConfidence,
        issue: issue,
        canRetryOnCloud: await _couldEscalateIfAsked(),
      );
    }

    return retryOnCloud(
      prompt: prompt,
      systemPrompt: systemPrompt,
      options: options,
      quality: quality,
      onPartial: onPartial,
      localText: local,
      issue: issue,
    );
  }

  /// Runs the cloud tier explicitly — the path behind the UI's "check this with
  /// the cloud model" action under `askEachTime`, and the automatic path under
  /// `allowCloudForNonSensitive`.
  ///
  /// A cloud failure degrades to the local text flagged low-confidence rather
  /// than throwing: the student already has an answer on screen, and replacing
  /// it with a network error would be a worse outcome than labelling it.
  Future<GuardedResult> retryOnCloud({
    required String prompt,
    String? systemPrompt,
    AiGenerationOptions? options,
    QualityContext quality = QualityContext.ungrounded,
    void Function(String partial)? onPartial,
    String localText = '',
    QualityIssue? issue,
  }) async {
    final cloud = _cloud;
    if (cloud == null) {
      return GuardedResult(
        text: localText,
        tier: AnswerTier.localLowConfidence,
        issue: issue,
      );
    }
    try {
      final text = await _generate(cloud, prompt, systemPrompt, options,
          onPartial: onPartial);
      // The cloud answer gets the same check. A cloud reply that is ALSO broken
      // is not "verified" just because it cost a network call.
      if (checkOutputQuality(text, context: quality).passed) {
        return GuardedResult(
          text: text,
          tier: AnswerTier.cloudVerified,
          issue: issue,
        );
      }
      return GuardedResult(
        text: text.trim().isEmpty ? localText : text,
        tier: AnswerTier.localLowConfidence,
        issue: issue,
      );
    } on AiException {
      onPartial?.call(localText);
      return GuardedResult(
        text: localText,
        tier: AnswerTier.localLowConfidence,
        issue: issue,
      );
    }
  }

  /// May a failed local answer be re-run in the cloud without asking first?
  ///
  /// Requires all of: the cloud opt-in on, a privacy mode that pre-authorises
  /// it, a cloud provider wired, and a network. `askEachTime` deliberately
  /// fails here — see the file header.
  Future<bool> _mayEscalateAutomatically() async {
    if (_cloud == null || !_cloudEnabled()) return false;
    if (_privacy() != CloudPrivacy.allowCloudForNonSensitive) return false;
    return _isOnline();
  }

  /// Could the cloud answer this if the user said yes? Drives whether the UI
  /// offers the button at all — offering it with no network or no opt-in would
  /// be an action that silently does nothing.
  Future<bool> _couldEscalateIfAsked() async {
    if (_cloud == null || !_cloudEnabled()) return false;
    if (_privacy() == CloudPrivacy.localOnly) return false;
    return _isOnline();
  }

  Future<String> _generate(
    AiProvider provider,
    String prompt,
    String? systemPrompt,
    AiGenerationOptions? options, {
    void Function(String partial)? onPartial,
  }) async {
    final buffer = StringBuffer();
    onPartial?.call('');
    await for (final chunk in provider.generate(
      prompt: prompt,
      systemPrompt: systemPrompt,
      options: options,
    )) {
      buffer.write(chunk);
      onPartial?.call(buffer.toString());
    }
    return buffer.toString();
  }
}
