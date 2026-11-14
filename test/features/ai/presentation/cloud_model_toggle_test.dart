// The two ways a student can turn cloud AI on from inside the AI panel — the
// header switch and the `/cloud` command — and the property that matters most:
// they are the same setting, so neither can show a stale state after the other
// has been used.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/data/embeddings/embedder_download_manager.dart';
import 'package:margo/features/ai/data/llm/model_download_manager.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/chat_commands.dart';
import 'package:margo/features/ai/domain/features/notes_qa.dart';
import 'package:margo/features/ai/domain/rag/rag_retriever.dart';
import 'package:margo/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:margo/features/ai/domain/rag/prompt_contract.dart';
import 'package:margo/features/ai/domain/rag/text_embedder.dart';
import 'package:margo/features/ai/presentation/ask_notes_notifier.dart';
import 'package:margo/features/ai/presentation/sidebar/ai_sidebar.dart';

class _NoopProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'noop',
        displayName: 'noop',
        contextWindowTokens: 4096,
      );
  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      const Stream.empty();
}

class _NoopEmbedder implements TextEmbedder {

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  @override
  int get chunkWords => kChunkWords;

  @override
  int get chunkOverlapWords => kChunkOverlapWords;

  @override
  String get modelId => 'noop';
  @override
  int get dimensions => 3;
  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      const [0, 0, 0];
  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      const [];
}

/// Builds a notifier wired to a real [SettingsNotifier], which is the point:
/// the command must write the same stored value the switch reads.
AskNotesNotifier buildNotifier(SettingsNotifier settings) => AskNotesNotifier(
      qa: NotesQa(
        provider: _NoopProvider(),
        retriever: RagRetriever(
          embedder: _NoopEmbedder(),
          loadChunks: (_) async => const [],
        ),
      ),
      llmDownloads: ModelDownloadManager(),
      embedderDownloads: EmbedderDownloadManager(authToken: () => null),
      cloudEnabled: () => settings.state.cloudAiEnabled,
      setCloudEnabled: settings.setCloudAiEnabled,
      hasCloudKey: () => settings.state.hasCloudKey,
      privacyAsksEachTime: () =>
          settings.state.cloudPrivacy == CloudPrivacy.askEachTime,
    );

/// Cloud needs a saved provider and key to turn on. These stand in for a real
/// one; nothing is sent anywhere.
const _cloudPrefs = <String, Object>{
  'ai.cloudPresetId': 'openrouter',
  'ai.cloudBaseUrl': 'https://openrouter.ai/api/v1',
  'ai.cloudModel': 'test-model',
};

InMemorySecretStore _storeWithKey() =>
    InMemorySecretStore()..values['ai.cloudApiKey'] = 'sk-test';

/// Saves a provider and key before the notifier restores, then waits for it.
Future<SettingsNotifier> settingsWithKey() async {
  SharedPreferences.setMockInitialValues(_cloudPrefs);
  final settings = SettingsNotifier(secrets: _storeWithKey());
  while (!settings.state.loaded) {
    await Future<void>.delayed(Duration.zero);
  }
  return settings;
}

/// No key saved (the store is empty, not the real keystore).
Future<SettingsNotifier> settingsWithoutKey() async {
  final settings = SettingsNotifier(secrets: InMemorySecretStore());
  while (!settings.state.loaded) {
    await Future<void>.delayed(Duration.zero);
  }
  return settings;
}

