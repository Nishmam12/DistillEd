import 'package:flutter_test/flutter_test.dart';

import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/presentation/cloud_send_gate.dart';

const _mine = AiModelEntry(
  id: 'user:c1:big',
  displayName: 'My AI · Big',
  source: ModelSource.userKey,
  contextWindowTokens: 32000,
  host: 'api.example.com',
);

void main() {
  late CloudPrivacy privacy;
  late bool seenFirstCloudCall;
  late Set<String> consented;
  late CloudSendGate gate;

  CloudSendGate build({Duration timeout = const Duration(seconds: 60)}) =>
      CloudSendGate(
        privacy: () => privacy,
        hasSeenFirstCloudCall: () => seenFirstCloudCall,
        hasConsentedTo: (model) => consented.contains(model.id),
        markConsented: (model) async {
          seenFirstCloudCall = true;
          consented.add(model.id);
        },
        timeout: timeout,
      );

  setUp(() {
    privacy = CloudPrivacy.allowCloudForNonSensitive;
    seenFirstCloudCall = true;
    consented = {_mine.id};
    gate = build();
  });

  test('says yes at once when no question is needed', () async {
    expect(await gate.confirm(_mine), isTrue);
    expect(gate.state, isNull);
  });

  test('under ask-each-time it shows the model and where the text goes',
      () async {
    privacy = CloudPrivacy.askEachTime;

    final answer = gate.confirm(_mine);
    await Future<void>.delayed(Duration.zero);

    expect(gate.state?.modelName, 'My AI · Big');
    expect(gate.state?.host, 'api.example.com');
    expect(gate.state?.firstEver, isFalse);

    gate.answer(true);
    expect(await answer, isTrue);
    expect(gate.state, isNull);
  });

  test('a no means nothing is sent and nothing is remembered', () async {
    consented.clear();

    final answer = gate.confirm(_mine);
    await Future<void>.delayed(Duration.zero);
    gate.answer(false);

    expect(await answer, isFalse);
    expect(consented, isEmpty);
    expect(gate.state, isNull);
  });

  test('a new model is asked about once, then remembered', () async {
    consented.clear();

    final first = gate.confirm(_mine);
    await Future<void>.delayed(Duration.zero);
    gate.answer(true);
    expect(await first, isTrue);
    expect(consented, {_mine.id});

    expect(await gate.confirm(_mine), isTrue, reason: 'no second question');
    expect(gate.state, isNull);
  });

  test('the very first cloud call gets the longer explanation', () async {
    seenFirstCloudCall = false;

    final answer = gate.confirm(_mine);
    await Future<void>.delayed(Duration.zero);

    expect(gate.state?.firstEver, isTrue);
    gate.answer(true);
    await answer;
    expect(seenFirstCloudCall, isTrue);
  });

  test('a second request while a question is showing is declined', () async {
    privacy = CloudPrivacy.askEachTime;

    final first = gate.confirm(_mine);
    await Future<void>.delayed(Duration.zero);

    expect(await gate.confirm(_mine), isFalse);
    expect(gate.state, isNotNull, reason: 'the first question is still up');

    gate.answer(true);
    expect(await first, isTrue);
  });

  test('a question nobody answers counts as a no', () async {
    privacy = CloudPrivacy.askEachTime;
    gate = build(timeout: const Duration(milliseconds: 20));

    expect(await gate.confirm(_mine), isFalse);
    expect(gate.state, isNull);
  });

  test('an answer with no question showing does nothing', () {
    gate.answer(true);
    expect(gate.state, isNull);
  });
}
