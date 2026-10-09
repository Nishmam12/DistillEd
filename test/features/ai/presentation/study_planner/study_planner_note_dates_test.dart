import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/memory/learning_memory_repository.dart';
import 'package:inkflow/features/ai/data/study_planner/study_plan_store.dart';
import 'package:inkflow/features/ai/domain/study_planner/note_deadlines.dart';
import 'package:inkflow/features/ai/domain/study_planner/study_plan.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/study_planner/study_planner_screen.dart';
import 'package:inkflow/features/ai/presentation/study_planner_notifier.dart';

/// The planner opens with no saved plan and these tests never generate one, so
/// nothing here is ever read.
class _UnusedMemory implements LearningMemoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

class _EmptyStore implements StudyPlanStore {
  @override
  Future<StudyPlan?> loadForNotebook(int notebookId) async => null;
  @override
  Future<void> save(StudyPlan plan) async {}
  @override
  Future<void> deleteForNotebook(int notebookId) async {}
}

void main() {
  final quiz = NoteDeadline(
      date: DateTime(2026, 10, 14), label: 'Quiz 2 on Oct 14', pageId: 3);
  final finalExam = NoteDeadline(
      date: DateTime(2026, 11, 20), label: 'Final exam Nov 20', pageId: 5);

  late int lookups;

  Future<void> pumpPlanner(
    WidgetTester tester,
    Future<List<NoteDeadline>> Function() deadlines,
  ) async {
    lookups = 0;
    // The screen is a lazy ListView: on the default 800x600 surface the Generate
    // button is never built and the suggestions sit below the fold.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        studyPlannerProvider(1).overrideWith((ref) => StudyPlannerNotifier(
            memory: _UnusedMemory(), store: _EmptyStore(), notebookId: 1)),
        noteDeadlinesProvider(1).overrideWith((ref) {
          lookups++;
          return deadlines();
        }),
      ],
      child: const MaterialApp(home: StudyPlannerScreen(notebookId: 1)),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> chooseExamCountdown(WidgetTester tester) async {
    await tester.tap(find.text('Exam countdown'));
    await tester.pumpAndSettle();
  }

  testWidgets('nothing looks through the notes until the student asks',
      (tester) async {
    await pumpPlanner(tester, () async => [quiz]);

    expect(find.text('Find dates in my notes'), findsNothing,
        reason: 'only the exam countdown needs a date');
    await chooseExamCountdown(tester);

    expect(find.text('Find dates in my notes'), findsOneWidget);
    expect(lookups, 0);
  });

  testWidgets('asking lists what the notes say, soonest first', (tester) async {
    await pumpPlanner(tester, () async => [quiz, finalExam]);
    await chooseExamCountdown(tester);

    await tester.tap(find.text('Find dates in my notes'));
    await tester.pumpAndSettle();

    expect(lookups, 1);
    expect(find.text('Quiz 2 on Oct 14'), findsOneWidget);
    expect(find.text('Wed, Oct 14'), findsOneWidget);
    expect(find.text('Final exam Nov 20'), findsOneWidget);
    // Soonest above latest.
    expect(tester.getTopLeft(find.text('Quiz 2 on Oct 14')).dy,
        lessThan(tester.getTopLeft(find.text('Final exam Nov 20')).dy));
  });

  testWidgets('choosing one sets the exam date and enables Generate',
      (tester) async {
    await pumpPlanner(tester, () async => [quiz]);
    await chooseExamCountdown(tester);
    FilledButton generate() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Generate plan'));
    expect(generate().onPressed, isNull, reason: 'no exam date yet');

    await tester.tap(find.text('Find dates in my notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz 2 on Oct 14'));
    await tester.pumpAndSettle();

    expect(find.text('Exam: Wed, Oct 14'), findsOneWidget);
    expect(generate().onPressed, isNotNull);
  });

  testWidgets('nothing found says so', (tester) async {
    await pumpPlanner(tester, () async => const []);
    await chooseExamCountdown(tester);

    await tester.tap(find.text('Find dates in my notes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No upcoming'), findsOneWidget);
  });

  testWidgets('a date model that cannot load is not "no dates"',
      (tester) async {
    await pumpPlanner(
        tester, () async => throw const DateFinderUnavailable('offline'));
    await chooseExamCountdown(tester);

    await tester.tap(find.text('Find dates in my notes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No upcoming'), findsNothing);
    expect(find.textContaining('connect to the internet'), findsOneWidget);
  });

  testWidgets('Try again looks again', (tester) async {
    var fail = true;
    await pumpPlanner(tester, () async {
      if (fail) throw const DateFinderUnavailable('offline');
      return [quiz];
    });
    await chooseExamCountdown(tester);
    await tester.tap(find.text('Find dates in my notes'));
    await tester.pumpAndSettle();
    expect(lookups, 1);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(lookups, 2);
    expect(find.text('Quiz 2 on Oct 14'), findsOneWidget);
  });

  testWidgets('any other failure is reported plainly', (tester) async {
    await pumpPlanner(tester, () async => throw StateError('disk'));
    await chooseExamCountdown(tester);

    await tester.tap(find.text('Find dates in my notes'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't look through your notes"),
        findsOneWidget);
  });
}
