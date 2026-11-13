import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/data/embeddings/embedder_download_manager.dart';
import 'package:margo/features/ai/data/llm/model_download_manager.dart';
import 'package:margo/features/ai/domain/ai_provider.dart';
import 'package:margo/features/ai/domain/features/figure_qa.dart';
import 'package:margo/features/ai/domain/figure.dart';
import 'package:margo/features/ai/domain/image_transcriber.dart';
import 'package:margo/features/ai/domain/features/notes_qa.dart';
import 'package:margo/features/ai/domain/rag/note_chunk.dart';
import 'package:margo/features/ai/domain/rag/rag_retriever.dart';
import 'package:margo/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:margo/features/ai/domain/rag/prompt_contract.dart';
import 'package:margo/features/ai/domain/rag/text_embedder.dart';
import 'package:margo/features/ai/presentation/ask_notes_notifier.dart';

class _ScriptedProvider implements AiProvider {
  final List<String> chunks;
  _ScriptedProvider(this.chunks);
  final prompts = <String>[];

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'scripted',
        displayName: 'Scripted',
        contextWindowTokens: 4096,
        isLocal: true,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    prompts.add(prompt);
    for (final c in chunks) {
      yield c;
    }
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

AskNotesNotifier _notifier({
  required List<String> answerChunks,
  required List<NoteChunk> notebookChunks,
}) {
  final qa = NotesQa(
    provider: _ScriptedProvider(answerChunks),
    retriever: RagRetriever(
      embedder: _FixedEmbedder(),
      loadChunks: (_) async => notebookChunks,
    ),
  );
  return AskNotesNotifier(
    qa: qa,
    // Not exercised by ask(); constructed plainly (no plugin calls in ctor).
    llmDownloads: ModelDownloadManager(),
    embedderDownloads: EmbedderDownloadManager(authToken: () => null),
  );
}

void main() {
  test('startComposing opens the query box', () {
    final n = _notifier(answerChunks: const [], notebookChunks: const []);
    n.startComposing();
    expect(n.state, isA<AskNotesComposing>());
  });

  test('an empty question is a no-op', () async {
    final n = _notifier(answerChunks: const ['x'], notebookChunks: [
      _chunk('something')
    ]);
    await n.ask('   ', notebookId: 1);
    expect(n.state, isA<AskNotesIdle>());
  });

  test('a question with relevant notes ends answered, carrying the sources',
      () async {
    final n = _notifier(
      answerChunks: const ['Mitochondria', ' make ATP [1].'],
      notebookChunks: [_chunk('Mitochondria make ATP.')],
    );

    await n.ask('what makes ATP?', notebookId: 1);

    final state = n.state;
    expect(state, isA<AskNotesAnswered>());
    state as AskNotesAnswered;
    expect(state.text, 'Mitochondria make ATP [1].');
    expect(state.sources, isNotEmpty);
    expect(state.question, 'what makes ATP?');
  });

  test('a notebook with nothing relevant is a grounded not-found — the LLM is '
      'never called', () async {
    final n = _notifier(
      answerChunks: const ['this should never be produced'],
      notebookChunks: const [], // retrieval finds nothing
    );

    await n.ask('anything', notebookId: 1);
    expect(n.state, isA<AskNotesNotFound>());
  });

  test('a model that answers with the refusal is treated as not-found', () async {
    final n = _notifier(
      answerChunks: const ["I couldn't find the answer to that in your notes."],
      notebookChunks: [_chunk('unrelated passage that still got retrieved')],
    );

    await n.ask('something the notes lack', notebookId: 1);
    // No source chips next to a bare refusal — it's a not-found, not an answer.
    expect(n.state, isA<AskNotesNotFound>());
  });

  test('an empty model reply is treated as not-found, not a blank answer',
      () async {
    final n = _notifier(
      answerChunks: const ['   '],
      notebookChunks: [_chunk('a retrieved passage')],
    );

    await n.ask('q', notebookId: 1);
    expect(n.state, isA<AskNotesNotFound>());
  });

  test('reset returns to idle', () async {
    final n = _notifier(
      answerChunks: const ['answer [1]'],
      notebookChunks: [_chunk('passage')],
    );
    await n.ask('q', notebookId: 1);
    expect(n.state, isA<AskNotesAnswered>());

    n.reset();
    expect(n.state, isA<AskNotesIdle>());
    expect(n.state, isNot(isA<AskNotesComposing>()));
  });

  test('the answering state exposes the sources while streaming', () async {
    final states = <AskNotesState>[];
    final n = _notifier(
      answerChunks: const ['partial'],
      notebookChunks: [_chunk('passage')],
    );
    n.addListener(states.add, fireImmediately: false);

    await n.ask('q', notebookId: 1);

    // The sequence passed through searching → answering(sources) → answered.
    expect(states.any((s) => s is AskNotesSearching), isTrue);
    expect(
      states.any((s) => s is AskNotesAnswering && s.sources.isNotEmpty),
      isTrue,
    );
  });

  group('a question about a figure', () {
    const figure = FigureDescription(
      kind: FigureKind.chart,
      title: 'Revenue by quarter',
      summary: 'A bar chart of revenue over four quarters.',
    );

    (AskNotesNotifier, _ScriptedProvider, _Eye) build(String chunkText) {
      final provider = _ScriptedProvider(const ['Q3 revenue was 40 [2].']);
      final eye = _Eye('The Q3 bar reaches 40.');
      final n = AskNotesNotifier(
        qa: NotesQa(
          provider: provider,
          retriever: RagRetriever(
            embedder: _FixedEmbedder(),
            loadChunks: (_) async => [_chunk(chunkText)],
          ),
        ),
        llmDownloads: ModelDownloadManager(),
        embedderDownloads: EmbedderDownloadManager(authToken: () => null),
        figureQa: FigureQa(
          figuresOf: (_) async => const [figure],
          imageOf: (_, _) async => Uint8List.fromList(const [1, 2, 3]),
          local: eye,
        ),
      );
      return (n, provider, eye);
    }

    test('the figure is looked at, and what was seen reaches the answering '
        'model as the next numbered passage', () async {
      final (n, provider, eye) =
          build('[Figure 1 — chart: Revenue by quarter] A bar chart.');
      final states = <AskNotesState>[];
      n.addListener(states.add);

      await n.ask('What was revenue in Q3?', notebookId: 1);

      expect(eye.calls, 1);
      expect(provider.prompts.single, contains('[2] Seen by looking directly'));
      expect(provider.prompts.single, contains('The Q3 bar reaches 40.'));
      expect(
          states.whereType<AskNotesSearching>().any((s) => s.lookingAtFigure),
          isTrue);
      final state = n.state as AskNotesAnswered;
      expect(state.figure!.pageId, 7);
      expect(state.figure!.label, 'figure "Revenue by quarter"');
    });

    test('a question about plain text never calls the vision model', () async {
      final (n, provider, eye) = build('Revenue grew in every quarter.');
      await n.ask('When did revenue start growing?', notebookId: 1);

      expect(eye.calls, 0);
      expect(provider.prompts.single, isNot(contains('Seen by looking')));
      expect((n.state as AskNotesAnswered).figure, isNull);
    });
  });
}

class _Eye implements ImageTranscriber {
  _Eye(this.reply);
  final String reply;
  int calls = 0;

  @override
  Future<String> transcribeImage(Uint8List imageBytes,
      {required String prompt,
      double temperature = 0.0,
      int maxOutputTokens = 1024,
      int? randomSeed}) async {
    calls++;
    return reply;
  }
}
