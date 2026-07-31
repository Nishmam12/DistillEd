// The two ways a student can turn cloud AI on from inside the AI panel — the
// header switch and the `/cloud` command — and the property that matters most:
// they are the same setting, so neither can show a stale state after the other
// has been used.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_download_manager.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/chat_commands.dart';
import 'package:inkflow/features/ai/domain/features/notes_qa.dart';
import 'package:inkflow/features/ai/domain/rag/rag_retriever.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';
import 'package:inkflow/features/ai/presentation/ask_notes_notifier.dart';
import 'package:inkflow/features/ai/presentation/sidebar/ai_sidebar.dart';

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
  @override
  Future<List<double>> embed(String text) async => const [];
}

class _NoopEmbedder implements TextEmbedder {
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
      privacyAsksEachTime: () =>
          settings.state.cloudPrivacy == CloudPrivacy.askEachTime,
    );

Widget wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

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
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              captured = ref;
              return const CloudModelToggle();
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();

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
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              captured = ref;
              return const CloudModelToggle();
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(captured.read(settingsProvider).cloudPrivacy,
          CloudPrivacy.askEachTime);
      expect(captured.read(settingsProvider).hasSeenFirstCloudCall, isFalse);
    });
  });

  group('the /cloud command', () {
    test('turns the setting on and confirms instead of asking the model',
        () async {
      final settings = SettingsNotifier();
      final notifier = buildNotifier(settings);

      await notifier.ask('/cloud on', notebookId: 1);

      expect(settings.state.cloudAiEnabled, isTrue);
      expect(notifier.state, isA<AskNotesNotice>());
      expect((notifier.state as AskNotesNotice).message,
          cloudCommandConfirmation(enabled: true, privacyAsksEachTime: true));
    });

    test('turns the setting off again', () async {
      final settings = SettingsNotifier();
      await settings.setCloudAiEnabled(true);
      final notifier = buildNotifier(settings);

      await notifier.ask('/cloud off', notebookId: 1);

      expect(settings.state.cloudAiEnabled, isFalse);
    });

    test('natural phrasing works too', () async {
      final settings = SettingsNotifier();
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
    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            captured = ref;
            return const CloudModelToggle();
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
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
