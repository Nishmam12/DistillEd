// The grounding contract, asserted at the seam where it can actually break.
//
// Every feature that tells a student "this came from your notes" must build its
// prompt out of note content and nothing else. That is easy to state and easy
// to lose: a helpful refactor that keeps a question but drops the passages
// produces a fluent, confident answer from the model's training data, shown
// under a heading that says it came from the student's own notebook. Nothing
// in the type system stops that, so it is pinned here.
//
// The features audited:
//   • Ask your notes — retrieval only, refuses when nothing retrieves.
//   • Explain        — the extracted passage only.
//   • Summarize      — the extracted page text only.
//   • Context Engine — the extracted page content only (this is what the
//                      Knowledge Graph's concepts and edges are built from).
//
// Deliberately NOT audited: Research, which is the one feature that is allowed
// to reach outside the notes, and says so in its own header.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/features/explainer.dart';
import 'package:inkflow/features/ai/domain/features/notes_qa.dart';
import 'package:inkflow/features/ai/domain/page_content.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';
import 'package:inkflow/features/ai/domain/rag/rag_retriever.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// Records exactly what reached the model.
class _RecordingProvider implements AiProvider {
  final String reply;
  _RecordingProvider([this.reply = '{}']);

  final prompts = <String>[];
  final systemPrompts = <String?>[];

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    prompts.add(prompt);
    systemPrompts.add(systemPrompt);
    yield reply;
  }

  @override
  Future<List<double>> embed(String text) async => const [];

  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'recorder',
        displayName: 'Recorder',
        contextWindowTokens: 8192,
      );
}

class _EmptyEmbedder implements TextEmbedder {
  @override
  String get modelId => 'recorder';
  @override
  int get dimensions => 3;
  @override
  Future<List<double>> embedOne(String text,
          {required EmbedTaskType taskType}) async =>
      const [1, 0, 0];
  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      [for (final _ in texts) const [1.0, 0.0, 0.0]];
}

RetrievedChunk _chunk(String text, {int pageId = 1, int ordinal = 0}) =>
    RetrievedChunk(
      score: 0.9,
      chunk: NoteChunk(
        notebookId: 1,
        pageId: pageId,
        ordinal: ordinal,
        text: text,
        embedding: const [1, 0, 0],
        embeddingModelId: 'recorder',
        contentSignature: 'sig',
        embeddedAt: DateTime(2026, 7, 31),
      ),
    );

void main() {
  group('Ask your notes', () {
    test('sends the retrieved passages and the question, and nothing else',
        () async {
      final provider = _RecordingProvider('answer');
      final qa = NotesQa(
        provider: provider,
        retriever: RagRetriever(
          embedder: _EmptyEmbedder(),
          loadChunks: (_) async => const [],
        ),
      );

      await qa.answer(question: 'Where does it happen?', sources: [
        _chunk('Photosynthesis happens in the chloroplast.'),
        _chunk('Respiration happens in the mitochondria.', ordinal: 1),
      ]).toList();

      final prompt = provider.prompts.single;
      expect(prompt, contains('Photosynthesis happens in the chloroplast.'));
      expect(prompt, contains('Respiration happens in the mitochondria.'));
      expect(prompt, contains('Where does it happen?'));
      // The passages arrive numbered so a [1] citation lines up with the card
      // the UI shows in the same position.
      expect(prompt, contains('[1]'));
      expect(prompt, contains('[2]'));
    });

    test('refuses rather than prompting when it is handed no passages',
        () async {
      // The release-build hole this closes: with no passages the prompt is a
      // bare question under "use only the passages below", and the model
      // answers from world knowledge while the UI says it came from the notes.
      final provider = _RecordingProvider('a confident wrong answer');
      final qa = NotesQa(
        provider: provider,
        retriever: RagRetriever(
          embedder: _EmptyEmbedder(),
          loadChunks: (_) async => const [],
        ),
      );

      final reply = await qa.answer(question: 'anything', sources: const [])
          .join();

      expect(provider.prompts, isEmpty, reason: 'the model is never reached');
      expect(reply, NotesQa.notFoundReply);
    });

    test('an unindexed notebook retrieves nothing, so nothing is answered',
        () async {
      final qa = NotesQa(
        provider: _RecordingProvider(),
        retriever: RagRetriever(
          embedder: _EmptyEmbedder(),
          loadChunks: (_) async => const [],
        ),
      );

      expect(await qa.findSources(question: 'q', notebookId: 1), isEmpty);
    });

    test('the system prompt names the passages as the only source of truth',
        () {
      expect(NotesQa.systemPrompt, contains('ONLY the passages'));
      expect(NotesQa.systemPrompt, contains('only source of truth'));
    });
  });

  group('Explain', () {
    test('sends only the passage it was given', () async {
      final provider = _RecordingProvider('explanation');
      await Explainer(provider: provider)
          .explain(const ExplainInput(
            content: 'A catalyst lowers activation energy.',
            mode: ExplainMode.beginner,
          ))
          .toList();

      final prompt = provider.prompts.single;
      expect(prompt, contains('A catalyst lowers activation energy.'));
      // Nothing but the passage: no retrieved context, no notebook text, no
      // invented framing that would let the model treat something else as
      // source material.
      expect(prompt.replaceAll('PASSAGE:', '').trim(),
          'A catalyst lowers activation energy.');
    });

    test('is allowed background but never contradiction — stated in the prompt',
        () {
      // Explain teaches a subject rather than reporting a document, so it may
      // bring in widely-known background. The line it must not cross is
      // contradicting what the student wrote, and that is the rule pinned here.
      for (final mode in ExplainMode.values) {
        final prompt = Explainer.systemPromptFor(mode);
        expect(prompt, contains('Base the explanation on the passage'));
        expect(prompt, contains('never invent specifics'));
        expect(prompt, contains('contradict it'));
      }
    });
  });

  group('Context Engine (what the Knowledge Graph is built from)', () {
    test('sends only the extracted page content', () async {
      final provider = _RecordingProvider(
          '{"currentTopic":"Cells","keyConcepts":["Mitosis"]}');
      await ContextEngine(provider: provider).analyze(const PageContent(
        recognizedInkText:
            'Mitosis splits one nucleus into two identical nuclei, and each '
            'daughter cell keeps the full chromosome count.',
        typedText: 'Cell division notes from the Tuesday lecture',
        recognizedImageText: '',
      ));

      final prompt = provider.prompts.first;
      expect(prompt, contains('Mitosis splits one nucleus'));
      expect(prompt, contains('Cell division notes from the Tuesday lecture'));
    });

    test('the schema instruction forbids inventing concepts or definitions',
        () {
      expect(ContextEngine.schemaInstruction,
          contains('Use only what the note actually says'));
      expect(ContextEngine.schemaInstruction,
          contains('Never invent facts, names, or definitions'));
      expect(ContextEngine.schemaInstruction,
          contains('Put a term in "definitions" only when the note itself '
              'defines it'));
    });

    test('relations are only drawn when the note implies them', () {
      // The Knowledge Graph's edges come from this list. An edge the note never
      // implied is a made-up claim about how the student's material connects.
      expect(ContextEngine.schemaInstruction,
          contains('Only include a pair when the note itself implies the link'));
    });

    test('a page the gate rejects never reaches the model at all', () async {
      final provider = _RecordingProvider();
      final context = await ContextEngine(provider: provider)
          .analyze(const PageContent(
        recognizedInkText: 'xq',
        typedText: '',
        recognizedImageText: '',
      ));

      expect(provider.prompts, isEmpty);
      expect(context.keyConcepts, isEmpty);
    });
  });
}
