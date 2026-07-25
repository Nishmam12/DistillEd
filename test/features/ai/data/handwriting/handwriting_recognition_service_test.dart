import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/migration/legacy_models/stroke.dart';
import 'package:inkflow/domain/model/stroke_point.dart';
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
