import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/features/ai/data/handwriting/handwriting_recognition_service.dart';
import 'package:distill_ed/features/ai/data/ocr/gemma_vision_ocr_service.dart';
import 'package:distill_ed/features/ai/domain/ai_exception.dart';
import 'package:distill_ed/features/ai/domain/figure.dart';
import 'package:distill_ed/features/ai/domain/figure_analyzer.dart';
import 'package:distill_ed/features/ai/domain/image_transcriber.dart';
import 'package:distill_ed/features/ai/domain/language/language_detector.dart';
import 'package:distill_ed/features/ai/domain/page_content.dart';
import 'package:distill_ed/features/ai/domain/page_content_extractor.dart';
import 'package:distill_ed/features/ai/domain/pdf_text_layer.dart';
import 'package:distill_ed/features/ai/domain/read_cache.dart';

/// A Gemma transcriber that replies with a scripted string per attempt (the
/// last is reused if more attempts happen), or throws [throwError] every call.
class FakeTranscriber implements ImageTranscriber {
  final List<String> replies;
  final Object? throwError;
  int calls = 0;
  final prompts = <String>[];
  final maxTokens = <int>[];

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
    maxTokens.add(maxOutputTokens);
    if (throwError != null) throw throwError!;
    final reply = calls < replies.length ? replies[calls] : replies.last;
    calls++;
    return reply;
  }
}

class _CallbackTranscriber implements ImageTranscriber {
  _CallbackTranscriber(this._reply);
  final Future<String> Function(String prompt) _reply;

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) =>
      _reply(prompt);
}

/// The ML Kit readings the next recognise calls will return: (text, score).
final _inkQueue = <(String, double)>[];

/// A cache whose every call fails — the database being locked, say.
class _BrokenCache implements ReadCache {
  @override
  Future<CachedRead?> find(String key) async => throw StateError('db locked');

  @override
  Future<void> save(String key, CachedRead read) async =>
      throw StateError('db locked');
}

/// Identifies every text as [tag] — or as [byText] says, when it has an entry —
/// and `null` (could not run) when neither applies.
class _FixedDetector implements LanguageDetector {
  final String? tag;
  final Map<String, String> byText;

  _FixedDetector(this.tag, {this.byText = const {}});

