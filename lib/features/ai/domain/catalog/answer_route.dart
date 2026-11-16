// Who answers a question the student asks: the one place that is decided.
//
// Three things feed it — whether cloud AI is on at all, the privacy setting,
// and the model the student picked — and every feature that answers the student
// (Ask, Explain, Summarize, quiz, flashcards, Research) reads the result rather
// than working it out again. A rule that lives in six places is a rule that is
// wrong in one of them, and here a wrong rule sends a student's notes somewhere
// they did not agree to.
//
// What it does NOT decide: where pages are read and analysed in the background.
// That stays with [AiProcessingMode] alone. Background work runs without the
// student asking, so it must never spend a key they are paying for.

import '../../../../core/providers/settings_provider.dart'
    show AiProcessingMode, CloudPrivacy;
import 'ai_model_entry.dart';

sealed class AnswerRoute {
  const AnswerRoute();
}

/// The on-device model answers and nothing leaves the device.
class LocalOnly extends AnswerRoute {
  const LocalOnly();
}

/// The on-device model answers first. [escalation] is the cloud model a poor
/// or oversized answer may be handed to, or null when there is none.
class LocalFirst extends AnswerRoute {
  final AiModelEntry? escalation;
  const LocalFirst(this.escalation);
}

/// The model the student picked answers, and the on-device model is not asked.
class CloudDirect extends AnswerRoute {
  final AiModelEntry model;
  const CloudDirect(this.model);
}

/// Decides the route for [answerModelId] — [kAnswerAuto], [kAnswerLocal], or
/// the id of an entry in [catalogue].
AnswerRoute resolveAnswerRoute({
  required AiProcessingMode aiMode,
  required CloudPrivacy privacy,
  required String answerModelId,
  required List<AiModelEntry> catalogue,
}) {
  // The two switches that mean "nothing leaves this device" win over any
  // stored choice: turning cloud AI off must not need the picker changed too.
  if (!aiMode.allowsCloud) return const LocalOnly();
  if (privacy == CloudPrivacy.localOnly) return const LocalOnly();
  if (answerModelId == kAnswerLocal) return const LocalOnly();

  if (answerModelId != kAnswerAuto) {
    final picked = _find(catalogue, answerModelId);
    if (picked != null && picked.pickable) return CloudDirect(picked);
    // A model that was deleted, locked or switched off since it was picked:
    // behave as auto rather than fail every question.
  }
  return LocalFirst(_margoFallback(catalogue));
}

/// False when [answerModelId] names a model that can no longer answer, so the
/// picker can say so once and reset the choice.
bool answerChoiceIsUsable(String answerModelId, List<AiModelEntry> catalogue) {
  if (answerModelId == kAnswerAuto || answerModelId == kAnswerLocal) {
    return true;
  }
  return _find(catalogue, answerModelId)?.pickable ?? false;
}

AiModelEntry? _find(List<AiModelEntry> catalogue, String id) {
  for (final entry in catalogue) {
    if (entry.id == id) return entry;
  }
  return null;
}

/// The cloud model auto may hand an answer to: one of Margo's own, never one
/// reached with the student's key. Their key is spent only when they pick that
/// model or tap to use it.
AiModelEntry? _margoFallback(List<AiModelEntry> catalogue) {
  for (final entry in catalogue) {
    if (entry.source == ModelSource.margo && entry.pickable) return entry;
  }
  return null;
}
