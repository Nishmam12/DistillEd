import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/features/quiz_generator.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/quiz_notifier.dart';
import 'package:inkflow/features/ai/presentation/quiz/quiz_sheet.dart';

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
    state = QuizReady(questions);
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

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizNotifierProvider.overrideWith((ref) => _FixedQuiz(questions)),
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
}