  @override
  Future<String?> identify(String text) async => byText[text] ?? tag;
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
    FigureAnalyzer? figureAnalyzer,
    bool Function()? localIsSlow,
    bool Function()? lite,
    // The existing tests below are about the whole-page Gemma read, so that is
    // what the helper gives them; the ML-Kit-first tests ask for it explicitly.
    bool mlKitFirstInk = false,
    ReadCache? readCache,
    String Function()? readModelId,
    bool persistReads = true,
    LanguageDetector? languageDetector,
    PdfTextLayerReader? pdfTextLayer,
    LectureTranscriptReader? lectureTranscript,
  }) =>
      PageContentExtractor(
        loadElements: (_) async => elements,
        recognition: HandwritingRecognitionService(),
        readImageText: readImageText,
        visionOcr: visionOcr,
        renderInk: renderInk,
        loadImageBytes: loadImageBytes,
        figureAnalyzer: figureAnalyzer,
        localIsSlow: localIsSlow,
        lite: lite,
        mlKitFirstInk: mlKitFirstInk,
        readCache: readCache,
        readModelId: readModelId,
        persistReads: persistReads,
        languageDetector: languageDetector,
        pdfTextLayer: pdfTextLayer,
        lectureTranscript: lectureTranscript,
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

  test('a text box with a damaged outline still reads, without costing the page',
      () async {
    recognizedText = '';
    const damaged = TextElement(
        id: 't-damaged',
        zOrder: 0,
        geometryData: [5, 5],
        text: 'still here',
        color: 0xFF000000);
    const other = TextElement(
        id: 't-other',
        zOrder: 1,
        geometryData: [0, 10, 100, 30],
        text: 'fine',
        color: 0xFF000000);

    final content = await extractor([damaged, other])
        .extractPage(1, languageCode: 'en');

    expect(content.typedText, contains('still here'));
    expect(content.typedText, contains('fine'));
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

  group('image text that is not any language (a script ML Kit cannot read)',
      () {
    // ML Kit text recognition reads Latin script; handed Bengali it still
    // answers, with letters that are no language at all. Left in, that noise
    // would be stored as the page's text and indexed.
    const noise = 'xqz vbn mwk xqz vbn mwk xqz vbn mwk';
    const image = ImageElement(
        id: 'img',
        zOrder: 0,
        geometryData: [0, 0, 100, 100],
        relativeImagePath: 'imports/bangla.png');

    test('noise is dropped, and the image is flagged for a deep read',
        () async {
      final content = await extractor(
        [image],
        readImageText: (_) async => noise,
        languageDetector: _FixedDetector(kUndetermined),
      ).extractPage(1, languageCode: 'bn');

      expect(content.recognizedImageText, isEmpty);
      expect(content.hasUnrecognizedImages, isTrue,
          reason: 'it was NOT read, so a deep read still has work to do');
    });

    test('text in a language is kept', () async {
      final content = await extractor(
        [image],
        readImageText: (_) async => 'Corpus means a large collection of text.',
        languageDetector: _FixedDetector('en'),
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText,
          'Corpus means a large collection of text.');
    });

    test('with no detector wired nothing changes: the text is kept', () async {
      final content = await extractor(
        [image],
        readImageText: (_) async => noise,
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, noise);
    });

    test('a detector that could not run never costs the page its text',
        () async {
      final content = await extractor(
        [image],
        readImageText: (_) async => noise,
        languageDetector: _FixedDetector(null),
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, noise);
    });

    test('each image is judged on its own text', () async {
      const second = ImageElement(
          id: 'img2',
          zOrder: 1,
          geometryData: [0, 200, 100, 300],
          relativeImagePath: 'imports/english.png');

      final content = await extractor(
        [image, second],
        readImageText: (path) async =>
            path.contains('bangla') ? noise : 'a real sentence that reads fine',
        languageDetector: _FixedDetector(null, byText: {
          noise: kUndetermined,
          'a real sentence that reads fine': 'en',
        }),
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, 'a real sentence that reads fine');
    });

    test("a deep read keeps Gemma's attempt over noise from ML Kit", () async {
      // Gemma's reading fails its own gate, so ML Kit would normally be
      // preferred — but ML Kit's "reading" is noise, which is worse than a poor
      // reading in the right script.
      final content = await extractor(
        [image],
        readImageText: (_) async => noise,
        visionOcr: vision(const ['## ?? %%', '@@ !! ##']), // gate-failing
        loadImageBytes: loadBytes,
        languageDetector: _FixedDetector(kUndetermined),
      ).extractPage(1, languageCode: 'bn', useVision: true);

      expect(content.recognizedImageText, '## ?? %%');
    });

    test('a deep read still prefers ML Kit when its text is a real language',
        () async {
      final content = await extractor(
        [image],
        readImageText: (_) async => 'the reliable ml kit sentence here',
        visionOcr: vision(const ['## ?? %%', '@@ !! ##']), // gate-failing
        loadImageBytes: loadBytes,
        languageDetector: _FixedDetector('en'),
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedImageText, 'the reliable ml kit sentence here');
    });
  });

  group('a PDF page that carries its own text', () {
    // What PDFium read out of the page at import: exact, and free.
    const layer = 'Photosynthesis converts light energy into chemical energy '
        'stored in glucose, releasing oxygen as a by-product.';
    const page = ImageElement(
        id: 'pdf',
        zOrder: 0,
        geometryData: [0, 0, 100, 140],
        relativeImagePath: 'notes/1/imports/pdf_abc_3.png',
        sourceDescription: 'lecture.pdf — Page 3');

    test('its text is the page\'s text, with no OCR and no model call',
        () async {
      final transcriber = FakeTranscriber(const ['gemma should not run']);
      var ocrCalls = 0;
      final content = await extractor(
        [page],
        pdfTextLayer: (path) async {
          expect(path, 'notes/1/imports/pdf_abc_3.png');
          return layer;
        },
        readImageText: (_) async {
          ocrCalls++;
          return 'ocr';
        },
        visionOcr: GemmaVisionOcrService(transcriber: transcriber),
        loadImageBytes: loadBytes,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedImageText, layer);
      expect(content.hasUnrecognizedImages, isFalse);
      expect(transcriber.calls, 0, reason: 'a text PDF never loads the model');
      expect(ocrCalls, 0);
    });

    test('a light read gets the text too — it needs no model at all', () async {
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => layer,
      ).extractPage(1, languageCode: 'en'); // useVision defaults to false

      expect(content.recognizedImageText, layer);
      expect(content.hasUnrecognizedImages, isFalse);
    });

    test('no figure pass is spent on a page whose text is already exact',
        () async {
      final figures = FakeTranscriber(const ['{"kind":"none"}']);
      await extractor(
        [page],
        pdfTextLayer: (_) async => layer,
        loadImageBytes: loadBytes,
        visionOcr: vision(const ['unused']),
        figureAnalyzer:
            FigureAnalyzer(local: figures, localModelId: 'local-x'),
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(figures.calls, 0);
    });

    test('Windows line endings in the layer are normalised', () async {
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => '${layer.replaceFirst(', ', ',\r\n')}\r\n',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, isNot(contains('\r')));
      expect(content.recognizedImageText, contains(',\nreleasing'));
    });

    test('a page with only a page number is read like any scan', () async {
      final transcriber = FakeTranscriber(const ['The slide really says this.']);
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => '12',
        visionOcr: GemmaVisionOcrService(transcriber: transcriber),
        loadImageBytes: loadBytes,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedImageText, 'The slide really says this.');
      expect(transcriber.calls, 1);
    });

    test('an empty layer — a scan — is read like any scan', () async {
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => '',
        readImageText: (_) async => 'what OCR read from the picture',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, 'what OCR read from the picture');
    });

    test('a page with no text file at all is read like any scan', () async {
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => null, // imported before the layer was kept
        readImageText: (_) async => 'what OCR read from the picture',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, 'what OCR read from the picture');
    });

    test('a garbled layer is not trusted — broken fonts yield text that is '
        'no language', () async {
      // PDFs with a broken character map still HAVE a text layer; it just is not
      // text. Common with legacy Bangla fonts.
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => layer,
        // Only the layer is noise; what OCR then reads is a real language.
        languageDetector: _FixedDetector(null, byText: {
          layer: kUndetermined,
          'what OCR read from the picture': 'en',
        }),
        readImageText: (_) async => 'what OCR read from the picture',
      ).extractPage(1, languageCode: 'bn');

      expect(content.recognizedImageText, 'what OCR read from the picture');
    });

    test('a layer in a real language is trusted', () async {
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => layer,
        languageDetector: _FixedDetector('en'),
        readImageText: (_) async => 'ocr should not be used',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, layer);
    });

    test('Re-read asks the model, and so ignores the layer', () async {
      final transcriber = FakeTranscriber(const ['The model\'s own reading.']);
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => layer,
        visionOcr: GemmaVisionOcrService(transcriber: transcriber),
        loadImageBytes: loadBytes,
      ).extractPage(1,
          languageCode: 'en', useVision: true, varyVision: true);

      expect(content.recognizedImageText, "The model's own reading.");
      expect(transcriber.calls, 1);
    });

    test('a reader that fails never costs the page its read', () async {
      final content = await extractor(
        [page],
        pdfTextLayer: (_) async => throw StateError('disk error'),
        readImageText: (_) async => 'what OCR read from the picture',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, 'what OCR read from the picture');
    });

    test('with no reader wired the page is read exactly as before', () async {
      final content = await extractor(
        [page],
        readImageText: (_) async => 'what OCR read from the picture',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, 'what OCR read from the picture');
    });

    test('a page with no image file is never handed to the reader', () async {
      const pathless = ImageElement(
          id: 'p',
          zOrder: 0,
          geometryData: [0, 0, 10, 10],
          relativeImagePath: '');
      var asked = false;

      await extractor([pathless], pdfTextLayer: (_) async {
        asked = true;
        return layer;
      }).extractPage(1, languageCode: 'en');

      expect(asked, isFalse);
    });

    test('each page is judged on its own — a text page beside a scan',
        () async {
      const scan = ImageElement(
          id: 'scan',
          zOrder: 1,
          geometryData: [0, 200, 100, 340],
          relativeImagePath: 'notes/1/imports/pdf_abc_4.png');

      final content = await extractor(
        [page, scan],
        pdfTextLayer: (path) async => path.endsWith('_3.png') ? layer : '',
        readImageText: (_) async => 'the scan, read by OCR',
      ).extractPage(1, languageCode: 'en');

      expect(content.recognizedImageText, '$layer\n\nthe scan, read by OCR');
    });
  });


  group('lecture transcripts — what was said, beside what was written', () {
    const lecture = 'Lecture recorded Mon, Oct 12 at 10:05 (spoken words, '
        'transcribed on this device):\n[0:00] Today we cover photosynthesis.\n'
        '[0:25] The light reactions happen in the thylakoid.';

    test('the transcript is part of what the AI can read on the page',
        () async {
      recognizedText = 'my own note';
      final content = await extractor(
        [_ink],
        lectureTranscript: (pageId) async {
          expect(pageId, 7);
          return lecture;
        },
      ).extractPage(7, languageCode: 'en');

      expect(content.lectureTranscript, lecture);
      expect(content.combinedText, 'my own note\n\n$lecture');
      expect(content.hasText, isTrue);
    });

    test('a page that is only a recording is not empty to the AI', () async {
      final content = await extractor(
        const [],
        lectureTranscript: (_) async => lecture,
      ).extractPage(7, languageCode: 'en');

      expect(content.hasText, isTrue);
      expect(content.combinedText, lecture);
    });

    test('a page with no recording is read exactly as before', () async {
      recognizedText = 'my own note';
      final content = await extractor(
        [_ink],
        lectureTranscript: (_) async => '',
      ).extractPage(7, languageCode: 'en');

      expect(content.lectureTranscript, isEmpty);
      expect(content.combinedText, 'my own note');
    });

    test('a reader that fails never costs the page its read', () async {
      recognizedText = 'my own note';
      final content = await extractor(
        [_ink],
        lectureTranscript: (_) async => throw StateError('disk error'),
      ).extractPage(7, languageCode: 'en');

      expect(content.combinedText, 'my own note');
    });

    test('with no reader wired nothing changes', () async {
      recognizedText = 'my own note';
      final content =
          await extractor([_ink]).extractPage(7, languageCode: 'en');

      expect(content.lectureTranscript, isEmpty);
    });

    test('a selection is not the whole page: it carries no transcript',
        () async {
      recognizedText = 'my own note';
      final content = await extractor(
        [_ink],
        lectureTranscript: (_) async => lecture,
      ).extractSelection(7, {'ink1'}, languageCode: 'en');

      expect(content.lectureTranscript, isEmpty);
    });

    test('it follows the text the student wrote, whatever else the page holds',
        () async {
      const typed = TextElement(
          id: 't',
          zOrder: 1,
          geometryData: [0, 0, 50, 20],
          text: 'typed note',
          color: 0xFF000000);

      final content = await extractor(
        [typed],
        lectureTranscript: (_) async => lecture,
      ).extractPage(7, languageCode: 'en');

      expect(content.combinedText, 'typed note\n\n$lecture');
    });
  });


  group('Gemma vision — whole-page read, ML Kit fallback '
      '(flag off, Re-read, or ML Kit cannot carry the page)', () {
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

    test('one image the model fails on does not cost the others their text',
        () async {
      const second = ImageElement(
          id: 'img2',
          zOrder: 1,
          geometryData: [0, 120, 100, 220],
          relativeImagePath: 'imports/page2.png',
          sourceDescription: 'doc.pdf — Page 2');
      var call = 0;
      final flaky = GemmaVisionOcrService(
          transcriber: _CallbackTranscriber((_) async {
        call++;
        if (call == 2) throw StateError('decoder blew up');
        return 'Slide one: osmosis moves water across a membrane.';
      }));

      final content = await extractor(
        [image, second],
        readImageText: (_) async => '',
        visionOcr: flaky,
        loadImageBytes: loadBytes,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedImageText, contains('osmosis'));
      expect(content.hasUnrecognizedImages, isTrue,
          reason: 'the failed image is flagged, not silently dropped');
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


  group('ML Kit first, Gemma only where ML Kit cannot be trusted', () {
    // The channel hands back the NEXT scripted reading on every recognise call,
    // one per handwritten line, top to bottom.
    var readings = <({String text, double score})>[];

    setUp(() {
      readings = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'vision#startDigitalInkRecognizer') {
          if (readings.isEmpty) return <Map<String, Object>>[];
          final next = readings.removeAt(0);
          return next.text.isEmpty
              ? <Map<String, Object>>[]
              : [
                  {'text': next.text, 'score': next.score}
                ];
        }
        return 'success';
      });
    });

    /// One handwritten line per element, 100 units apart so each groups alone.
    List<FreehandElement> lineElements(int count) => [
          for (var i = 0; i < count; i++)
            FreehandElement(
              id: 'l${i + 1}',
              zOrder: i,
              color: 0xFF000000,
              size: 2,
              points: [
                StrokePoint(x: 10, y: 100.0 * i, t: 0),
                StrokePoint(x: 60, y: 100.0 * i + 20, t: 40),
              ],
            ),
        ];

    /// The element ids handed to the renderer on each call, in order.
    final rendered = <List<String>>[];
    Future<Uint8List?> recordingRender(List<SceneElement> els) async {
      rendered.add([for (final e in els) e.id]);
      return Uint8List.fromList(const [1, 2, 3]);
    }

    setUp(rendered.clear);

    PageContentExtractor mlFirst(
      List<SceneElement> elements,
      FakeTranscriber transcriber, {
      InkImageRenderer? render,
      FigureAnalyzer? figureAnalyzer,
      bool mlKitFirstInk = true,
    }) =>
        extractor(
          elements,
          visionOcr: GemmaVisionOcrService(transcriber: transcriber),
          renderInk: render ?? recordingRender,
          figureAnalyzer: figureAnalyzer,
          mlKitFirstInk: mlKitFirstInk,
        );

    test('a page ML Kit reads cleanly never touches Gemma', () async {
      readings = [
        (text: 'Sentence segmentation splits text', score: 1.0),
        (text: 'Tokens are the units of text', score: 2.0),
      ];
      final gemma = FakeTranscriber(const ['must not run']);

      final content = await mlFirst(lineElements(2), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(gemma.calls, 0, reason: 'no model load for a page that read fine');
      expect(rendered, isEmpty);
      expect(content.recognizedInkText,
          'Sentence segmentation splits text\nTokens are the units of text');
      expect(content.inkTopScore, 1.5);
    });

    test('only the line ML Kit cannot be trusted on goes to Gemma, cropped',
        () async {
      readings = [
        (text: 'Eigenvalues describe scaling', score: 1.0),
        (text: ':::: ??', score: 9.0),
        (text: 'Vectors span a space', score: 1.0),
      ];
      final gemma = FakeTranscriber(const ['Matrices represent linear maps']);

      final content = await mlFirst(lineElements(3), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(gemma.calls, 1);
      expect(rendered, [
        ['l2']
      ], reason: 'a crop of just the weak line, not the whole page');
      expect(content.recognizedInkText,
          'Eigenvalues describe scaling\nMatrices represent linear maps\nVectors span a space');
      // Only the lines ML Kit actually supplied count toward the confidence.
      expect(content.inkTopScore, 1.0);
    });

    test('a read of a small region is capped well under a page of tokens',
        () async {
      readings = [
        (text: 'Eigenvalues describe scaling', score: 1.0),
        (text: ':::: ??', score: 9.0),
        (text: 'Vectors span a space', score: 1.0),
      ];
      final gemma = FakeTranscriber(const ['Matrices represent linear maps']);

      await mlFirst(lineElements(3), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      // One line: 96 + 48. Far below the 1,024 a whole page is allowed.
      expect(gemma.maxTokens.single, 144);
    });

    test('a line of maths goes to Gemma even though ML Kit was confident',
        () async {
      readings = [
        (text: 'Solve the quadratic below', score: 1.0),
        (text: 'x^2 + 3x = 0', score: 1.0),
        (text: 'then factorise the result', score: 1.0),
      ];
      final gemma = FakeTranscriber(const ['x^2 + 3x = 0, so x(x + 3) = 0']);

      final content = await mlFirst(lineElements(3), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(gemma.calls, 1);
      expect(rendered, [
        ['l2']
      ]);
      expect(content.recognizedInkText, contains('x(x + 3) = 0'));
    });

    test('neighbouring weak lines are read as one region, in one call',
        () async {
      readings = [
        (text: ':::: ??', score: 9.0),
        (text: '#### @@', score: 9.0),
        (text: 'A perfectly readable line', score: 1.0),
        (text: 'Another readable line here', score: 1.0),
        (text: 'And a third readable line', score: 1.0),
      ];
      final gemma =
          FakeTranscriber(const ['First repaired line\nSecond repaired line']);

      final content = await mlFirst(lineElements(5), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(gemma.calls, 1);
      expect(rendered, [
        ['l1', 'l2']
      ]);
      expect(gemma.maxTokens.single, 192, reason: '96 + 48 for each of 2 lines');
      expect(
          content.recognizedInkText,
          'First repaired line\nSecond repaired line\n'
          'A perfectly readable line\nAnother readable line here\n'
          'And a third readable line');
    });

    test("Gemma's failed read of a weak line leaves ML Kit's text in place",
        () async {
      readings = [
        (text: 'Eigenvalues describe scaling', score: 1.0),
        (text: 'wobbly ink', score: 9.0),
        (text: 'Vectors span a space', score: 1.0),
      ];
      // Both attempts fail the gate.
      final gemma = FakeTranscriber(const ['::: ???', '### @@@']);

      final content = await mlFirst(lineElements(3), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(content.recognizedInkText,
          'Eigenvalues describe scaling\nwobbly ink\nVectors span a space');
    });

    test('a weak line that cannot be rendered keeps ML Kit\'s text', () async {
      readings = [
        (text: 'Eigenvalues describe scaling', score: 1.0),
        (text: 'wobbly ink', score: 9.0),
        (text: 'Vectors span a space', score: 1.0),
      ];
      final gemma = FakeTranscriber(const ['never asked']);

      final content = await mlFirst(lineElements(3), gemma,
              render: (_) async => null)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(gemma.calls, 0);
      expect(content.recognizedInkText, contains('wobbly ink'));
    });

    test('a page where ML Kit read nothing at all goes to Gemma whole',
        () async {
      // Not a doodle: if NO line reads, ML Kit is not the right tool for this
      // handwriting, and the page must not come back empty.
      readings = []; // every recognise call returns no candidates
      final gemma = FakeTranscriber(const ['Gemma read the whole page fine here']);

      final content = await mlFirst(lineElements(3), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(rendered, [
        ['l1', 'l2', 'l3']
      ]);
      expect(content.recognizedInkText, 'Gemma read the whole page fine here');
    });

    test('a page that is mostly weak goes whole rather than line by line',
        () async {
      // 2 of 3 lines weak: three small reads cost more than one page read, and
      // ML Kit is clearly struggling with this hand.
      readings = [
        (text: ':::: ??', score: 9.0),
        (text: 'Vectors span a space', score: 1.0),
        (text: '#### @@', score: 9.0),
      ];
      final gemma = FakeTranscriber(const ['The whole page, read by Gemma here']);

      final content = await mlFirst(lineElements(3), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(gemma.calls, 1);
      expect(rendered, [
        ['l1', 'l2', 'l3']
      ]);
      expect(content.recognizedInkText, 'The whole page, read by Gemma here');
    });

    test('too many separate weak regions go whole, not one call each', () async {
      // 4 isolated weak lines among 9: under the "mostly weak" bar, but four
      // model calls is past the point where one page read is cheaper.
      readings = [
        for (var i = 0; i < 9; i++)
          i.isEven && i < 8
              ? (text: ':::: ??', score: 9.0)
              : (text: 'A readable line number $i', score: 1.0),
      ];
      final gemma = FakeTranscriber(const ['Everything, read in a single pass']);

      await mlFirst(lineElements(9), gemma)
          .extractPage(1, languageCode: 'en', useVision: true);

      expect(gemma.calls, 1);
      expect(rendered.single, hasLength(9));
    });

    test('Re-read sends the whole page to Gemma first, as before', () async {
      readings = [
        (text: 'Sentence segmentation splits text', score: 1.0),
        (text: 'Tokens are the units of text', score: 2.0),
      ];
      final gemma = FakeTranscriber(const ['A fresh reading from the model']);

      final content = await mlFirst(lineElements(2), gemma).extractPage(1,
          languageCode: 'en', useVision: true, varyVision: true);

      expect(rendered, [
        ['l1', 'l2']
      ]);
      expect(content.recognizedInkText, 'A fresh reading from the model');
    });

    test('a missing Gemma model still surfaces when a weak line needs it',
        () async {
      readings = [
        (text: 'Eigenvalues describe scaling', score: 1.0),
        (text: 'wobbly ink', score: 9.0),
        (text: 'Vectors span a space', score: 1.0),
      ];
      final gemma = FakeTranscriber(const [],
          throwError: const AiModelNotReadyException('not downloaded'));

      await expectLater(
        mlFirst(lineElements(3), gemma)
            .extractPage(1, languageCode: 'en', useVision: true),
        throwsA(isA<AiModelNotReadyException>()),
      );
    });

    group('the figure pass over the drawn layer', () {
      // The drawn layer includes the ink, so a deep read of any handwriting page
      // used to run a full figure pass over it — a vision call that answers
      // {"kind": "none"} for plain prose, and loads the model just to say so.
      // That would undo the point of reading ink with ML Kit first.
      const noFigure = '{"kind":"none"}';
      const box = SceneShapeElement(
        id: 'box1',
        zOrder: 9,
        shapeType: ShapeType.rectangle,
        geometryData: [200, 0, 320, 60],
        color: 0xFF000000,
        strokeWidth: 2,
      );

      test('handwriting ML Kit read cleanly makes no model call at all',
          () async {
        readings = [
          (text: 'Sentence segmentation splits text', score: 1.0),
          (text: 'Tokens are the units of text', score: 2.0),
        ];
        final gemma = FakeTranscriber(const ['must not run']);
        final figures = FakeTranscriber(const [noFigure]);

        await mlFirst(lineElements(2), gemma,
                figureAnalyzer: FigureAnalyzer(local: figures))
            .extractPage(1, languageCode: 'en', useVision: true);

        expect(gemma.calls, 0);
        expect(figures.calls, 0,
            reason: 'plain handwriting is not a drawing; no vision pass');
      });

      test('a shape on the page still gets the figure pass', () async {
        readings = [
          (text: 'Sentence segmentation splits text', score: 1.0),
        ];
        final figures = FakeTranscriber(const [noFigure]);

        await mlFirst([...lineElements(1), box], FakeTranscriber(const ['x']),
                figureAnalyzer: FigureAnalyzer(local: figures))
            .extractPage(1, languageCode: 'en', useVision: true);

        expect(figures.calls, 1);
      });

      test('ink ML Kit could not fully read still gets the figure pass',
          () async {
        // A weak line is as likely a diagram drawn with the pen as messy writing.
        readings = [
          (text: 'Eigenvalues describe scaling', score: 1.0),
          (text: ':::: ??', score: 9.0),
          (text: 'Vectors span a space', score: 1.0),
        ];
        final figures = FakeTranscriber(const [noFigure]);

        await mlFirst(lineElements(3),
                FakeTranscriber(const ['Matrices represent linear maps']),
                figureAnalyzer: FigureAnalyzer(local: figures))
            .extractPage(1, languageCode: 'en', useVision: true);

        expect(figures.calls, 1);
      });

      test('ink with a stroke that read as no text at all gets it too',
          () async {
        readings = [
          (text: 'Sentence segmentation splits text', score: 1.0),
          (text: '', score: 0.0), // a doodle: no candidates
        ];
        final figures = FakeTranscriber(const [noFigure]);

        await mlFirst(lineElements(2), FakeTranscriber(const ['x']),
                figureAnalyzer: FigureAnalyzer(local: figures))
            .extractPage(1, languageCode: 'en', useVision: true);

        expect(figures.calls, 1);
      });

      test('with ML Kit first off, ink gets the figure pass as it always did',
          () async {
        final figures = FakeTranscriber(const [noFigure]);

        await mlFirst(lineElements(1),
                FakeTranscriber(const ['Gemma reads this handwriting fine']),
                figureAnalyzer: FigureAnalyzer(local: figures),
                mlKitFirstInk: false)
            .extractPage(1, languageCode: 'en', useVision: true);

        expect(figures.calls, 1);
      });
    });

    test('without useVision nothing changes: ML Kit alone, as always', () async {
      readings = [(text: 'Just the light read', score: 1.0)];
      final gemma = FakeTranscriber(const ['must not run']);

      final content = await mlFirst(lineElements(1), gemma)
          .extractPage(1, languageCode: 'en');

      expect(gemma.calls, 0);
      expect(content.recognizedInkText, 'Just the light read');
    });
  });


  group('persistent read cache — a read is never paid for twice', () {
    const image = ImageElement(
        id: 'img',
        zOrder: 0,
        geometryData: [0, 0, 100, 100],
        relativeImagePath: 'imports/page1.png');
    const chartJson = '{"kind":"chart","title":"Revenue",'
        '"summary":"A bar chart of revenue across four quarters.",'
        '"insight":"Revenue roughly quadruples.",'
        '"verbatim_text":"Q1 Q2 Q3 Q4 revenue by quarter chart","confidence":0.9}';
    const box = SceneShapeElement(
      id: 'box1',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 120, 60],
      color: 0xFF000000,
      strokeWidth: 2,
    );

    /// A "session": a fresh extractor and a fresh model, sharing only [cache] —
    /// which is all that survives an app restart.
    Future<PageContent> session(
      List<SceneElement> elements,
      FakeTranscriber model, {
      ReadCache? cache,
      String modelId = 'model-a',
      bool slow = false,
      bool lite = false,
      bool persist = true,
      bool vary = false,
      bool figures = false,
      bool mlKitFirst = false,
      InkImageRenderer? render,
    }) =>
        extractor(
          elements,
          visionOcr: GemmaVisionOcrService(transcriber: model),
          loadImageBytes: loadBytes,
          renderInk: render ?? renderInk,
          figureAnalyzer: figures
              ? FigureAnalyzer(local: model, localModelId: modelId)
              : null,
          localIsSlow: () => slow,
          lite: () => lite,
          mlKitFirstInk: mlKitFirst,
          readCache: cache,
          readModelId: () => modelId,
          persistReads: persist,
        ).extractPage(1,
            languageCode: 'en', useVision: true, varyVision: vary);

    test('an image read once is not read again in a later session', () async {
      final cache = InMemoryReadCache();
      final first = FakeTranscriber(const ['Corpus: a large, structured set of texts.']);
      await session([image], first, cache: cache);
      expect(first.calls, 1);

      final second = FakeTranscriber(const ['SOMETHING ELSE ENTIRELY HERE']);
      final content = await session([image], second, cache: cache);

      expect(second.calls, 0, reason: 'no model load for content already read');
      expect(content.recognizedImageText,
          'Corpus: a large, structured set of texts.');
    });

    test('the figure is remembered with its text', () async {
      final cache = InMemoryReadCache();
      final first = FakeTranscriber(const [chartJson]);
      final original = await session([image], first, cache: cache, figures: true);
      expect(first.calls, 1, reason: 'one merged read gives both');

      final second = FakeTranscriber(const ['{"kind":"none"}']);
      final again = await session([image], second, cache: cache, figures: true);

      expect(second.calls, 0);
      expect(again.figures, original.figures);
      expect(again.recognizedImageText, original.recognizedImageText);
      expect(again.figures.single.title, 'Revenue');
    });

    test('Re-read skips the cache and replaces what it held', () async {
      final cache = InMemoryReadCache();
      await session([image],
          FakeTranscriber(const ['The old transcription of this page']),
          cache: cache);

      final reread = FakeTranscriber(const ['The new transcription of this page']);
      final fresh = await session([image], reread, cache: cache, vary: true);
      expect(reread.calls, 1, reason: 'asking to read it again must read it');
      expect(fresh.recognizedImageText, 'The new transcription of this page');

      final later = FakeTranscriber(const ['NOT ASKED FOR THIS ONE']);
      final cached = await session([image], later, cache: cache);
      expect(later.calls, 0);
      expect(cached.recognizedImageText, 'The new transcription of this page',
          reason: 'the corrected reading is what is remembered now');
    });

    test('a different model reads afresh', () async {
      final cache = InMemoryReadCache();
      await session([image],
          FakeTranscriber(const ['Read by the first model entirely']),
          cache: cache, modelId: 'model-a');

      final other = FakeTranscriber(const ['Read by the second model entirely']);
      final content =
          await session([image], other, cache: cache, modelId: 'model-b');

      expect(other.calls, 1);
      expect(content.recognizedImageText, 'Read by the second model entirely');
    });

    test('a read that found nothing is not remembered', () async {
      // An empty result is as likely a transient failure as a blank image;
      // caching it would stop the page ever being read properly.
      final cache = InMemoryReadCache();
      await session([image], FakeTranscriber(const ['']), cache: cache);
      expect(cache.entries, isEmpty);

      final retry = FakeTranscriber(const ['A proper reading, second time']);
      final content = await session([image], retry, cache: cache);
      expect(retry.calls, 1);
      expect(content.recognizedImageText, 'A proper reading, second time');
    });

    test('a read made while the local model is slow is not remembered, '
        'but an earlier full read still is used', () async {
      // On the CPU the output is capped and the figure passes are skipped, so
      // that read is a degraded one; remembering it would pin the degradation
      // even after the device is back on the GPU.
      final cache = InMemoryReadCache();
      await session([image],
          FakeTranscriber(const ['A degraded reading made on the CPU']),
          cache: cache, slow: true);
      expect(cache.entries, isEmpty);

      await session([image],
          FakeTranscriber(const ['The full reading made on the GPU']),
          cache: cache);
      final slowLater = FakeTranscriber(const ['NOT ASKED FOR THIS ONE']);
      final content = await session([image], slowLater, cache: cache, slow: true);

      expect(slowLater.calls, 0);
      expect(content.recognizedImageText, 'The full reading made on the GPU');
    });

    test('a slow device is served the full read a healthy session made, '
        'figure included', () async {
      // The slow session skips the figure pass, but that must not change WHICH
      // remembered read it finds — or the very device that most needs cache hits
      // would never get one.
      final cache = InMemoryReadCache();
      final healthy = FakeTranscriber(const [chartJson]);
      await session([image], healthy, cache: cache, figures: true);
      expect(healthy.calls, 1);

      final slow = FakeTranscriber(const ['NOT ASKED FOR THIS ONE']);
      final content =
          await session([image], slow, cache: cache, figures: true, slow: true);

      expect(slow.calls, 0);
      expect(content.figures.single.title, 'Revenue');
      expect(content.recognizedImageText, contains('revenue by quarter'));
    });

    test('a lite device still remembers its reads — text only', () async {
      // Lite drops the figure pass to save RAM, but its output is not cut short,
      // so there is nothing wrong with what it read. It is the device that most
      // needs a cache, so it must not be shut out of one.
      final cache = InMemoryReadCache();
      final first = FakeTranscriber(const ['Corpus: a large, structured set of texts.']);
      await session([image], first, cache: cache, figures: true, lite: true);
      expect(cache.entries, hasLength(1));

      final second = FakeTranscriber(const ['NOT ASKED FOR THIS ONE']);
      final content = await session([image], second,
          cache: cache, figures: true, lite: true);

      expect(second.calls, 0);
      expect(content.recognizedImageText,
          'Corpus: a large, structured set of texts.');
    });

    test('a lite read is not mistaken for a full one by a healthy session',
        () async {
      // It was read WITHOUT the figure pass. Stored as if it had been read with
      // one, it would pass for "this image has no figure" — and a device that
      // can do figures would never be shown the chart on the page.
      final cache = InMemoryReadCache();
      await session([image],
          FakeTranscriber(const ['Revenue by quarter across the year here']),
          cache: cache, figures: true, lite: true);

      final healthy = FakeTranscriber(const [chartJson]);
      final content =
          await session([image], healthy, cache: cache, figures: true);

      expect(healthy.calls, 1, reason: 'a text-only read is not a full read');
      expect(content.figures.single.title, 'Revenue');
    });

    test('Gemma\'s reading of a weak line of handwriting is remembered by '
        'what was drawn', () async {
      final cache = InMemoryReadCache();
      // The ML Kit side is mocked per recognise call, as in the group above.
      void mlKitReads() => TestDefaultBinaryMessengerBinding
              .instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'vision#startDigitalInkRecognizer') return 'success';
            final queue = _inkQueue;
            final next = queue.removeAt(0);
            return [
              {'text': next.$1, 'score': next.$2}
            ];
          });
      List<FreehandElement> lines() => [
            for (var i = 0; i < 3; i++)
              FreehandElement(
                id: 'l$i',
                zOrder: i,
                color: 0xFF000000,
                size: 2,
                points: [
                  StrokePoint(x: 10, y: 100.0 * i, t: 0),
                  StrokePoint(x: 60, y: 100.0 * i + 20, t: 40),
                ],
              ),
          ];
      void queueLines() {
        _inkQueue
          ..clear()
          ..addAll(const [
            ('Eigenvalues describe scaling', 1.0),
            (':::: ??', 9.0),
            ('Vectors span a space', 1.0),
          ]);
        mlKitReads();
      }

      queueLines();
      final first = FakeTranscriber(const ['Matrices represent linear maps']);
      await session(lines(), first, cache: cache, mlKitFirst: true);
      expect(first.calls, 1);

      queueLines(); // a new session: ML Kit reads the page again, cheaply
      final second = FakeTranscriber(const ['NOT ASKED FOR THIS ONE']);
      final content = await session(lines(), second, cache: cache, mlKitFirst: true);

      expect(second.calls, 0);
      expect(content.recognizedInkText, contains('Matrices represent linear maps'));
    });

    test('a whole-page ink read is remembered too', () async {
      final cache = InMemoryReadCache();
      await session([_ink],
          FakeTranscriber(const ['Sentence Segmentation is splitting text']),
          cache: cache);

      final second = FakeTranscriber(const ['NOT ASKED FOR THIS ONE']);
      final content = await session([_ink], second, cache: cache);

      expect(second.calls, 0);
      expect(content.recognizedInkText,
          'Sentence Segmentation is splitting text');
    });

    test('a drawn figure is remembered by how it was drawn', () async {
      final cache = InMemoryReadCache();
      await session([box], FakeTranscriber(const [chartJson]),
          cache: cache, figures: true);

      final second = FakeTranscriber(const ['{"kind":"none"}']);
      final content =
          await session([box], second, cache: cache, figures: true);

      expect(second.calls, 0);
      expect(content.figures.single.title, 'Revenue');
    });

    test('a cache that fails costs the page nothing', () async {
      final model = FakeTranscriber(const ['Read despite the broken cache here']);
      final content = await session([image], model, cache: _BrokenCache());

      expect(content.recognizedImageText, 'Read despite the broken cache here');
    });

    test('the flag turns it off: nothing is looked up or saved', () async {
      final cache = InMemoryReadCache();
      await session([image], FakeTranscriber(const ['First reading of the page']),
          cache: cache, persist: false);
      expect(cache.entries, isEmpty);

      await session([image], FakeTranscriber(const ['Second reading of the page']),
          cache: cache); // persist on: saves
      final off = FakeTranscriber(const ['Third reading of the page']);
      final content =
          await session([image], off, cache: cache, persist: false);
      expect(off.calls, 1, reason: 'with the flag off the cache is not consulted');
      expect(content.recognizedImageText, 'Third reading of the page');
    });

    test('the light read (no useVision) never touches the cache', () async {
      final cache = InMemoryReadCache();
      await extractor(
        [image],
        readImageText: (_) async => 'ml kit light read of the picture',
        loadImageBytes: loadBytes,
        readCache: cache,
      ).extractPage(1, languageCode: 'en');

      expect(cache.entries, isEmpty);
    });
  });

  group('figures (charts and diagrams)', () {
    const chartJson = '{"kind":"chart","title":"Revenue",'
        '"summary":"A bar chart of revenue across four quarters.",'
        '"insight":"Revenue roughly quadruples.","confidence":0.9}';

    /// A flowchart box — the case that used to be invisible entirely, because
    /// shapes carry no text of their own and were never rendered for vision.
    const box = SceneShapeElement(
      id: 'box1',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 120, 60],
      color: 0xFF000000,
      strokeWidth: 2,
    );

    const image = ImageElement(
      id: 'img',
      zOrder: 0,
      geometryData: [0, 0, 200, 200],
      relativeImagePath: 'imports/chart.png',
      sourceDescription: '',
    );

    FigureAnalyzer analyzer(List<String> replies, {Object? throwError}) =>
        FigureAnalyzer(
          local: FakeTranscriber(replies, throwError: throwError),
          localModelId: 'local-x',
        );

    test('a shape-only page produces a figure', () async {
      final content = await extractor(
        [box],
        renderInk: renderInk,
        figureAnalyzer: analyzer(const [chartJson]),
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.figures, hasLength(1));
      expect(content.figures.single.kind, FigureKind.chart);
      // The page has no words at all, yet is no longer empty to the AI.
      expect(content.combinedText, isEmpty);
      expect(content.combinedTextWithFigures, contains('Revenue'));
    });

    test('a pasted image is analysed as a figure', () async {
      final content = await extractor(
        [image],
        loadImageBytes: loadBytes,
        figureAnalyzer: analyzer(const [chartJson]),
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.figures, hasLength(1));
      // An image we understood is read content, so it is no longer "unread".
      expect(content.sources.single.needsOcr, isFalse);
    });

    test('the optional figure passes are skipped while the local model is slow',
        () async {
      // On the CPU every figure call is a full vision decode several times
      // slower than usual, for something the page can do without. The image's
      // TEXT is not optional, so it still gets its plain OCR read.
      final figureCalls = FakeTranscriber(const [chartJson]);
      final content = await extractor(
        [box, image],
        renderInk: renderInk,
        loadImageBytes: loadBytes,
        visionOcr:
            vision(const ['Revenue by quarter across the financial year']),
        figureAnalyzer:
            FigureAnalyzer(local: figureCalls, localModelId: 'local-x'),
        localIsSlow: () => true,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(figureCalls.calls, 0, reason: 'no figure pass of either kind');
      expect(content.figures, isEmpty);
      expect(content.recognizedImageText, contains('Revenue by quarter'));
    });

    test('a healthy local model still gets the figure passes', () async {
      final content = await extractor(
        [box],
        renderInk: renderInk,
        figureAnalyzer: analyzer(const [chartJson]),
        localIsSlow: () => false,
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.figures, hasLength(1));
    });

    test('the figure pass is skipped entirely without useVision', () async {
      final transcriber = FakeTranscriber(const [chartJson]);
      final content = await extractor(
        [box],
        renderInk: renderInk,
        figureAnalyzer:
            FigureAnalyzer(local: transcriber, localModelId: 'local-x'),
      ).extractPage(1, languageCode: 'en');

      expect(content.figures, isEmpty);
      expect(transcriber.calls, 0,
          reason: 'the passive light path must not pay for a VLM call');
    });

    test('a page of typed text alone never triggers a figure call', () async {
      const text = TextElement(
        id: 't1',
        zOrder: 0,
        geometryData: [0, 0, 100, 20],
        text: 'just some typed words',
        color: 0xFF000000,
        fontSize: 14,
      );
      final transcriber = FakeTranscriber(const [chartJson]);
      final content = await extractor(
        [text],
        renderInk: renderInk,
        figureAnalyzer:
            FigureAnalyzer(local: transcriber, localModelId: 'local-x'),
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.figures, isEmpty);
      expect(transcriber.calls, 0);
    });

    test('"no figure here" leaves the page figure-free', () async {
      final content = await extractor(
        [box],
        renderInk: renderInk,
        figureAnalyzer: analyzer(const ['{"kind":"none"}']),
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.figures, isEmpty);
    });

    test('a failed figure read never costs the page its text', () async {
      recognizedText = 'the ink still reads fine';
      final content = await extractor(
        [_ink],
        renderInk: renderInk,
        figureAnalyzer: analyzer(const [],
            throwError: const AiGenerationException('vision blew up')),
      ).extractPage(1, languageCode: 'en', useVision: true);

      expect(content.figures, isEmpty);
      expect(content.recognizedInkText, 'the ink still reads fine');
    });

    test('a selection can be analysed for figures too', () async {
      final content = await extractor(
        [box],
        renderInk: renderInk,
        figureAnalyzer: analyzer(const [chartJson]),
      ).extractSelection(1, {'box1'}, languageCode: 'en', useVision: true);

      expect(content.figures, hasLength(1));
    });
  });
}