Widget wrap(Widget child, {SecretStore? secrets}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        secretStoreProvider.overrideWithValue(secrets ?? InMemorySecretStore()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

/// The toggle in a scope whose settings are reachable through the returned
/// ref. [withKey] saves a provider and key first.
Future<WidgetRef> pumpToggle(WidgetTester tester, {bool withKey = false}) async {
  if (withKey) SharedPreferences.setMockInitialValues(_cloudPrefs);
  late WidgetRef captured;
  await tester.pumpWidget(wrap(
    Consumer(builder: (context, ref, _) {
      captured = ref;
      return const CloudModelToggle();
    }),
    secrets: withKey ? _storeWithKey() : null,
  ));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the header toggle', () {
    testWidgets('renders a switch in the AI panel header', (tester) async {
      await tester.pumpWidget(wrap(const CloudModelToggle()));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('starts off — the privacy default is local-only', (tester) async {
      await tester.pumpWidget(wrap(const CloudModelToggle()));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('tapping it turns cloud AI on in settings', (tester) async {
      final captured = await pumpToggle(tester, withKey: true);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(captured.read(settingsProvider).cloudAiEnabled, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    });

    testWidgets('it does not touch the per-call confirmation contract',
        (tester) async {
      // Turning the opt-in on grants permission for the app to ASK. It must not
      // quietly promote the privacy mode to "send whatever you like".
      final captured = await pumpToggle(tester, withKey: true);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(captured.read(settingsProvider).cloudPrivacy,
          CloudPrivacy.askEachTime);
      expect(captured.read(settingsProvider).hasSeenFirstCloudCall, isFalse);
    });

    testWidgets('with no key it stays off, leaves the mode, and points to '
        'Settings', (tester) async {
      final captured = await pumpToggle(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(find.text('Add a cloud AI key in Settings first.'), findsOneWidget);
      expect(captured.read(settingsProvider).aiMode, AiProcessingMode.onDevice);
      expect(captured.read(settingsProvider).cloudAiEnabled, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('with no key the tooltip says a key is needed', (tester) async {
      await pumpToggle(tester);

      expect(find.byTooltip('Cloud AI needs a key — add one in Settings'),
          findsOneWidget);
    });
  });

  group('the /cloud command', () {
    test('turns the setting on and confirms instead of asking the model',
        () async {
      final settings = await settingsWithKey();
      final notifier = buildNotifier(settings);

      await notifier.ask('/cloud on', notebookId: 1);

      expect(settings.state.cloudAiEnabled, isTrue);
      expect(notifier.state, isA<AskNotesNotice>());
      expect((notifier.state as AskNotesNotice).message,
          cloudCommandConfirmation(enabled: true, privacyAsksEachTime: true));
    });

    test('without a key it says a key is needed, not that cloud is on',
        () async {
      final settings = await settingsWithoutKey();
      final notifier = buildNotifier(settings);

      await notifier.ask('/cloud on', notebookId: 1);

      expect(settings.state.cloudAiEnabled, isFalse);
      // The refused command wrote nothing, so the mode is still on-device and a
      // key added later does not switch cloud on by itself.
      expect(settings.state.aiMode, AiProcessingMode.onDevice);
      expect((notifier.state as AskNotesNotice).message, cloudNeedsKeyMessage);

      await notifier.ask('/cloud', notebookId: 1);
      expect((notifier.state as AskNotesNotice).message,
          cloudStateReport(enabled: false),
          reason: 'a bare /cloud reports the effective state');
    });

    test('turns the setting off again', () async {
      final settings = await settingsWithKey();
      await settings.setCloudAiEnabled(true);
      final notifier = buildNotifier(settings);

      await notifier.ask('/cloud off', notebookId: 1);

      expect(settings.state.cloudAiEnabled, isFalse);
    });

    test('natural phrasing works too', () async {
      final settings = await settingsWithKey();
      final notifier = buildNotifier(settings);

      await notifier.ask('use the cloud model', notebookId: 1);
      expect(settings.state.cloudAiEnabled, isTrue);

      await notifier.ask('switch to local model', notebookId: 1);
      expect(settings.state.cloudAiEnabled, isFalse);
    });

    test('a bare /cloud reports without changing anything', () async {
      final settings = SettingsNotifier();
      final notifier = buildNotifier(settings);

      await notifier.ask('/cloud', notebookId: 1);

      expect(settings.state.cloudAiEnabled, isFalse);
      expect((notifier.state as AskNotesNotice).message,
          cloudStateReport(enabled: false));
    });

    test('an unknown command says so rather than asking it', () async {
      final settings = SettingsNotifier();
      final notifier = buildNotifier(settings);

      await notifier.ask('/clod on', notebookId: 1);

      expect(notifier.state, isA<AskNotesNotice>());
      expect(settings.state.cloudAiEnabled, isFalse);
    });

    test('a real question is still asked', () async {
      final settings = SettingsNotifier();
      final notifier = buildNotifier(settings);

      await notifier.ask('What did I write about cloud computing?',
          notebookId: 1);

      // Retrieval finds nothing (empty fake store), so this lands on the
      // grounded not-found — the point is that it is NOT a notice.
      expect(notifier.state, isA<AskNotesNotFound>());
      expect(settings.state.cloudAiEnabled, isFalse);
    });
  });

  testWidgets('both entry points read the same setting and stay in sync',
      (tester) async {
    // The property the two-entry-point design lives or dies on. They share one
    // stored value, so a change through either is visible through the other.
    final captured = await pumpToggle(tester, withKey: true);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    // Flip it through the COMMAND path, against the same provider container.
    final settings = captured.read(settingsProvider.notifier);
    final notifier = buildNotifier(settings);
    await notifier.ask('/cloud on', notebookId: 1);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue,
        reason: 'the header switch reflects a change made by the command');

    // And back the other way: flip the switch, and the command's state report
    // must agree.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await notifier.ask('/cloud', notebookId: 1);

    expect((notifier.state as AskNotesNotice).message,
        cloudStateReport(enabled: false),
        reason: 'the command reflects a change made by the header switch');
  });
}
