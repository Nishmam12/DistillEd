import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/data/memory/learning_memory_repository.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/features/quiz_generator.dart';
import 'package:inkflow/features/ai/domain/knowledge_graph/concept_relation.dart';
import 'package:inkflow/features/ai/domain/memory/concept_mastery.dart';
import 'package:inkflow/features/ai/domain/memory/learning_preferences.dart';
import 'package:inkflow/features/ai/domain/memory/quiz_attempt.dart';
import 'package:inkflow/features/ai/domain/memory/study_session.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/quiz_notifier.dart';
import 'package:inkflow/features/ai/presentation/quiz/quiz_sheet.dart';

/// Captures what the sheet files, so the durable side-effect is asserted
/// without standing up Isar.
class _FakeMemory implements LearningMemoryRepository {
  final recorded = <QuizAttempt>[];

  @override
  Future<void> recordQuizAttempt(QuizAttempt attempt) async =>
      recorded.add(attempt);

  @override
  Future<void> observePageContext({
    required int notebookId,
    required Iterable<String> keyConcepts,
    Iterable<String> knowledgeGaps = const [],
    Iterable<ConceptRelation> relations = const [],
    int? pageId,
    DateTime? at,
  }) async {}

  @override
  Future<List<ConceptRelation>> relationsForNotebook(int notebookId) async =>
      const [];

  @override
  Future<List<ConceptMastery>> allConcepts(int notebookId) async => const [];
  @override
  Future<List<ConceptMastery>> weakConcepts(int notebookId) async => const [];
  @override
  Future<List<ConceptMastery>> masteredConcepts(int notebookId) async => const [];
  @override
  Future<List<ConceptMastery>> dueForReview({int? notebookId, DateTime? now}) async =>
      const [];
  @override
  Future<List<QuizAttempt>> quizHistory(int notebookId) async => const [];
  @override
  Future<LearningPreferences> loadPreferences() async =>
      LearningPreferences.empty;
  @override
  Future<void> savePreferences(LearningPreferences prefs) async {}
  @override
  Future<void> recordStudySession(StudySession session) async {}
  @override
  Future<List<StudySession>> studyHistory(int notebookId) async => const [];
}

class _NoopProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
      modelId: 'noop',
      displayName: 'noop',
      contextWindowTokens: 4096,
      isLocal: true);
  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<double>> embed(String text) => throw UnimplementedError();
}

class _FakeInstaller implements ModelInstaller {
  @override
  Future<bool> isInstalled(String modelId) async => true;
  @override
  Future<void> install({
    required LlmModelSpec spec,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> uninstall(String modelId) async {}
}

class _FakeStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 62;
}

class _FixedQuiz extends QuizNotifier {
  _FixedQuiz(List<QuizQuestion> questions)
      : super(
          generator: QuizGenerator(provider: _NoopProvider()),
          downloads: ModelDownloadManager(
              installer: _FakeInstaller(), storage: _FakeStorage()),
        ) {
    state = QuizReady(
      questions,
      notebookId: 7,
      pageId: 3,
      // 'Sky' is named by Q1's prompt, 'Bravo' by Q2's answer — so each
      // question attributes to exactly one concept.
      concepts: const ['Sky', 'Bravo'],
    );
  }
}

void main() {
  const questions = [
    QuizQuestion(
      type: QuestionType.trueFalse,
      prompt: 'The sky is blue.',
      options: ['True', 'False'],
      correctIndex: 0,
      correctAnswer: 'True',
      explanation: 'On a clear day, yes.',
    ),
    QuizQuestion(
      type: QuestionType.mcq,
      prompt: 'Pick the second option.',
      options: ['Alpha', 'Bravo', 'Charlie', 'Delta'],
      correctIndex: 1,
      correctAnswer: 'Bravo',
      explanation: 'Bravo is second.',
    ),
  ];

  Future<void> openSheet(WidgetTester tester, {_FakeMemory? memory}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizNotifierProvider.overrideWith((ref) => _FixedQuiz(questions)),
          learningMemoryProvider.overrideWithValue(memory ?? _FakeMemory()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showQuizSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the questions in the sheet', (tester) async {
    await openSheet(tester);

    expect(find.text('The sky is blue.'), findsOneWidget);
    expect(find.text('Pick the second option.'), findsOneWidget);
    expect(find.text('Check answers'), findsOneWidget);
  });

  testWidgets('grades the attempt: one right, one wrong → 1 / 2',
      (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('True')); // Q1 correct
    await tester.pump();
    await tester.tap(find.text('Alpha')); // Q2 wrong (correct is Bravo)
    await tester.pump();

    await tester.tap(find.text('Check answers'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    // Explanations are revealed after checking.
    expect(find.text('Bravo is second.'), findsOneWidget);
  });

  testWidgets('all correct → 2 / 2', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('True'));
    await tester.pump();
    await tester.tap(find.text('Bravo'));
    await tester.pump();

    await tester.tap(find.text('Check answers'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('checking answers files a durable attempt, attributed per concept',
      (tester) async {
    final memory = _FakeMemory();
    await openSheet(tester, memory: memory);

    await tester.tap(find.text('True')); // Q1 correct  → 'sky'
    await tester.pump();
    await tester.tap(find.text('Alpha')); // Q2 wrong   → 'bravo'
    await tester.pump();

    await tester.tap(find.text('Check answers'));
    await tester.pumpAndSettle();

    final attempt = memory.recorded.single;
    expect(attempt.notebookId, 7);
    expect(attempt.pageId, 3);
    expect(attempt.correctCount, 1);
    expect(attempt.totalCount, 2);
    expect(attempt.conceptOutcomes(), {'sky': true, 'bravo': false},
        reason: 'a miss decrements the specific concept, not the whole topic');
    expect(attempt.attemptId, isNotEmpty);
  });

  testWidgets('nothing is filed until the learner checks their answers',
      (tester) async {
    final memory = _FakeMemory();
    await openSheet(tester, memory: memory);

    await tester.tap(find.text('True'));
    await tester.pump();

    expect(memory.recorded, isEmpty);
  });
}
