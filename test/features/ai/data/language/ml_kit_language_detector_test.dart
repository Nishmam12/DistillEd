import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/data/language/ml_kit_language_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_language_identifier');
  final calls = <MethodCall>[];

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the language tag ML Kit finds', () async {
    answerWith((_) async => 'bn');

    expect(await MlKitLanguageDetector().identify('আমি ভালো আছি'), 'bn');
  });

  test('romanised Bangla comes back as bn-Latn', () async {
    answerWith((_) async => 'bn-Latn');

    expect(await MlKitLanguageDetector().identify('ami bhalo achi'), 'bn-Latn');
  });

  test('"und" — no language found — is passed through, it is an answer',
      () async {
    answerWith((_) async => 'und');

    expect(await MlKitLanguageDetector().identify('qzx vbn mwk'), 'und');
  });

  test('asks for the main language of the text, at the default confidence',
      () async {
    answerWith((_) async => 'en');

    await MlKitLanguageDetector().identify('hello there');

    final args = calls.single.arguments as Map;
    expect(calls.single.method, 'nlp#startLanguageIdentifier');
    expect(args['text'], 'hello there');
    expect(args['possibleLanguages'], isFalse);
    expect(args['confidence'], 0.5);
  });

  test('a platform failure is null — "could not say", not "no language"',
      () async {
    answerWith((_) async => throw PlatformException(code: 'x', message: 'boom'));

    expect(await MlKitLanguageDetector().identify('hello there'), isNull);
  });

  test('a missing plugin is null, not a crash', () async {
    // No handler registered: the channel answers MissingPluginException.
    expect(await MlKitLanguageDetector().identify('hello there'), isNull);
  });

  test('one native identifier is reused, and closed on dispose', () async {
    answerWith((_) async => 'en');
    final detector = MlKitLanguageDetector();

    await detector.identify('hello there');
    await detector.identify('good morning');
    await detector.dispose();

    final starts =
        calls.where((c) => c.method == 'nlp#startLanguageIdentifier').toList();
    expect(
        (starts[0].arguments as Map)['id'], (starts[1].arguments as Map)['id']);
    expect(calls.last.method, 'nlp#closeLanguageIdentifier');
  });

  test('disposing a detector that never ran closes nothing', () async {
    answerWith((_) async => null);

    await MlKitLanguageDetector().dispose();

    expect(calls, isEmpty);
  });
}
