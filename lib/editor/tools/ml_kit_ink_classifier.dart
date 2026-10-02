// ML Kit Digital Ink as an [InkClassifier] (docs/AI_PIPELINE_PLAN.md, item 17):
// the shape recogniser and the gesture classifier, which are ordinary ink models
// with a different language tag.
//
// Never downloads: a model that is not on the device is "no answer", so the
// gestures stay off until the student has turned them on in Settings, which is
// where the (small) download is started.

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

import '../../features/ai/data/handwriting/handwriting_recognition_service.dart';
import '../../domain/model/scene_element.dart';
import 'ink_gestures.dart';

class MlKitInkClassifier implements InkClassifier {
  MlKitInkClassifier({mlkit.DigitalInkRecognizerModelManager? models})
      : _models = models ?? mlkit.DigitalInkRecognizerModelManager();

  final mlkit.DigitalInkRecognizerModelManager _models;

  /// One recogniser per model, kept for reuse.
  final Map<String, mlkit.DigitalInkRecognizer> _recognizers = {};

  /// Models known to be on the device. Only presence is remembered: a model that
  /// was missing is asked about again, since it may have been downloaded since.
  final Set<String> _present = {};

  Future<bool> _isPresent(String model) async {
    if (_present.contains(model)) return true;
    final present = await _models.isModelDownloaded(model);
    if (present) _present.add(model);
    return present;
  }

  @override
  Future<InkClass?> classify(FreehandElement stroke, {required String model}) async {
    if (!await _isPresent(model)) return null;
    final recognizer = _recognizers.putIfAbsent(
        model, () => mlkit.DigitalInkRecognizer(languageCode: model));
    final candidates = await recognizer
        .recognize(HandwritingRecognitionService.elementsToInk([stroke]));
    if (candidates.isEmpty) return null;
    final best = candidates.first;
    return (label: best.text, score: best.score);
  }

  /// Closes the recognisers this classifier opened.
  Future<void> dispose() async {
    final open = _recognizers.values.toList();
    _recognizers.clear();
    for (final recognizer in open) {
      try {
        await recognizer.close();
      } catch (_) {
        // Releasing a native handle must not throw into a dispose path.
      }
    }
  }
}
