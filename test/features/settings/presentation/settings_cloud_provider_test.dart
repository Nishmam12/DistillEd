// The Cloud AI provider row, its dialog and the AI-mode hint. The dialog checks
// a typed key by listing the provider's models before it closes, so a rejected
// key is never saved; these run it against a fake lister.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/core/theme/margo_theme.dart';
import 'package:margo/features/ai/data/providers/openai_compatible_provider.dart';
import 'package:margo/features/home/data/repositories/note_repository.dart';
import 'package:margo/features/home/presentation/home_notifier.dart'
    show noteRepositoryProvider;
import 'package:margo/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'sk-test-123';
const _hint = 'Cloud modes need a key. Add one under Cloud AI provider.';

/// A keystore whose reads wait until [release], so "not loaded yet" can be seen.
class _SlowStore extends InMemorySecretStore {
  final _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<String?> read(String key) async {
    await _gate.future;
    return super.read(key);
  }
}

class _Repo implements NoteRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object> _savedProvider() => {
  'ai.cloudPresetId': 'openrouter',
  'ai.cloudBaseUrl': 'https://openrouter.ai/api/v1',
  'ai.cloudModel': 'google/gemma-3-27b-it',
};

InMemorySecretStore _storeWithKey() =>
    InMemorySecretStore()..values['ai.cloudApiKey'] = _key;

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required SecretStore store,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secretStoreProvider.overrideWithValue(store),
        noteRepositoryProvider.overrideWithValue(_Repo()),
      ],
      child: MaterialApp(theme: MargoTheme.light, home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the dialog from a button and records what it pops.
Future<List<CloudProviderResult?>> _openDialog(
  WidgetTester tester, {
  required CloudModelLister listModels,
  String presetId = '',
  String baseUrl = '',
  bool hasKey = false,
  String model = '',
}) async {
  final popped = <CloudProviderResult?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: MargoTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => popped.add(
            await showDialog<CloudProviderResult>(
              context: context,
              builder: (_) => CloudProviderDialog(
                presetId: presetId,
                baseUrl: baseUrl,
                model: model,
                hasKey: hasKey,
                listModels: listModels,
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

Future<void> _choosePreset(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('cloudPreset')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Future<void> _checkKey(WidgetTester tester) async {
  // Let the button that appears after typing build before it is tapped.
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cloudCheckKey')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(_neverCalls.clear);

  group('Cloud AI provider row', () {
    testWidgets('claims nothing before the keystore is read', (tester) async {
      final store = _SlowStore();
      await _pumpScreen(tester, const AiModelsScreen(), store: store);

      expect(find.text('Cloud AI provider'), findsOneWidget);
      expect(find.text('Add a key to use cloud AI'), findsNothing);

      store.release();
      await tester.pumpAndSettle();
      expect(find.text('Add a key to use cloud AI'), findsOneWidget);
    });

    testWidgets('with no key it asks for one', (tester) async {
      await _pumpScreen(
        tester,
        const AiModelsScreen(),
        store: InMemorySecretStore(),
        prefs: _savedProvider(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a key to use cloud AI'), findsOneWidget);
      expect(find.text('Add'), findsWidgets);
    });

    testWidgets('with a key it names the provider and model', (tester) async {
      await _pumpScreen(
        tester,
        const AiModelsScreen(),
        store: _storeWithKey(),
        prefs: _savedProvider(),
      );
      await tester.pumpAndSettle();

      expect(find.text('OpenRouter · google/gemma-3-27b-it'), findsOneWidget);
      expect(find.text('Change'), findsWidgets);
      expect(find.textContaining(_key), findsNothing);
    });
  });

  group('CloudProviderDialog', () {
    testWidgets('the custom preset shows the base URL field', (tester) async {
      await _openDialog(tester, listModels: _never);
      expect(find.byKey(const ValueKey('cloudBaseUrl')), findsNothing);

      await _choosePreset(tester, 'Custom (OpenAI-compatible)');
      expect(find.byKey(const ValueKey('cloudBaseUrl')), findsOneWidget);
    });

    testWidgets('an unsafe custom URL blocks Save', (tester) async {
      var calls = 0;
      final popped = await _openDialog(
        tester,
        listModels: ({required baseUrl, required apiKey}) async {
          calls++;
          return const [];
        },
      );
      await _choosePreset(tester, 'Custom (OpenAI-compatible)');
      await tester.enterText(
        find.byKey(const ValueKey('cloudBaseUrl')),
        'http://example.com/v1',
      );
      await tester.enterText(find.byKey(const ValueKey('cloudKey')), _key);
      await tester.enterText(
        find.byKey(const ValueKey('cloudModelName')),
        'llama3',
      );
      await _tapSave(tester);

      expect(popped, isEmpty);
      expect(find.byType(CloudProviderDialog), findsOneWidget);
      expect(
        find.text(
          'Use https://, or http:// only for localhost or a private address.',
        ),
        findsOneWidget,
      );
      expect(calls, 0); // the key never went to the unsafe URL
    });

    testWidgets('a rejected key keeps the dialog open', (tester) async {
      final popped = await _openDialog(
        tester,
        listModels: ({required baseUrl, required apiKey}) async =>
            throw const CloudModelListException(
              'Your AI API key was rejected.',
              keyRejected: true,
            ),
      );
      await tester.enterText(find.byKey(const ValueKey('cloudKey')), 'sk-bad');
      await _tapSave(tester);

      expect(popped, isEmpty);
      expect(find.byType(CloudProviderDialog), findsOneWidget);
      expect(
        find.text('The provider rejected this key. Check it and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a non-auth failure falls back to a typed model name', (
      tester,
    ) async {
      final popped = await _openDialog(
        tester,
        listModels: ({required baseUrl, required apiKey}) async =>
            throw const CloudModelListException(
              'Could not load the model list.',
              keyRejected: false,
            ),
      );
      await tester.enterText(find.byKey(const ValueKey('cloudKey')), _key);
      await _checkKey(tester);

      expect(find.byKey(const ValueKey('cloudModelName')), findsOneWidget);
      expect(
        find.text('Could not load the model list. Type the model name.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('cloudModelName')),
        'my-model',
      );
      await _tapSave(tester);
      expect(popped.single!.model, 'my-model');
      expect(popped.single!.newKey, _key);
      expect(popped.single!.contextTokens, 0);
    });

    testWidgets('a good key returns the chosen model and its context', (
      tester,
    ) async {
      String? sentUrl;
      String? sentKey;
      final popped = await _openDialog(
        tester,
        model: 'b-model',
        listModels: ({required baseUrl, required apiKey}) async {
          sentUrl = baseUrl;
          sentKey = apiKey;
          return const [
            CloudModel(id: 'a-model', contextLength: 8000),
            CloudModel(id: 'b-model', contextLength: 128000),
          ];
        },
      );
      await tester.enterText(find.byKey(const ValueKey('cloudKey')), _key);
      await _checkKey(tester);

      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      await _tapSave(tester);

      final result = popped.single!;
      expect(result.presetId, 'openrouter');
      expect(result.baseUrl, 'https://openrouter.ai/api/v1');
      expect(result.model, 'b-model'); // the saved model, not the first
      expect(result.contextTokens, 128000);
      expect(result.newKey, _key);
      expect(result.clearKey, isFalse);
      expect(sentUrl, 'https://openrouter.ai/api/v1');
      expect(sentKey, _key);
    });

    testWidgets('typing a key lists nothing until Check key is tapped', (
      tester,
    ) async {
      var calls = 0;
      await _openDialog(
        tester,
        presetId: 'openrouter',
        baseUrl: 'https://openrouter.ai/api/v1',
        listModels: ({required baseUrl, required apiKey}) async {
          calls++;
          return const [CloudModel(id: 'a-model')];
        },
      );
      await tester.enterText(find.byKey(const ValueKey('cloudKey')), _key);
      await tester.pumpAndSettle();
      expect(calls, 0, reason: 'nothing is sent while the user is typing');

      await _checkKey(tester);
      expect(calls, 1);
    });

    testWidgets('the key checked is the key that is saved', (tester) async {
      String? checked;
      final popped = await _openDialog(
        tester,
        presetId: 'openrouter',
        baseUrl: 'https://openrouter.ai/api/v1',
        listModels: ({required baseUrl, required apiKey}) async {
          checked = apiKey;
          return const [CloudModel(id: 'a-model')];
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('cloudKey')),
        '  "$_key"  ',
      );
      await _checkKey(tester);
      expect(checked, _key);

      await _tapSave(tester);
      expect(popped.single!.newKey, _key);
    });

    testWidgets('no new key closes without a check, keeping the saved one', (
      tester,
    ) async {
      final popped = await _openDialog(
        tester,
        presetId: 'openrouter',
        baseUrl: 'https://openrouter.ai/api/v1',
        hasKey: true,
        model: 'saved-model',
        listModels: _never,
      );
      expect(
        find.text('Saved on this device. Leave blank to keep it.'),
        findsOneWidget,
      );
      await _tapSave(tester);

      expect(popped.single!.model, 'saved-model');
      expect(popped.single!.newKey, isNull);
      expect(_neverCalls, isEmpty);
    });

    testWidgets('a saved key is never sent to a changed provider', (
      tester,
    ) async {
      final popped = await _openDialog(
        tester,
        presetId: 'openrouter',
        baseUrl: 'https://openrouter.ai/api/v1',
        hasKey: true,
        model: 'saved-model',
        listModels: _never,
      );
      await _choosePreset(tester, 'Google Gemini');
      // The key stays hidden, but its hint must stop promising it is kept.
      expect(
        find.text('Saved on this device. Leave blank to keep it.'),
        findsNothing,
      );
      await _tapSave(tester);

      // Save refuses without a key for this provider, so nothing is popped and
      // the lister (which would send the old key) is never reached.
      expect(popped, isEmpty);
      expect(_neverCalls, isEmpty);
      expect(
        find.text(
          'The saved key is for another provider. Paste the key for this one.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Remove key pops a clear request', (tester) async {
      final popped = await _openDialog(
        tester,
        presetId: 'openrouter',
        hasKey: true,
        model: 'saved-model',
        listModels: _never,
      );
      await tester.tap(find.text('Remove key'));
      await tester.pumpAndSettle();
      expect(popped.single!.clearKey, isTrue);
    });
  });

  group('AI processing hint', () {
    testWidgets('shows in a cloud mode with no key', (tester) async {
      await _pumpScreen(
        tester,
        const SettingsScreen(),
        store: InMemorySecretStore(),
        prefs: {'ai.mode': 'auto'},
      );
      await tester.pumpAndSettle();
      expect(find.text(_hint), findsOneWidget);
    });

    testWidgets('hides once a key is saved', (tester) async {
      await _pumpScreen(
        tester,
        const SettingsScreen(),
        store: _storeWithKey(),
        prefs: {'ai.mode': 'auto', ..._savedProvider()},
      );
      await tester.pumpAndSettle();
      expect(find.text(_hint), findsNothing);
    });

    testWidgets('hides on-device', (tester) async {
      await _pumpScreen(
        tester,
        const SettingsScreen(),
        store: InMemorySecretStore(),
        prefs: {'ai.mode': 'onDevice'},
      );
      await tester.pumpAndSettle();
      expect(find.text(_hint), findsNothing);
    });
  });
}

/// Every call to [_never]. The dialog swallows a thrown error as a non-auth
/// failure, so a test checks this list instead of waiting for an exception.
final List<String> _neverCalls = [];

/// A lister that must not be reached.
Future<List<CloudModel>> _never({
  required String baseUrl,
  required String apiKey,
}) {
  _neverCalls.add(baseUrl);
  throw StateError('listModels should not be called');
}
