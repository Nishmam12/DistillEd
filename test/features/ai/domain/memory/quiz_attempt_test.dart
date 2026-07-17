import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/memory/quiz_attempt.dart';
import 'package:inkflow/features/ai/domain/memory/stable_id.dart';

QuizQuestionOutcome outcome(
  String prompt,
  bool correct, [
  List<String> conceptKeys = const [],
]) =>
    QuizQuestionOutcome(
        prompt: prompt, correct: correct, conceptKeys: conceptKeys);

QuizAttempt attempt(List<QuizQuestionOutcome> outcomes, {String? attemptId}) =>
    QuizAttempt.record(
      notebookId: 1,
      pageId: 1,
      takenAt: DateTime(2026, 7, 1),
      outcomes: outcomes,
      attemptId: attemptId,
    );

void main() {
  test('score counts correct answers; an empty attempt scores zero', () {
    final a = attempt([outcome('q1', true), outcome('q2', false)]);
    expect(a.totalCount, 2);
    expect(a.correctCount, 1);
    expect(a.scoreFraction, 0.5);

    expect(attempt(const []).scoreFraction, 0, reason: 'no divide-by-zero');
  });

  test('a concept is correct only when every question testing it was right', () {
    final a = attempt([
      outcome('q1', true, ['mitosis']),
      outcome('q2', false, ['mitosis']), // one miss taints the concept
      outcome('q3', true, ['osmosis']),
    ]);
    expect(a.conceptOutcomes(), {'mitosis': false, 'osmosis': true});
  });

  test('a question with no attributable concept scores but moves no mastery',
      () {
    final a = attempt([outcome('q1', false)]);
    expect(a.conceptOutcomes(), isEmpty);
    expect(a.correctCount, 0);
    expect(a.totalCount, 1);
  });

  test('generated event IDs are unique 128-bit hex', () {
    final ids = {for (var i = 0; i < 50; i++) newStableId()};
    expect(ids, hasLength(50), reason: 'no collisions');
    expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('an explicit attemptId is preserved (stable sync identity)', () {
    expect(attempt(const [], attemptId: 'fixed-id').attemptId, 'fixed-id');
  });
}
