import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:inkflow/features/ai/data/ocr/gemma_vision_ocr_service.dart';
import 'package:inkflow/features/ai/domain/ai_exception.dart';
import 'package:inkflow/features/ai/domain/image_transcriber.dart';
import 'package:inkflow/features/ai/domain/page_content.dart';
import 'package:inkflow/features/ai/domain/page_content_extractor.dart';

/// A Gemma transcriber that replies with a scripted string per attempt (the
/// last is reused if more attempts happen), or throws [throwError] every call.
class FakeTranscriber implements ImageTranscriber {
  final List<String> replies;
  final Object? throwError;
  int calls = 0;
  final prompts = <String>[];

  FakeTranscriber(this.replies, {this.throwError});

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    prompts.add(prompt);
    if (throwError != null) throw throwError!;
    final reply = calls < replies.length ? replies[calls] : replies.last;
    calls++;
    return reply;
  }
}

const _ink = FreehandElement(
  id: 'ink1',
  zOrder: 0,
  color: 0xFF000000,
  size: 2,
  points: [
    StrokePoint(x: 10, y: 10, t: 0),
    StrokePoint(x: 60, y: 12, t: 40),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_digital_ink_recognizer');

  /// The text the mocked ML Kit recognizer returns.
  String recognizedText = '';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#startDigitalInkRecognizer') {
        return [
          {'text': recognizedText, 'score': 2.5},
        ];
      }
      return 'success';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  PageContentExtractor extractor(
    List<SceneElement> elements, {
    ImageTextReader? readImageText,
    GemmaVisionOcrService? visionOcr,
    InkImageRenderer? renderInk,
    ImageBytesLoader? loadImageBytes,
  }) =>
      PageContentExtractor(
        loadElements: (_) async => elements,
        recognition: HandwritingRecognitionService(),
        readImageText: readImageText,
        visionOcr: visionOcr,
        renderInk: renderInk,
        loadImageBytes: loadImageBytes,
      );

  /// A rendered-ink PNG (contents don't matter; the fake transcriber ignores
  /// them) and an image-file byte loader, so the vision path has something to
  /// hand Gemma.
  Future<Uint8List?> renderInk(List<SceneElement> _) async =>
      Uint8List.fromList(const [1, 2, 3]);
  Future<Uint8List?> loadBytes(String _) async =>
      Uint8List.fromList(const [4, 5, 6]);
  GemmaVisionOcrService vision(List<String> replies, {Object? throwError}) =>
      GemmaVisionOcrService(
          transcriber: FakeTranscriber(replies, throwError: throwError));

  test('empty page extracts to PageContent.empty', () async {
    final content = await extractor([]).extractPage(1, languageCode: 'en');
    expect(content.hasText, isFalse);
    expect(content.sources, isEmpty);
  });

  test('ink is recognized and reported with bounds and score', () async {
    recognizedText = 'handwritten line';
    final content =
        await extractor([_ink]).extractPage(1, languageCode: 'en');

    expect(content.recognizedInkText, 'handwritten line');
    expect(content.inkTopScore, 2.5);
    final inkSource =
        content.sources.singleWhere((s) => s.kind == PageSourceKind.ink);
    expect(inkSource.bounds.left, 10);
    expect(inkSource.bounds.right, 60);
    expect(inkSource.needsOcr, isFalse);
  });

  test('typed text concatenates in reading order (top→bottom, left→right)',
      () async {
    recognizedText = '';
    const bottom = TextElement(
        id: 't-bottom',
        zOrder: 0,
        geometryData: [0, 200, 100, 220],
        text: 'third',
        color: 0xFF000000);
    const topRight = TextElement(
        id: 't-top-right',
        zOrder: 1,
        geometryData: [150, 10, 250, 30],
        text: 'second',
        color: 0xFF000000);
    const topLeft = TextElement(
        id: 't-top-left',
        zOrder: 2,
        geometryData: [0, 10, 100, 30],
        text: 'first',
        color: 0xFF000000);

    final content = await extractor([bottom, topRight, topLeft])
        .extractPage(1, languageCode: 'en');

    expect(content.typedText, 'first\nsecond\nthird');
    expect(content.recognizedInkText, isEmpty);
  });

  test('blank text elements are skipped', () async {
    const blank = TextElement(
        id: 'blank',
        zOrder: 0,
        geometryData: [0, 0, 10, 10],
        text: '   ',
        color: 0xFF000000);
    final content =
        await extractor([blank]).extractPage(1, languageCode: 'en');
    expect(content.typedText, isEmpty);
    expect(content.sources, isEmpty);
  });

  test('images (rasterized PDFs included) are flagged needsOcr, not read',
      () async {
    const image = ImageElement(
        id: 'img',
        zOrder: 0,
        geometryData: [0, 0, 100, 100],
        relativeImagePath: 'imports/page1.png',
        sourceDescription: 'doc.pdf — Page 1');

    final content =
        await extractor([image]).extractPage(1, languageCode: 'en');

    expect(content.hasUnrecognizedImages, isTrue);
    final source = content.sources.single;
    expect(source.kind, PageSourceKind.image);
    expect(source.needsOcr, isTrue);
    expect(content.hasText, isFalse);
  });

  group('images with OCR wired in', () {
    const image = ImageElement(
        id: 'img',
        zOrder: 0,
        geometryData: [0, 0, 100, 100],
        relativeImagePath: 'imports/page1.png',
        sourceDescription: 'doc.pdf — Page 1');

    test('an imported page becomes readable text the AI can use', () async {
      // Without this the AI saw nothing at all on a page holding an imported
      // PDF or a photo of a whiteboard.
      final content = await extractor(
        [image],
        readImageText: (path) async {
          expect(path, 'imports/page1.png');
          return 'Corpus means a large collection of text.';
        },
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText,
          'Corpus means a large collection of text.');
      expect(content.hasText, isTrue);
      expect(content.combinedText, contains('Corpus'));
      expect(content.hasUnrecognizedImages, isFalse,
          reason: 'it was read, so nothing is left needing OCR');
    });

    test('an image holding no text is still flagged as unread', () async {
      final content = await extractor([image], readImageText: (_) async => '')
          .extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, isEmpty);
      expect(content.hasUnrecognizedImages, isTrue,
          reason: 'a diagram is visible content the pipeline did not read');
    });

    test('image text is kept apart from text the user typed', () async {
      const typed = TextElement(
          id: 't',
          zOrder: 1,
          geometryData: [0, 0, 50, 20],
          text: 'my own note',
          color: 0xFF000000);

      final content = await extractor(
        [image, typed],
        readImageText: (_) async => 'from the picture',
      ).extractPage(1, languageCode: 'en');

      expect(content.typedText, 'my own note');
      expect(content.recognizedImageText, 'from the picture');
      // Both reach the model, ink first, then typed, then read-from-image.
      expect(content.combinedText, 'my own note\n\nfrom the picture');
    });

    test('several images are joined in element order', () async {
      const second = ImageElement(
          id: 'img2',
          zOrder: 1,
          geometryData: [0, 200, 100, 300],
          relativeImagePath: 'imports/page2.png');

      final content = await extractor(
        [image, second],
        readImageText: (path) async =>
            path.contains('page1') ? 'first' : 'second',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, 'first\n\nsecond');
    });

    test('an image with no file behind it is not handed to the reader',
        () async {
      const pathless = ImageElement(
          id: 'img3',
          zOrder: 0,
          geometryData: [0, 0, 10, 10],
          relativeImagePath: '');

      var called = false;
      final content = await extractor([pathless], readImageText: (_) async {
        called = true;
        return 'should not happen';
      }).extractPage(1, languageCode: 'en');

      expect(called, isFalse);
      expect(content.hasUnrecognizedImages, isTrue);
    });
  });

  test('combinedText joins ink then typed text; eraser ink is invisible',
      () async {
    recognizedText = 'from the pen';
    const typed = TextElement(
        id: 't',
        zOrder: 1,
        geometryData: [0, 300, 100, 320],
        text: 'from the keyboard',
        color: 0xFF000000);
    final eraser = _ink.copyWith(id: 'e', isEraser: true);

    final content = await extractor([_ink, typed, eraser])
        .extractPage(1, languageCode: 'en');

    expect(content.combinedText, 'from the pen\n\nfrom the keyboard');
    // The eraser element contributes no ink source of its own; the single
    // ink source covers only the real stroke.
    expect(
        content.sources.where((s) => s.kind == PageSourceKind.ink), hasLength(1));
  });

  group('extractSelection', () {
    test('reads only the selected elements', () async {
      recognizedText = 'selected ink';
      const other = TextElement(
          id: 'other',
          zOrder: 0,
          geometryData: [0, 0, 100, 20],
          text: 'not selected',
          color: 0xFF000000);

      final content = await extractor([_ink, other])
          .extractSelection(1, {'ink1'}, languageCode: 'en');

      expect(content.recognizedInkText, 'selected ink');
      expect(content.typedText, isEmpty,
          reason: 'the unselected text element is excluded');
    });

    test('can target a single typed element', () async {
      recognizedText = '';
      const keep = TextElement(
          id: 'a',
          zOrder: 0,
          geometryData: [0, 10, 100, 30],
          text: 'keep me',
          color: 0xFF000000);
      const drop = TextElement(
          id: 'b',
          zOrder: 1,
          geometryData: [0, 40, 100, 60],
          text: 'drop me',
          color: 0xFF000000);

      final content = await extractor([keep, drop])
          .extractSelection(1, {'a'}, languageCode: 'en');

      expect(content.typedText, 'keep me');
    });

    test('no ids yields empty content without touching recognition', () async {
      recognizedText = 'should never be read';
      final content = await extractor([_ink])
          .extractSelection(1, const {}, languageCode: 'en');

      expect(content.hasText, isFalse);
      expect(content.sources, isEmpty);
    });

    test('ids absent from the page yield empty content', () async {
      recognizedText = 'ignored';
      final content = await extractor([_ink])
          .extractSelection(1, {'not-on-page'}, languageCode: 'en');

      expect(content.hasText, isFalse);
    });
  });

  group('Gemma vision — primary read (useVision), ML Kit fallback', () {
    const image = ImageElement(
        id: 'img',
        zOrder: 0,
        geometryData: [0, 0, 100, 100],
        relativeImagePath: 'imports/page1.png');

    test('a good Gemma read wins; ML Kit is never consulted for the ink',
        () async {
      recognizedText = 'ML KIT GARBAGE senderee seprentti';
      final content = await extractor(
        [_ink],
        visionOcr:
            vision(const ['Sentence Segmentation is splitting text into units']),
        renderInk: renderInk,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedInkText,
          'Sentence Segmentation is splitting text into units');
      expect(content.inkTopScore, isNull,
          reason: 'a Gemma read has no ML Kit confidence score');
    });

    test('useVision:false keeps the light ML Kit path (Gemma untouched)',
        () async {
      recognizedText = 'the ml kit reading';
      final transcriber = FakeTranscriber(const ['gemma should not run']);
      final content = await extractor(
        [_ink],
        visionOcr: GemmaVisionOcrService(transcriber: transcriber),
        renderInk: renderInk,
      ).extractPage(1, languageCode: 'en'); // useVision defaults to false

      expect(content.recognizedInkText, 'the ml kit reading');
      expect(transcriber.calls, 0, reason: 'no deep read was asked for');
    });

    test('a gibberish Gemma read (both attempts) falls back to ML Kit',
        () async {
      recognizedText = 'the reliable ml kit sentence here';
      final ocr = vision(const ['::: ??? %%%', '### @@@ !!!']); // both fail gate
      final content = await extractor(
        [_ink],
        visionOcr: ocr,
        renderInk: renderInk,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedInkText, 'the reliable ml kit sentence here');
    });

    test("Gemma's best effort is kept only when ML Kit finds nothing", () async {
      recognizedText = ''; // ML Kit reads nothing
      final content = await extractor(
        [_ink],
        visionOcr: vision(const ['## ?? %%', '@@ !! ##']), // gate-failing
        renderInk: renderInk,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedInkText, '## ?? %%',
          reason: 'a poor Gemma read still beats an empty page');
    });

    test('a good Gemma read of an imported image becomes its text', () async {
      final content = await extractor(
        [image],
        readImageText: (_) async => 'ml kit ocr fallback text',
        visionOcr: vision(const ['Corpus: a large, structured set of texts.']),
        loadImageBytes: loadBytes,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedImageText,
          'Corpus: a large, structured set of texts.');
      expect(content.hasUnrecognizedImages, isFalse);
    });

    test('a missing Gemma model propagates (so the UI can offer the download)',
        () async {
      final content = extractor(
        [_ink],
        visionOcr: vision(const [],
            throwError: const AiModelNotReadyException('not downloaded')),
        renderInk: renderInk,
      ).extractPage(1, languageCode: 'en', useVision: true);

      await expectLater(content, throwsA(isA<AiModelNotReadyException>()));
    });

    test('render failure falls back to ML Kit rather than losing the ink',
        () async {
      recognizedText = 'ml kit still reads the strokes';
      final content = await extractor(
        [_ink],
        visionOcr: vision(const ['unused because render returned null']),
        renderInk: (_) async => null,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedInkText, 'ml kit still reads the strokes');
    });
  });
}
