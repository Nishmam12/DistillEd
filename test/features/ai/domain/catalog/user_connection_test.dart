import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/domain/catalog/provider_preset.dart';
import 'package:margo/features/ai/domain/catalog/user_connection.dart';

const _groq = UserConnection(
  id: 'c1',
  label: 'My Groq',
  presetId: 'groq',
  baseUrl: 'https://api.groq.com/openai/v1',
  models: [
    UserModel(
      modelId: 'llama-big',
      displayName: 'Llama big',
      contextWindowTokens: 32000,
      supportsTools: true,
    ),
    UserModel(modelId: 'tiny', displayName: 'Tiny'),
  ],
);

void main() {
  group('UserConnection JSON', () {
    test('a list survives an encode and decode unchanged', () {
      final decoded = decodeConnections(encodeConnections(const [_groq]));

      expect(decoded, hasLength(1));
      final c = decoded.single;
      expect(c.id, 'c1');
      expect(c.label, 'My Groq');
      expect(c.presetId, 'groq');
      expect(c.baseUrl, 'https://api.groq.com/openai/v1');
      expect(c.consentShown, isFalse);
      expect(c.models.map((m) => m.modelId), ['llama-big', 'tiny']);
      expect(c.models.first.contextWindowTokens, 32000);
      expect(c.models.first.supportsTools, isTrue);
    });

    test('consentShown is kept', () {
      final decoded = decodeConnections(
        encodeConnections([_groq.copyWith(consentShown: true)]),
      );
      expect(decoded.single.consentShown, isTrue);
    });

    test('nothing stored reads as no connections', () {
      expect(decodeConnections(null), isEmpty);
      expect(decodeConnections(''), isEmpty);
    });

    test('text that is not JSON reads as no connections', () {
      expect(decodeConnections('{not json'), isEmpty);
      expect(decodeConnections('"a string"'), isEmpty);
    });

    test('one broken entry does not lose the others', () {
      final raw = '[{"id":7},${encodeConnections(const [_groq]).substring(1)}';
      expect(decodeConnections(raw).map((c) => c.id), ['c1']);
    });
  });

  group('a model with no stated window', () {
    test('gets the conservative default, never a large guess', () {
      expect(_groq.models.last.contextWindowTokens, kUnknownModelWindowTokens);
      expect(kUnknownModelWindowTokens, 8000);
    });

    test('is assumed not to support tools', () {
      expect(_groq.models.last.supportsTools, isFalse);
    });
  });

  group('catalogue entries from a connection', () {
    test('one entry per model, named after the connection and the model', () {
      final entries = _groq.entries;

      expect(entries.map((e) => e.id), [
        'user:c1:llama-big',
        'user:c1:tiny',
      ]);
      expect(entries.first.displayName, 'My Groq · Llama big');
      expect(entries.first.source, ModelSource.userKey);
      expect(entries.first.contextWindowTokens, 32000);
      expect(entries.first.supportsTools, isTrue);
      expect(entries.first.pickable, isTrue);
    });

    test('carry the host that text will be sent to', () {
      expect(_groq.entries.first.host, 'api.groq.com');
    });

    test('an entry id leads back to its connection and model', () {
      final ref = UserModelRef.parse('user:c1:llama-big');
      expect(ref?.connectionId, 'c1');
      expect(ref?.modelId, 'llama-big');
    });

    test('a model id containing colons is kept whole', () {
      final ref = UserModelRef.parse('user:c1:org/model:free');
      expect(ref?.modelId, 'org/model:free');
    });

    test('an id that is not a user model has no reference', () {
      expect(UserModelRef.parse('auto'), isNull);
      expect(UserModelRef.parse('margo:free'), isNull);
      expect(UserModelRef.parse('user:c1'), isNull);
    });
  });

  group('AiModelEntry.pickable', () {
    AiModelEntry entry({bool locked = false, bool available = true}) =>
        AiModelEntry(
          id: 'margo:x',
          displayName: 'X',
          source: ModelSource.margo,
          contextWindowTokens: 8000,
          locked: locked,
          available: available,
        );

    test('a locked model cannot be picked', () {
      expect(entry(locked: true).pickable, isFalse);
    });

    test('an unavailable model cannot be picked', () {
      expect(entry(available: false).pickable, isFalse);
    });
  });

  group('validateBaseUrl', () {
    test('accepts an https address', () {
      expect(validateBaseUrl('https://api.example.com/v1'), isNull);
    });

    test('refuses plain http, which would send the key unencrypted', () {
      expect(validateBaseUrl('http://api.example.com/v1'), isNotNull);
    });

    test('refuses text that is not an address', () {
      expect(validateBaseUrl('api.example.com'), isNotNull);
      expect(validateBaseUrl(''), isNotNull);
      expect(validateBaseUrl('https://'), isNotNull);
    });
  });

  group('ProviderPreset', () {
    test('every preset address passes the same check a typed one must', () {
      for (final preset in ProviderPreset.all) {
        expect(validateBaseUrl(preset.baseUrl), isNull, reason: preset.id);
      }
    });

    test('ids are unique', () {
      final ids = [for (final p in ProviderPreset.all) p.id];
      expect(ids.toSet().length, ids.length);
    });

    test('an unknown id is the custom preset', () {
      expect(ProviderPreset.byId('nope').id, ProviderPreset.customId);
    });
  });
}
