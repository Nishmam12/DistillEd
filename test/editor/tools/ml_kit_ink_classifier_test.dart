import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/tools/ink_gestures.dart';
import 'package:inkflow/editor/tools/ml_kit_ink_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_digital_ink_recognizer');
  final calls = <MethodCall>[];
  var present = true;
  List<Map<String, Object?>> candidates = [
    {'text': 'RECTANGLE', 'score': 0.12},
    {'text': 'ELLIPSE', 'score': 0.4},
  ];

  const stroke = FreehandElement(
    id: 's',
    zOrder: 0,
    color: 0xFF000000,
    size: 3,
    points: [
      StrokePoint(x: 10, y: 20, t: 0),
      StrokePoint(x: 60, y: 22, t: 40),
      StrokePoint(x: 60, y: 80, t: 90),
    ],
  );

  setUp(() {
    calls.clear();
    present = true;
    candidates = [
      {'text': 'RECTANGLE', 'score': 0.12},
      {'text': 'ELLIPSE', 'score': 0.4},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'vision#manageInkModels':
          return present;
        case 'vision#startDigitalInkRecognizer':
          return candidates;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Iterable<MethodCall> recognitions() =>
      calls.where((c) => c.method == 'vision#startDigitalInkRecognizer');

  test('the best candidate is the answer, with its score', () async {
    final answer =
        await MlKitInkClassifier().classify(stroke, model: kShapesModel);

    expect(answer, isNotNull);
    expect(answer!.label, 'RECTANGLE');
    expect(answer.score, 0.12);
  });

  test('asks the model it was told to, about this stroke', () async {
    await MlKitInkClassifier().classify(stroke, model: kGestureModel);

    final args = recognitions().single.arguments as Map;
    expect(args['model'], kGestureModel);
    final strokes = (args['ink'] as Map)['strokes'] as List;
    expect(strokes, hasLength(1));
    expect(((strokes.single as Map)['points'] as List), hasLength(3));
  });

  test('a model that is not on the device is "no answer" — and nothing is '
      'recognised, so nothing is downloaded behind the student\'s back',
      () async {
    present = false;

    final answer =
        await MlKitInkClassifier().classify(stroke, model: kShapesModel);

    expect(answer, isNull);
    expect(recognitions(), isEmpty);
    expect(calls.any((c) => (c.arguments as Map?)?['task'] == 'download'), isFalse);
  });

  test('once the model is known to be there it is not checked again', () async {
    final classifier = MlKitInkClassifier();

    await classifier.classify(stroke, model: kShapesModel);
    await classifier.classify(stroke, model: kShapesModel);

    final checks = calls.where((c) => c.method == 'vision#manageInkModels');
    expect(checks, hasLength(1));
  });

  test('a model that was missing is checked again — it may have been '
      'downloaded since', () async {
    present = false;
    final classifier = MlKitInkClassifier();
    await classifier.classify(stroke, model: kShapesModel);

    present = true;
    final answer = await classifier.classify(stroke, model: kShapesModel);

    expect(answer?.label, 'RECTANGLE');
  });

  test('a model that is STILL missing stays "no answer", however often asked',
      () async {
    present = false;
    final classifier = MlKitInkClassifier();

    await classifier.classify(stroke, model: kShapesModel);
    final second = await classifier.classify(stroke, model: kShapesModel);

    expect(second, isNull);
    expect(recognitions(), isEmpty);
  });

  test('nothing recognised is "no answer"', () async {
    candidates = [];

    expect(await MlKitInkClassifier().classify(stroke, model: kShapesModel),
        isNull);
  });

  test('one recogniser is kept per model and reused', () async {
    final classifier = MlKitInkClassifier();

    await classifier.classify(stroke, model: kShapesModel);
    await classifier.classify(stroke, model: kShapesModel);
    await classifier.classify(stroke, model: kGestureModel);

    final ids = recognitions().map((c) => (c.arguments as Map)['id']).toList();
    expect(ids[0], ids[1]);
    expect(ids[2], isNot(ids[0]));
  });

  test('disposing closes every recogniser it opened', () async {
    final classifier = MlKitInkClassifier();
    await classifier.classify(stroke, model: kShapesModel);
    await classifier.classify(stroke, model: kGestureModel);

    await classifier.dispose();

    final closes = calls.where((c) => c.method == 'vision#closeDigitalInkRecognizer');
    expect(closes, hasLength(2));
  });

  test('a platform failure reaches the caller, who treats it as no answer',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#manageInkModels') return true;
      throw PlatformException(code: 'x', message: 'boom');
    });

    await expectLater(
        MlKitInkClassifier().classify(stroke, model: kShapesModel),
        throwsA(isA<Exception>()));
  });
}
