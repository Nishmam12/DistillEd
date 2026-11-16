// "Ask your notes" when the student has picked a cloud model to answer with.
// The on-device path is covered by `ask_notes_notifier_test.dart`; this file is
// about the promise that a pick changes who answers, and that nothing is sent
// without a yes.

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/data/embeddings/embedder_download_manager.dart';
import 'package:margo/features/ai/data/llm/model_download_manager.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/catalog/ai_model_entry.dart';
import 'package:margo/features/ai/domain/catalog/answer_route.dart';
import 'package:margo/features/ai/domain/features/notes_qa.dart';
import 'package:margo/features/ai/domain/quality/ai_quality_guard.dart';
import 'package:margo/features/ai/domain/rag/note_chunk.dart';
import 'package:margo/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:margo/features/ai/domain/rag/prompt_contract.dart';
import 'package:margo/features/ai/domain/rag/rag_retriever.dart';
import 'package:margo/features/ai/domain/rag/text_embedder.dart';
import 'package:margo/features/ai/domain/routing/selected_answer_provider.dart';
import 'package:margo/features/ai/presentation/ask_notes_notifier.dart';

class _FakeProvider implements AiProvider {
  final String reply;
  final int window;
  final bool isLocal;
  final AiException? fails;
  final prompts = <String>[];

  _FakeProvider(this.reply, {this.window = 4096, this.isLocal = false, this.fails});

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: reply,
        displayName: reply,
        contextWindowTokens: window,
        isLocal: isLocal,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    prompts.add(prompt);
    if (fails != null) throw fails!;
    yield reply;
  }
}

class _FixedEmbedder implements TextEmbedder {
  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;
  @override
  int get chunkWords => kChunkWords;
  @override
  int get chunkOverlapWords => kChunkOverlapWords;
  @override
  final String modelId = 'fake-v1';
  @override
  final int dimensions = 3;
  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      const [1.0, 0.0, 0.0];
  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      [for (final _ in texts) const [1.0, 0.0, 0.0]];
}

NoteChunk _chunk(String text) => NoteChunk(
      notebookId: 1,
      pageId: 7,
      ordinal: 0,
      text: text,
      embedding: const [1.0, 0.0, 0.0],
      embeddingModelId: 'fake-v1',
      contentSignature: 'sig',
      embeddedAt: DateTime(2026, 7, 17),
    );

const _mine = AiModelEntry(
  id: 'user:c1:big',
  displayName: 'My AI · Big',
  source: ModelSource.userKey,
  contextWindowTokens: 32000,
  host: 'api.example.com',
);

void main() {
  late _FakeProvider local;
  late _FakeProvider cloud;
  late _FakeProvider guardLocal;
  late AnswerRoute route;
  late bool allow;
  late List<AiModelEntry> askedAbout;
  late List<NoteChunk> notes;

  AskNotesNotifier build({bool withGuard = false}) => AskNotesNotifier(
        qa: NotesQa(
          provider: SelectedAnswerProvider(
            local: local,
            route: () => route,
            cloudFor: (_) => cloud,
          ),
          retriever: RagRetriever(
            embedder: _FixedEmbedder(),
            loadChunks: (_) async => notes,
          ),
        ),
        llmDownloads: ModelDownloadManager(),
        embedderDownloads: EmbedderDownloadManager(authToken: () => null),
        guard: withGuard
            ? AiQualityGuard(
                local: guardLocal,
                cloudEnabled: () => true,
                privacy: () => CloudPrivacy.askEachTime,
                isOnline: () async => true,
              )
            : null,
        route: () => route,
        confirmSend: (model) async {
          askedAbout.add(model);
          return allow;
        },
      );

  setUp(() {
    local = _FakeProvider('The device says ATP [1].', isLocal: true);
    cloud = _FakeProvider('The cloud says ATP [1].', window: 32000);
    guardLocal = _FakeProvider('The guard says ATP [1].', isLocal: true);
    route = const CloudDirect(_mine);
    allow = true;
    askedAbout = [];
    notes = [_chunk('Mitochondria make ATP.')];
  });

  test('the picked model answers, and the answer is labelled with its name',
      () async {
    final notifier = build();

    await notifier.ask('what makes ATP?', notebookId: 1);

    final state = notifier.state as AskNotesAnswered;
    expect(state.text, 'The cloud says ATP [1].');
    expect(state.tier, AnswerTier.cloud);
    expect(state.modelName, 'My AI · Big');
    expect(local.prompts, isEmpty);
  });

  test('the student is asked once, about the model that will receive it',
      () async {
    final notifier = build();

    await notifier.ask('what makes ATP?', notebookId: 1);

    expect(askedAbout, [_mine]);
  });

  test('a no sends nothing anywhere and returns to the question box',
      () async {
    allow = false;
    final notifier = build();

    await notifier.ask('what makes ATP?', notebookId: 1);

    expect(cloud.prompts, isEmpty);
    expect(local.prompts, isEmpty);
    expect(notifier.state, isA<AskNotesComposing>());
  });

  test('with nothing in the notes to send, the student is not asked at all',
      () async {
    notes = [];
    final notifier = build();

    await notifier.ask('what makes ATP?', notebookId: 1);

    expect(notifier.state, isA<AskNotesNotFound>());
    expect(askedAbout, isEmpty);
    expect(cloud.prompts, isEmpty);
  });

  test('the on-device model is not run first as a check', () async {
    final notifier = build(withGuard: true);

    await notifier.ask('what makes ATP?', notebookId: 1);

    expect(guardLocal.prompts, isEmpty);
    expect((notifier.state as AskNotesAnswered).text, 'The cloud says ATP [1].');
  });

  test('a picked model that fails shows the failure, with no on-device answer '
      'in its place', () async {
    cloud = _FakeProvider(
      'unused',
      fails: const AiUnavailableException("Couldn't reach api.example.com."),
    );
    final notifier = build(withGuard: true);

    await notifier.ask('what makes ATP?', notebookId: 1);

    final state = notifier.state as AskNotesError;
    expect(state.message, contains('api.example.com'));
    expect(local.prompts, isEmpty);
    expect(guardLocal.prompts, isEmpty);
  });

  group('with nothing picked', () {
    setUp(() => route = const LocalFirst(null));

    test('the on-device model answers and nobody is asked anything', () async {
      final notifier = build();

      await notifier.ask('what makes ATP?', notebookId: 1);

      final state = notifier.state as AskNotesAnswered;
      expect(state.text, 'The device says ATP [1].');
      expect(state.tier, AnswerTier.local);
      expect(state.modelName, isNull);
      expect(askedAbout, isEmpty);
      expect(cloud.prompts, isEmpty);
    });

    test('the quality check still runs on the on-device answer', () async {
      final notifier = build(withGuard: true);

      await notifier.ask('what makes ATP?', notebookId: 1);

      expect(guardLocal.prompts, hasLength(1));
      expect(cloud.prompts, isEmpty);
    });
  });
}
