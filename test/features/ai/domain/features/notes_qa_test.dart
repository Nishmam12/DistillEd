import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/features/notes_qa.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_retriever.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// Records what it was asked and replays scripted chunks.
class _ScriptedProvider implements AiProvider {
  final List<String> chunks;
  String? lastPrompt;
  String? lastSystemPrompt;
  AiGenerationOptions? lastOptions;

  _ScriptedProvider(this.chunks);

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
    lastPrompt = prompt;
    lastSystemPrompt = systemPrompt;
    lastOptions = options;
    for (final c in chunks) {
      yield c;
    }
  }

  @override
  Future<List<double>> embed(String text) async =>
      throw const AiUnsupportedOperationException('not needed');
}

/// Returns a fixed query vector so canned chunks with the same vector score 1.0.
class _FixedEmbedder implements TextEmbedder {
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

NoteChunk _chunk(String text, {int pageId = 1, int ordinal = 0}) => NoteChunk(
      notebookId: 1,
      pageId: pageId,
      ordinal: ordinal,
      text: text,
      embedding: const [1.0, 0.0, 0.0], // matches the query → retrieved
      embeddingModelId: 'fake-v1',
      contentSignature: 'sig',
      embeddedAt: DateTime(2026, 7, 17),
    );

NotesQa _build(_ScriptedProvider provider, List<NoteChunk> chunks) => NotesQa(
      provider: provider,
      retriever: RagRetriever(
        embedder: _FixedEmbedder(),
        loadChunks: (_) async => chunks,
      ),
    );

void main() {
  group('findSources', () {
    test('returns the retriever hits for the notebook', () async {
      final qa = _build(_ScriptedProvider(const []),
          [_chunk('the cell membrane'), _chunk('mitosis phases', ordinal: 1)]);

      final sources =
          await qa.findSources(question: 'cells?', notebookId: 1);
      expect(sources, isNotEmpty);
      expect(sources.first.chunk.text, isNotEmpty);
    });

    test('returns empty when the notebook has nothing', () async {
      final qa = _build(_ScriptedProvider(const []), const []);
      expect(await qa.findSources(question: 'x', notebookId: 1), isEmpty);
    });
  });

  group('answer', () {
    test('streams the provider chunks unchanged, in order', () async {
      final provider = _ScriptedProvider(['Mito', 'chondria', ' make ATP.']);
      final qa = _build(provider, const []);

      final out = await qa.answer(
        question: 'what makes ATP?',
        sources: [
          RetrievedChunk(chunk: _chunk('Mitochondria make ATP.'), score: 0.9)
        ],
      ).toList();

      expect(out.join(), 'Mitochondria make ATP.');
    });

    test('grounds on the passages: numbered, with the question, under the '
        'grounding system prompt', () async {
      final provider = _ScriptedProvider(const ['ok']);
      final qa = _build(provider, const []);

      await qa.answer(
        question: 'What is the powerhouse?',
        sources: [
          RetrievedChunk(chunk: _chunk('Mitochondria are the powerhouse.'),
              score: 0.9),
          RetrievedChunk(
              chunk: _chunk('ATP stores energy.', ordinal: 1), score: 0.8),
        ],
      ).drain();

      expect(provider.lastSystemPrompt, NotesQa.systemPrompt);
      expect(provider.lastPrompt, contains('[1] Mitochondria are the powerhouse.'));
      expect(provider.lastPrompt, contains('[2] ATP stores energy.'));
      expect(provider.lastPrompt, contains('What is the powerhouse?'));
    });

    test('answers with low temperature (grounded extraction, not creative)',
        () async {
      final provider = _ScriptedProvider(const ['ok']);
      final qa = _build(provider, const []);

      await qa.answer(question: 'q', sources: [
        RetrievedChunk(chunk: _chunk('a passage'), score: 0.9)
      ]).drain();

      expect(provider.lastOptions!.temperature, lessThan(0.5));
    });

    test('keeps the first passage even if it alone exceeds the budget, but '
        'drops later passages that overflow', () async {
      // A provider with a tiny context window forces the budget to bite.
      final provider = _TinyWindowProvider(const ['ok']);
      final qa = NotesQa(
        provider: provider,
        retriever: RagRetriever(
          embedder: _FixedEmbedder(),
          loadChunks: (_) async => const [],
        ),
      );

      final big = List.generate(300, (i) => 'word$i').join(' ');
      await qa.answer(question: 'q', sources: [
        RetrievedChunk(chunk: _chunk(big), score: 0.9),
        RetrievedChunk(chunk: _chunk('second passage', ordinal: 1), score: 0.8),
      ]).drain();

      // [1] is always present; [2] is dropped rather than the model seeing a
      // citation number for a passage that was cut.
      expect(provider.lastPrompt, contains('[1]'));
      expect(provider.lastPrompt, isNot(contains('[2]')));
    });
  });
}

/// A provider whose context window is small enough that passage budgeting
/// engages on modest input.
class _TinyWindowProvider extends _ScriptedProvider {
  _TinyWindowProvider(super.chunks);

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'tiny',
        displayName: 'Tiny',
        contextWindowTokens: 800, // ~ a few hundred words of budget
        isLocal: true,
      );
}
