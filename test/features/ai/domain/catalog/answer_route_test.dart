import 'package:flutter_test/flutter_test.dart';

import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/domain/catalog/answer_route.dart';
import 'package:margo/features/ai/domain/catalog/cloud_consent.dart';

const _mine = AiModelEntry(
  id: 'user:c1:big',
  displayName: 'My AI · Big',
  source: ModelSource.userKey,
  contextWindowTokens: 32000,
  host: 'api.example.com',
);

const _margoFree = AiModelEntry(
  id: 'margo:free',
  displayName: 'Margo Free',
  source: ModelSource.margo,
  tier: MargoTier.free,
  contextWindowTokens: 128000,
);

const _margoComingSoon = AiModelEntry(
  id: 'margo:free',
  displayName: 'Margo Free',
  source: ModelSource.margo,
  tier: MargoTier.free,
  contextWindowTokens: 128000,
  available: false,
);

const _margoPremium = AiModelEntry(
  id: 'margo:premium',
  displayName: 'Margo Premium',
  source: ModelSource.margo,
  tier: MargoTier.premium,
  contextWindowTokens: 200000,
  locked: true,
);

AnswerRoute _route({
  AiProcessingMode aiMode = AiProcessingMode.auto,
  CloudPrivacy privacy = CloudPrivacy.askEachTime,
  String choice = kAnswerAuto,
  List<AiModelEntry> catalogue = const [_mine, _margoFree],
}) =>
    resolveAnswerRoute(
      aiMode: aiMode,
      privacy: privacy,
      answerModelId: choice,
      catalogue: catalogue,
    );

void main() {
  group('nothing leaves the device', () {
    test('when cloud AI is off, whatever model is stored as the choice', () {
      for (final choice in [kAnswerAuto, kAnswerLocal, _mine.id]) {
        expect(
          _route(aiMode: AiProcessingMode.onDevice, choice: choice),
          isA<LocalOnly>(),
          reason: choice,
        );
      }
    });

    test('when privacy is local only, whatever model is stored', () {
      for (final mode in [AiProcessingMode.auto, AiProcessingMode.cloudFirst]) {
        expect(
          _route(
            aiMode: mode,
            privacy: CloudPrivacy.localOnly,
            choice: _mine.id,
          ),
          isA<LocalOnly>(),
          reason: mode.name,
        );
      }
    });

    test('when the student picked the on-device model', () {
      for (final mode in [AiProcessingMode.auto, AiProcessingMode.cloudFirst]) {
        expect(_route(aiMode: mode, choice: kAnswerLocal), isA<LocalOnly>());
      }
    });
  });

  group('auto', () {
    test('answers on the device first, with Margo cloud as the fallback', () {
      final route = _route() as LocalFirst;
      expect(route.escalation, _margoFree);
    });

    test('never falls back to a model reached with the student\'s own key', () {
      final route = _route(catalogue: const [_mine]) as LocalFirst;
      expect(route.escalation, isNull);
    });

    test('has no fallback while Margo cloud is not available', () {
      final route =
          _route(catalogue: const [_mine, _margoComingSoon]) as LocalFirst;
      expect(route.escalation, isNull);
    });

    test('does not fall back to a locked model', () {
      final route =
          _route(catalogue: const [_margoPremium, _margoFree]) as LocalFirst;
      expect(route.escalation, _margoFree);
    });

    test('behaves the same under cloud-first, which is about reading pages',
        () {
      expect(_route(aiMode: AiProcessingMode.cloudFirst), isA<LocalFirst>());
    });
  });

  group('a picked cloud model', () {
    test('answers directly', () {
      for (final mode in [AiProcessingMode.auto, AiProcessingMode.cloudFirst]) {
        for (final privacy in [
          CloudPrivacy.askEachTime,
          CloudPrivacy.allowCloudForNonSensitive,
        ]) {
          final route = _route(aiMode: mode, privacy: privacy, choice: _mine.id);
          expect((route as CloudDirect).model, _mine,
              reason: '${mode.name} ${privacy.name}');
        }
      }
    });

    test('that no longer exists falls back to auto', () {
      final route = _route(choice: 'user:deleted:model') as LocalFirst;
      expect(route.escalation, _margoFree);
    });

    test('that is locked falls back to auto', () {
      final route = _route(
        choice: _margoPremium.id,
        catalogue: const [_margoPremium],
      );
      expect(route, isA<LocalFirst>());
    });

    test('that is not available right now falls back to auto', () {
      final route = _route(
        choice: _margoComingSoon.id,
        catalogue: const [_margoComingSoon],
      );
      expect(route, isA<LocalFirst>());
    });
  });

  group('whether the stored choice still names something usable', () {
    test('auto and on-device always do', () {
      expect(answerChoiceIsUsable(kAnswerAuto, const []), isTrue);
      expect(answerChoiceIsUsable(kAnswerLocal, const []), isTrue);
    });

    test('a model in the list does, a deleted one does not', () {
      expect(answerChoiceIsUsable(_mine.id, const [_mine]), isTrue);
      expect(answerChoiceIsUsable(_mine.id, const []), isFalse);
      expect(answerChoiceIsUsable(_margoPremium.id, const [_margoPremium]),
          isFalse);
    });
  });

  group('needsSendConfirmation', () {
    bool needs({
      CloudPrivacy privacy = CloudPrivacy.allowCloudForNonSensitive,
      bool firstEver = false,
      bool firstUse = false,
    }) =>
        needsSendConfirmation(
          privacy: privacy,
          firstEverCloudCall: firstEver,
          firstUseOfModel: firstUse,
        );

    test('asks every time under ask-each-time', () {
      expect(needs(privacy: CloudPrivacy.askEachTime), isTrue);
    });

    test('asks on the very first cloud call, whatever the setting', () {
      expect(needs(firstEver: true), isTrue);
    });

    test('asks the first time a new connection is used', () {
      expect(needs(firstUse: true), isTrue);
    });

    test('does not ask again once allowed and already explained', () {
      expect(needs(), isFalse);
    });
  });
}
