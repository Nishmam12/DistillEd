// Picks WHICH vision model reads an image, from the user's [AiProcessingMode].
//
// The page-read path had no cloud option at all before this: the extractor was
// wired straight to the on-device Gemma transcriber, so turning cloud AI on
// changed nothing about who read the page. This decorator is the seam that
// makes `cloudFirst` mean what it says — the cloud reads the image directly and
// the 2.6 GB local model is never loaded.
//
// Falling back is deliberate and one-way: cloud-first degrades to local when
// the cloud call fails, but nothing ever escalates local→cloud here. Escalation
// on a poor-but-successful local read stays the [FigureAnalyzer]'s job, because
// only it can judge whether a reading was good enough.

import 'dart:typed_data';

import '../ai_provider.dart';
import '../image_transcriber.dart';

/// Routes [transcribeImage] to the cloud or the on-device model.
///
/// [preferCloud] is read at CALL time, not construction time, so flipping the
/// mode in Settings takes effect on the next read without rebuilding the
/// extractor graph.
class CloudFirstTranscriber implements ImageTranscriber {
  final ImageTranscriber _local;
  final ImageTranscriber? _cloud;
  final bool Function() _preferCloud;

  CloudFirstTranscriber({
    required ImageTranscriber local,
    required ImageTranscriber? cloud,
    required bool Function() preferCloud,
  })  : _local = local,
        _cloud = cloud,
        _preferCloud = preferCloud;

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    final cloud = _cloud;
    if (cloud != null && _preferCloud()) {
      try {
        return await cloud.transcribeImage(
          imageBytes,
          prompt: prompt,
          temperature: temperature,
          maxOutputTokens: maxOutputTokens,
          randomSeed: randomSeed,
        );
      } on AiException {
        // Offline, gateway down, or the deployment predates /v1/vision. Read it
        // on-device rather than telling someone their page is unreadable —
        // slower is a far better failure than blank.
      }
    }
    return _local.transcribeImage(
      imageBytes,
      prompt: prompt,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
      randomSeed: randomSeed,
    );
  }
}
