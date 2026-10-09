import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/data/study_planner/ml_kit_date_finder.dart';
import 'package:distill_ed/features/ai/domain/study_planner/note_deadlines.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_entity_extractor');
  final calls = <MethodCall>[];

  // The plugin's wire format: `type` is the EntityType index (2 = dateTime) and
  // `dateTimeGranularity` the DateTimeGranularity index (4 = day, 3 = week,
  // 2 = month, 1 = year, 5 = hour).
  Map<String, Object?> dateAnnotation(DateTime when, int granularity,
          {String text = 'Oct 14'}) =>
      {
        'text': text,
        'start': 0,
        'end': text.length,
        'entities': [
          {
            'type': 2,
            'raw': 'DateTimeEntity',
            'dateTimeGranularity': granularity,
            'timestamp': when.millisecondsSinceEpoch,
          },
        ],
      };

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

  final now = DateTime(2026, 10, 2, 9, 30);

  test('reads a day out of the text', () async {
    final oct14 = DateTime(2026, 10, 14);
    answerWith((_) async => [dateAnnotation(oct14, 4)]);

    final dates = await MlKitDateFinder().find('Quiz 2 on Oct 14', now: now);

    expect(dates, [oct14]);
  });

  test('asks in English, for dates only, relative to now', () async {
    answerWith((_) async => <Object?>[]);

    await MlKitDateFinder().find('Quiz 2 on Oct 14', now: now);

    final args = calls.single.arguments as Map;
    expect(calls.single.method, 'nlp#startEntityExtractor');
    expect(args['language'], 'english');
    expect(args['text'], 'Quiz 2 on Oct 14');
    final params = args['parameters'] as Map;
    expect(params['time'], now.millisecondsSinceEpoch);
    expect(params['filters'], [2], reason: 'EntityType.dateTime only');
  });

  test('a time of day is still its day', () async {
    final at9 = DateTime(2026, 10, 14, 9, 0);
    answerWith((_) async => [dateAnnotation(at9, 5)]);

    expect(await MlKitDateFinder().find('Quiz at 9am Oct 14', now: now), [at9]);
  });

  test('"in October", "next week" and "2027" are not days to count down to',
      () async {
    answerWith((_) async => [
          dateAnnotation(DateTime(2026, 10, 1), 2, text: 'October'),
          dateAnnotation(DateTime(2026, 10, 5), 3, text: 'next week'),
          dateAnnotation(DateTime(2027, 1, 1), 1, text: '2027'),
        ]);

    expect(await MlKitDateFinder().find('Exam in October', now: now), isEmpty);
  });

  test('entities that are not dates are ignored', () async {
    answerWith((_) async => [
          {
            'text': '555-0100',
            'start': 0,
            'end': 8,
            'entities': [
              {'type': 8, 'raw': 'PhoneEntity'},
            ],
          },
        ]);

    expect(await MlKitDateFinder().find('call 555-0100', now: now), isEmpty);
  });

  test('every date in the text comes back, in the order written', () async {
    final oct14 = DateTime(2026, 10, 14);
    final nov20 = DateTime(2026, 11, 20);
    answerWith((_) async =>
        [dateAnnotation(oct14, 4), dateAnnotation(nov20, 4, text: 'Nov 20')]);

    expect(
        await MlKitDateFinder().find('Midterm Oct 14, final Nov 20', now: now),
        [oct14, nov20]);
  });

  test('one native extractor is reused, and closed on dispose', () async {
    answerWith((_) async => <Object?>[]);
    final finder = MlKitDateFinder();

    await finder.find('Quiz Oct 14', now: now);
    await finder.find('Exam Nov 3', now: now);
    await finder.dispose();

    final starts =
        calls.where((c) => c.method == 'nlp#startEntityExtractor').toList();
    expect((starts[0].arguments as Map)['id'], (starts[1].arguments as Map)['id']);
    expect(calls.last.method, 'nlp#closeEntityExtractor');
  });

  test('disposing a finder that never ran closes nothing', () async {
    answerWith((_) async => null);

    await MlKitDateFinder().dispose();

    expect(calls, isEmpty);
  });

  test('a model that cannot be loaded is DateFinderUnavailable', () async {
    answerWith((_) async => throw PlatformException(
        code: 'Error building extractor', message: 'Model not downloaded'));

    await expectLater(MlKitDateFinder().find('Quiz Oct 14', now: now),
        throwsA(isA<DateFinderUnavailable>()));
  });

  test('a missing plugin is DateFinderUnavailable, not a crash', () async {
    // No handler registered: the channel answers MissingPluginException.
    await expectLater(MlKitDateFinder().find('Quiz Oct 14', now: now),
        throwsA(isA<DateFinderUnavailable>()));
  });
}
