// One read of a page gives the on-device vision model only a few pictures.
//
// Written after the first device test: a page of 23 imported photos was read
// on the tablet for over ten minutes, one to three vision calls per photo,
// until Android killed the app for memory. These tests count the model calls.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:margo/features/ai/data/ocr/gemma_vision_ocr_service.dart';
import 'package:margo/features/ai/domain/image_transcriber.dart';
import 'package:margo/features/ai/domain/page_content_extractor.dart';
import 'package:margo/features/ai/domain/page_read_control.dart';
import 'package:margo/features/ai/domain/read_cache.dart';

/// Counts vision calls, and runs [onCall] at the start of each one.
class _CountingVision implements ImageTranscriber {
  int calls = 0;
  void Function(int call)? onCall;

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    calls++;
    onCall?.call(calls);
    // Long and wordy enough to clear the transcription quality gate.
    return 'Corpus: a large, structured set of texts used for study.';
  }
}

List<ImageElement> _pictures(int n) => [
      for (var i = 0; i < n; i++)
        ImageElement(
          id: 'img$i',
          zOrder: i,
          geometryData: [i * 110.0, 0, i * 110.0 + 100, 100],
          relativeImagePath: 'imports/photo$i.png',
        ),
    ];

void main() {
  late _CountingVision vision;
  late InMemoryReadCache cache;
  var pressure = 0;

  PageContentExtractor extractor(List<SceneElement> elements) =>
      PageContentExtractor(
        loadElements: (_) async => elements,
        recognition: HandwritingRecognitionService(),
        readImageText: (path) async => 'ocr of $path',
        visionOcr: GemmaVisionOcrService(transcriber: vision),
        // Different bytes per picture, so each has its own place in the cache.
        loadImageBytes: (path) async => Uint8List.fromList(utf8.encode(path)),
        readCache: cache,
        memoryPressureCount: () => pressure,
      );

  setUp(() {
    vision = _CountingVision();
    cache = InMemoryReadCache();
    pressure = 0;
  });

  test('a page of 12 pictures costs at most the budget in vision calls',
      () async {
    final content = await extractor(_pictures(12))
        .extractPage(1, languageCode: 'en', useVision: true);

    expect(vision.calls, kLocalImageReads);
    expect(content.picturesReadLightly, 12 - kLocalImageReads);
    // Nothing is dropped: the rest still have their text, by plain OCR.
    expect(content.recognizedImageText, contains('ocr of imports/photo11.png'));
    expect(content.sources.where((s) => s.needsOcr), isEmpty);
  });

  test('a page within the budget is read in full, as before', () async {
    final content = await extractor(_pictures(kLocalImageReads))
        .extractPage(1, languageCode: 'en', useVision: true);

    expect(vision.calls, kLocalImageReads);
    expect(content.picturesReadLightly, 0);
  });

  test('reading again moves on to the next pictures; read ones are free',
      () async {
    final ex = extractor(_pictures(10));

    await ex.extractPage(1, languageCode: 'en', useVision: true);
    final second = await ex.extractPage(1, languageCode: 'en', useVision: true);
    expect(vision.calls, 2 * kLocalImageReads);
    expect(second.picturesReadLightly, 10 - 2 * kLocalImageReads);

    final third = await ex.extractPage(1, languageCode: 'en', useVision: true);
    expect(vision.calls, 10, reason: 'the last two; the first eight are remembered');
    expect(third.picturesReadLightly, 0);

    await ex.extractPage(1, languageCode: 'en', useVision: true);
    expect(vision.calls, 10, reason: 'a fully read page costs nothing');
  });

  test('background indexing reads one picture per page', () async {
    final content = await extractor(_pictures(6))
        .extractPage(1, languageCode: 'en', useVision: true, economy: true);

    expect(vision.calls, kEconomyImageReads);
    expect(content.picturesReadLightly, 6 - kEconomyImageReads);
  });

  test('Stop ends the deep reading after the picture in hand', () async {
    final control = PageReadControl();
    addTearDown(control.dispose);
    vision.onCall = (call) {
      if (call == 2) control.stop();
    };

    final content = await extractor(_pictures(12)).extractPage(1,
        languageCode: 'en', useVision: true, control: control);

    expect(vision.calls, 2);
    expect(content.picturesReadLightly, 10);
    expect(content.recognizedImageText, contains('ocr of imports/photo11.png'));
  });

  test('memory pressure ends the deep reading: the model is not reloaded',
      () async {
    // The system asks for memory during the first picture. The model is
    // released then; every further picture would load 2.6 GB again.
    vision.onCall = (call) {
      if (call == 1) pressure++;
    };

    final content = await extractor(_pictures(12))
        .extractPage(1, languageCode: 'en', useVision: true);

    expect(vision.calls, 1);
    expect(content.picturesReadLightly, 11);
  });

  test('pressure from before the read does not stop it', () async {
    pressure = 3;
    await extractor(_pictures(3))
        .extractPage(1, languageCode: 'en', useVision: true);
    expect(vision.calls, 3);
  });

  test('progress names the picture in hand and how many this read takes',
      () async {
    final control = PageReadControl();
    addTearDown(control.dispose);
    final seen = <PageReadProgress>[];
    control.progress.addListener(() => seen.add(control.progress.value!));

    await extractor(_pictures(12)).extractPage(1,
        languageCode: 'en', useVision: true, control: control);

    expect(seen, [
      for (var i = 1; i <= kLocalImageReads; i++)
        PageReadProgress(picture: i, of: kLocalImageReads),
    ]);
  });

  test('a light read (no vision) is not counted as pictures left', () async {
    final content =
        await extractor(_pictures(12)).extractPage(1, languageCode: 'en');
    expect(vision.calls, 0);
    expect(content.picturesReadLightly, 0);
  });
}
