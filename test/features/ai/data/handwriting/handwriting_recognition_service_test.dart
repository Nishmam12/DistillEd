import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/migration/legacy_models/stroke.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/ai/data/handwriting/handwriting_recognition_service.dart';

/// Tests the service against a mocked ML Kit platform channel — no device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_digital_ink_recognizer');
  final log = <MethodCall>[];

  /// Queue of candidate lists returned by successive recognize calls.
  List<List<Map<String, Object>>> recognizeResponses = [];
  bool modelDownloaded = true;

  setUp(() {
    log.clear();
    recognizeResponses = [];
    modelDownloaded = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      switch (call.method) {
        case 'vision#startDigitalInkRecognizer':
          return recognizeResponses.isEmpty
              ? <Map<String, Object>>[]
              : recognizeResponses.removeAt(0);
        case 'vision#manageInkModels':
          final task = call.arguments['task'] as String;
          if (task == 'check') return modelDownloaded;
          return 'success';
        case 'vision#closeDigitalInkRecognizer':
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Stroke inkStroke(double y, {int? t0}) => Stroke(
        id: 'y$y',
        color: 0xFF000000,
        size: 4,
        points: [
          StrokePoint(x: 0, y: y, t: t0),
          StrokePoint(x: 10, y: y, t: t0 == null ? null : t0 + 16),
        ],
      );

  group('recognizePage', () {
    test('returns the top candidate and sends timestamped ink', () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': 'hello world', 'score': 1.5},
          {'text': 'hello word', 'score': 3.0},
        ],
      ];

      final page =
          await service.recognizePage([inkStroke(0, t0: 5000)], 'en');

      expect(page.text, 'hello world');
      expect(page.topScore, 1.5);
      expect(page.hasInk, isTrue);

      final call =
          log.singleWhere((c) => c.method == 'vision#startDigitalInkRecognizer');
      expect(call.arguments['model'], 'en');
      final strokes = (call.arguments['ink'] as Map)['strokes'] as List;
      final points = (strokes.first as Map)['points'] as List;
      expect(points.every((p) => (p as Map).containsKey('t')), isTrue,
          reason: 'every point sent to ML Kit must carry a timestamp');
    });

    test('page with no ink returns empty without calling the channel',
        () async {
      final service = HandwritingRecognitionService();
      final page = await service.recognizePage(
          [const Stroke(id: 'e', color: 0, size: 4, isEraser: true, points: [
        StrokePoint(x: 0, y: 0),
      ])], 'en');

      expect(page.hasInk, isFalse);
      expect(page.text, isEmpty);
      expect(log.where((c) => c.method == 'vision#startDigitalInkRecognizer'),
          isEmpty);
    });

    test('zero candidates → empty text but hasInk stays true', () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [[]];
      final page = await service.recognizePage([inkStroke(0)], 'en');
      expect(page.text, isEmpty);
      expect(page.topScore, isNull);
      expect(page.hasInk, isTrue);
    });

    test('platform failure is wrapped in RecognitionException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'MODEL_NOT_DOWNLOADED');
      });
      final service = HandwritingRecognitionService();
      expect(
        () => service.recognizePage([inkStroke(0)], 'en'),
        throwsA(isA<RecognitionException>()),
      );
    });
  });

  /// A stroke of ink as the editor stores it: 20 units tall so lines have height
  /// (a perfectly flat stroke cannot be split into columns), starting at [x],[y].
  FreehandElement element(String id, double y, {double x = 0}) =>
      FreehandElement(
        id: id,
        zOrder: 0,
        color: 0xFF000000,
        size: 4,
        points: [
          StrokePoint(x: x, y: y, t: 0),
          StrokePoint(x: x + 10, y: y + 20, t: 16),
        ],
      );

  group('recognizeElements — page-level behaviour (pinned before refactoring)',
      () {
    test('joins the lines in reading order, and the score is their mean',
        () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': 'first line', 'score': 1.0}
        ],
        [
          {'text': 'second line', 'score': 3.0}
        ],
      ];

      final page = await service.recognizeElements(
          [element('b', 200), element('a', 0)], 'en');

      expect(page.text, 'first line\nsecond line');
      expect(page.topScore, 2.0);
    });

    test('the score is a mean over SEGMENTS, so a table row counts per column',
        () async {
      final service = HandwritingRecognitionService();
      // Line 1 is a two-column row (two recognise calls, scores 1 and 3); line 2
      // is one segment (score 5). Mean of segments = (1+3+5)/3 = 3.0, where a
      // mean of line means would be (2+5)/2 = 3.5.
      recognizeResponses = [
        [
          {'text': 'Topic', 'score': 1.0}
        ],
        [
          {'text': 'Regression', 'score': 3.0}
        ],
        [
          {'text': 'a note below', 'score': 5.0}
        ],
      ];

      final page = await service.recognizeElements([
        element('c1', 0, x: 0),
        element('c2', 0, x: 900),
        element('n', 200),
      ], 'en');

      expect(page.text, 'Topic  Regression\na note below');
      expect(page.topScore, 3.0);
    });

    test('a line that reads as nothing leaves no blank line behind', () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': 'kept', 'score': 1.0}
        ],
        [], // the second line: ML Kit returns no candidates
        [
          {'text': 'also kept', 'score': 1.0}
        ],
      ];

      final page = await service.recognizeElements(
          [element('a', 0), element('b', 200), element('c', 400)], 'en');

      expect(page.text, 'kept\nalso kept');
    });
  });

  group('recognizeInkLines', () {
    test('one entry per handwritten line, top to bottom, each with its own '
        'text, score and place', () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': 'first line', 'score': 1.0}
        ],
        [
          {'text': 'second line', 'score': 3.0}
        ],
      ];

      final lines = await service.recognizeInkLines(
          [element('b', 200), element('a', 0)], 'en');

      expect([for (final l in lines) l.text], ['first line', 'second line']);
      expect([for (final l in lines) l.score], [1.0, 3.0]);
      expect(lines[0].bounds.top, 0);
      expect(lines[1].bounds.top, 200);
    });

    test('each line carries its own strokes, so it can be re-rendered alone',
        () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': 'a', 'score': 1.0}
        ],
        [
          {'text': 'b', 'score': 1.0}
        ],
      ];
      final top = element('top', 0);
      final bottom = element('bottom', 200);

      final lines = await service.recognizeInkLines([bottom, top], 'en');

      // The very point lists the editor holds, not copies: the caller maps a
      // line back to its elements by identity.
      expect(identical(lines[0].strokes.single, top.points), isTrue);
      expect(identical(lines[1].strokes.single, bottom.points), isTrue);
    });

    test('a line that reads as nothing is still reported, with empty text',
        () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [[]];

      final lines = await service.recognizeInkLines([element('doodle', 0)], 'en');

      // The caller decides what an unreadable line means (a doodle, or a page
      // ML Kit cannot read at all) — it must be able to see it.
      expect(lines, hasLength(1));
      expect(lines.single.text, isEmpty);
      expect(lines.single.score, isNull);
    });

    test('a line made of columns joins them and averages their scores',
        () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': 'Topic', 'score': 1.0}
        ],
        [
          {'text': 'Regression', 'score': 3.0}
        ],
      ];

      final lines = await service.recognizeInkLines(
          [element('c1', 0, x: 0), element('c2', 0, x: 900)], 'en');

      expect(lines.single.text, 'Topic  Regression');
      expect(lines.single.score, 2.0);
      expect(lines.single.strokes, hasLength(2));
    });

    test('a page with no ink yields no lines and never calls ML Kit',
        () async {
      final service = HandwritingRecognitionService();

      final lines = await service.recognizeInkLines(const [], 'en');

      expect(lines, isEmpty);
      expect(log.where((c) => c.method == 'vision#startDigitalInkRecognizer'),
          isEmpty);
    });
  });

  group('recognizeNotebook', () {
    test('concatenates pages in order, skipping empty pages', () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': 'the quick brown fox jumps over the lazy dog', 'score': 1.0},
        ],
        [
          {'text': 'and runs far away again', 'score': 2.0},
        ],
      ];

      final outcome = await service.recognizeNotebook(
        [
          [inkStroke(0)], // page 1
          [], // page 2 — no ink, must be skipped without a channel call
          [inkStroke(10)], // page 3
        ],
        'en',
      );

      expect(outcome.text,
          'the quick brown fox jumps over the lazy dog\n\nand runs far away again');
      expect(outcome.pages, hasLength(3));
      expect(outcome.pages[1].hasInk, isFalse);
      expect(outcome.gate.passed, isTrue); // 14 words, alphabetic, scores low
      expect(
        log.where((c) => c.method == 'vision#startDigitalInkRecognizer'),
        hasLength(2),
      );
    });

    test('gate failure surfaces on gibberish notebooks', () async {
      final service = HandwritingRecognitionService();
      recognizeResponses = [
        [
          {'text': '7 42 --', 'score': 30.0},
        ],
      ];
      final outcome = await service.recognizeNotebook([
        [inkStroke(0)],
      ], 'en');
      expect(outcome.gate.passed, isFalse);
    });
  });

  group('model management', () {
    test('ensureModelDownloaded skips download when model present', () async {
      final service = HandwritingRecognitionService();
      modelDownloaded = true;
      await service.ensureModelDownloaded('en');
      final tasks = log
          .where((c) => c.method == 'vision#manageInkModels')
          .map((c) => c.arguments['task'])
          .toList();
      expect(tasks, ['check']);
    });

    test('ensureModelDownloaded downloads when missing (Wi-Fi not required)',
        () async {
      final service = HandwritingRecognitionService();
      modelDownloaded = false;
      await service.ensureModelDownloaded('bn');
      final manage =
          log.where((c) => c.method == 'vision#manageInkModels').toList();
      expect(manage.map((c) => c.arguments['task']), ['check', 'download']);
      expect(manage.last.arguments['model'], 'bn');
      expect(manage.last.arguments['wifi'], isFalse);
    });
  });
}
