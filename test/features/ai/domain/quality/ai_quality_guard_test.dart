import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/quality/ai_quality_guard.dart';
import 'package:inkflow/features/ai/domain/quality/output_quality.dart';

/// Emits a canned reply, split into chunks so the streaming path is exercised,
/// and counts calls so a test can prove the cloud was (or was not) reached.
class FakeProvider implements AiProvider {
  FakeProvider(this.reply, {this.throws = false});

  final String reply;
  final bool throws;
  var calls = 0;
  String? lastPrompt;
  String? lastSystemPrompt;

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    calls++;
    lastPrompt = prompt;
    lastSystemPrompt = systemPrompt;
    if (throws) throw const AiUnavailableException('gateway down');
    for (final word in reply.split(' ')) {
      yield '$word ';
    }
  }

  @override
  Future<List<double>> embed(String text) async => const [];

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'fake',
        displayName: 'Fake',
        contextWindowTokens: 4096,
      );
}

const _goodAnswer = 'Photosynthesis happens in the chloroplast, where the '
    'light-dependent reactions take place in the thylakoid membrane.';

const _brokenAnswer = 'The answer is in the notes. The answer is in the notes. '
    'The answer is in the notes. The answer is in the notes.';

AiQualityGuard buildGuard({
  required FakeProvider local,
  FakeProvider? cloud,
  bool cloudEnabled = true,
  CloudPrivacy privacy = CloudPrivacy.allowCloudForNonSensitive,
  bool online = true,
}) =>
    AiQualityGuard(
      local: local,
      cloud: cloud,
      cloudEnabled: () => cloudEnabled,
      privacy: () => privacy,
      isOnline: () async => online,
    );

