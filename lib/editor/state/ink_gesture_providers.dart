// Wiring for hold-to-snap and scribble-to-erase (docs/AI_PIPELINE_PLAN.md, item
// 17): the ML Kit classifier the canvas asks after each stroke.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tools/ink_gestures.dart';
import '../tools/ml_kit_ink_classifier.dart';

/// ML Kit's shape and gesture models, one recogniser each, freed with the
/// container. A model that is not on the device answers nothing, so the gestures
/// do nothing until Settings has downloaded them.
final inkClassifierProvider = Provider<InkClassifier>((ref) {
  final classifier = MlKitInkClassifier();
  ref.onDispose(classifier.dispose);
  return classifier;
});

/// Turns an ink gesture on: switches it on, downloads its ML Kit model, and if
/// the download fails switches it back off and returns what to tell the student —
/// a gesture whose model is missing does nothing, so it must not look enabled.
/// Null on success.
Future<String?> enableInkGesture({
  required Future<void> Function(bool enabled) setEnabled,
  required Future<void> Function() downloadModel,
}) async {
  await setEnabled(true);
  try {
    await downloadModel();
    return null;
  } catch (_) {
    await setEnabled(false);
    return "Couldn't download the model. Check your connection and try again.";
  }
}
