// Isar persistence for [QuizAttempt] — the durable score history Phase 1's quiz
// flow deliberately didn't keep.
//
// Identity is the generated [attemptId] (indexed), not Isar's local `id`.
// Per-question outcomes are stored as an Isar `@embedded` list, so an attempt
// stays one row and the concept attribution travels with the questions.

import 'package:isar/isar.dart';

import '../../domain/memory/quiz_attempt.dart';

part 'quiz_attempt_record.g.dart';

@collection
class QuizAttemptRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late String attemptId;

  @Index()
  late int notebookId;

  late int pageId;
  late DateTime takenAt;
  late List<QuizQuestionOutcomeRecord> outcomes;

  QuizAttempt toDomain() => QuizAttempt(
        attemptId: attemptId,
        notebookId: notebookId,
        pageId: pageId,
        takenAt: takenAt,
        outcomes: [for (final o in outcomes) o.toDomain()],
      );

  static QuizAttemptRecord fromDomain(QuizAttempt attempt) => QuizAttemptRecord()
    ..attemptId = attempt.attemptId
    ..notebookId = attempt.notebookId
    ..pageId = attempt.pageId
    ..takenAt = attempt.takenAt
    ..outcomes = [
      for (final o in attempt.outcomes) QuizQuestionOutcomeRecord.fromDomain(o)
    ];
}

/// Isar embedded objects need a no-arg constructor and nullable/defaulted
/// fields, so this mirrors [QuizQuestionOutcome] defensively and fills in
/// defaults on read rather than trusting stored shape.
@embedded
class QuizQuestionOutcomeRecord {
  String? prompt;
  bool? correct;
  List<String>? conceptKeys;

  QuizQuestionOutcome toDomain() => QuizQuestionOutcome(
        prompt: prompt ?? '',
        correct: correct ?? false,
        conceptKeys: conceptKeys ?? const [],
      );

  static QuizQuestionOutcomeRecord fromDomain(QuizQuestionOutcome outcome) =>
      QuizQuestionOutcomeRecord()
        ..prompt = outcome.prompt
        ..correct = outcome.correct
        ..conceptKeys = outcome.conceptKeys;
}