void main() {
  group('good local output is left alone', () {
    test('passes through as AnswerTier.local', () async {
      final local = FakeProvider(_goodAnswer);
      final cloud = FakeProvider('should never run');

      final result = await buildGuard(local: local, cloud: cloud)
          .run(prompt: 'q', systemPrompt: 'sys');

      expect(result.tier, AnswerTier.local);
      expect(result.text.trim(), _goodAnswer);
      expect(result.issue, isNull);
      expect(result.isLowConfidence, isFalse);
    });

    test('does NOT reach the cloud — no over-triggering', () async {
      final cloud = FakeProvider('should never run');
      await buildGuard(local: FakeProvider(_goodAnswer), cloud: cloud)
          .run(prompt: 'q');

      expect(cloud.calls, 0,
          reason: 'a perfectly good local answer must not cost a network call');
    });

    test('a grounded refusal does not trigger the cloud', () async {
      // The most damaging false escalation: the cloud would answer an honest
      // "not in your notes" from world knowledge.
      const refusal = "I couldn't find the answer to that in your notes.";
      final cloud = FakeProvider('Napoleon was crowned in 1804.');

      final result = await buildGuard(
        local: FakeProvider(refusal),
        cloud: cloud,
      ).run(
        prompt: 'q',
        quality: const QualityContext(
          sourcePassages: ['Photosynthesis converts light into glucose.'],
          allowedRefusal: refusal,
        ),
      );

      expect(cloud.calls, 0);
      expect(result.tier, AnswerTier.local);
    });

    test('streams the local answer as it arrives', () async {
      final seen = <String>[];
      await buildGuard(local: FakeProvider(_goodAnswer))
          .run(prompt: 'q', onPartial: seen.add);

      expect(seen.first, '', reason: 'each attempt starts from empty');
      expect(seen.length, greaterThan(2), reason: 'streaming is preserved');
      expect(seen.last.trim(), _goodAnswer);
    });
  });

  group('broken local output escalates to the cloud', () {
    test('a repetition loop is re-run on the cloud and marked verified',
        () async {
      final cloud = FakeProvider(_goodAnswer);

      final result = await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: cloud,
      ).run(prompt: 'q', systemPrompt: 'sys');

      expect(cloud.calls, 1);
      expect(result.tier, AnswerTier.cloudVerified);
      expect(result.text.trim(), _goodAnswer);
      expect(result.issue, QualityIssue.repetition);
    });

    test('an empty local reply escalates', () async {
      final cloud = FakeProvider(_goodAnswer);
      final result =
          await buildGuard(local: FakeProvider(''), cloud: cloud).run(prompt: 'q');

      expect(result.tier, AnswerTier.cloudVerified);
      expect(result.issue, QualityIssue.empty);
    });

    test('the cloud is asked the same question, with the same system prompt',
        () async {
      final cloud = FakeProvider(_goodAnswer);
      await buildGuard(local: FakeProvider(_brokenAnswer), cloud: cloud)
          .run(prompt: 'the question', systemPrompt: 'the rules');

      // A re-run that changed the request would not be a check on anything.
      expect(cloud.lastPrompt, 'the question');
      expect(cloud.lastSystemPrompt, 'the rules');
    });

    test('the UI is told to clear the bad answer before the cloud one arrives',
        () async {
      final seen = <String>[];
      await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: FakeProvider(_goodAnswer),
      ).run(prompt: 'q', onPartial: seen.add);

      expect(seen.where((s) => s.isEmpty).length, 2,
          reason: 'one reset per attempt, so the view replaces rather than '
              'appends');
      expect(seen.last.trim(), _goodAnswer);
    });
  });

  group('the privacy contract gates escalation', () {
    test('localOnly never escalates, and says the answer is unreliable',
        () async {
      final cloud = FakeProvider(_goodAnswer);

      final result = await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: cloud,
        privacy: CloudPrivacy.localOnly,
      ).run(prompt: 'q');

      expect(cloud.calls, 0);
      expect(result.tier, AnswerTier.localLowConfidence);
      expect(result.isLowConfidence, isTrue);
      expect(result.canRetryOnCloud, isFalse,
          reason: 'offering a button the setting forbids would be a lie');
    });

    test('askEachTime does not escalate on its own initiative', () async {
      // The default setting. A quality failure is not consent — the whole point
      // of this test is that a bad local answer never silently reaches the
      // network.
      final cloud = FakeProvider(_goodAnswer);

      final result = await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: cloud,
        privacy: CloudPrivacy.askEachTime,
      ).run(prompt: 'q');

      expect(cloud.calls, 0, reason: 'no silent cloud call, ever');
      expect(result.tier, AnswerTier.localLowConfidence);
      expect(result.canRetryOnCloud, isTrue,
          reason: 'the UI offers the check; the user decides');
    });

    test('askEachTime escalates once the user actually asks', () async {
      final cloud = FakeProvider(_goodAnswer);
      final guard = buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: cloud,
        privacy: CloudPrivacy.askEachTime,
      );

      final first = await guard.run(prompt: 'q');
      expect(cloud.calls, 0);

      final second = await guard.retryOnCloud(
          prompt: 'q', localText: first.text, issue: first.issue);

      expect(cloud.calls, 1);
      expect(second.tier, AnswerTier.cloudVerified);
    });

    test('cloud AI switched off never escalates', () async {
      final cloud = FakeProvider(_goodAnswer);

      final result = await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: cloud,
        cloudEnabled: false,
      ).run(prompt: 'q');

      expect(cloud.calls, 0);
      expect(result.tier, AnswerTier.localLowConfidence);
      expect(result.canRetryOnCloud, isFalse);
    });

    test('offline never escalates, and does not offer a button that would fail',
        () async {
      final cloud = FakeProvider(_goodAnswer);

      final result = await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: cloud,
        privacy: CloudPrivacy.askEachTime,
        online: false,
      ).run(prompt: 'q');

      expect(cloud.calls, 0);
      expect(result.canRetryOnCloud, isFalse);
    });

    test('with no cloud provider wired it degrades to low confidence', () async {
      final result = await buildGuard(local: FakeProvider(_brokenAnswer))
          .run(prompt: 'q');

      expect(result.tier, AnswerTier.localLowConfidence);
      expect(result.text.trim(), _brokenAnswer.trim(),
          reason: 'the local text is still shown, just labelled');
    });
  });

  group('the cloud is not trusted blindly either', () {
    test('a cloud answer that is ALSO broken is not marked verified', () async {
      final result = await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: FakeProvider(_brokenAnswer),
      ).run(prompt: 'q');

      expect(result.tier, AnswerTier.localLowConfidence,
          reason: 'a network call does not make an answer correct');
    });

    test('a cloud failure keeps the local answer rather than erroring out',
        () async {
      final result = await buildGuard(
        local: FakeProvider(_brokenAnswer),
        cloud: FakeProvider('', throws: true),
      ).run(prompt: 'q');

      expect(result.tier, AnswerTier.localLowConfidence);
      expect(result.text.trim(), _brokenAnswer.trim());
    });
  });

  test('the grounding context reaches the check', () async {
    // An answer written from world knowledge, with passages that do not support
    // it: the guard must escalate on ignoredSources, not pass it through.
    final cloud = FakeProvider(_goodAnswer);
    final result = await buildGuard(
      local: FakeProvider('Napoleon Bonaparte was crowned Emperor of the '
          'French at Notre-Dame after rising through the artillery.'),
      cloud: cloud,
    ).run(
      prompt: 'q',
      quality: const QualityContext(sourcePassages: [
        'Photosynthesis converts light energy into glucose in the chloroplast.'
      ]),
    );

    expect(result.issue, QualityIssue.ignoredSources);
    expect(cloud.calls, 1);
  });
}
