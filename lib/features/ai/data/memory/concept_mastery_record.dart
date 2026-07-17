// Isar persistence for [ConceptMastery]. The rules live in the pure domain
// model; this entity only converts to/from it.
//
// Identity is the natural key (notebookId, conceptKey) — both indexed so the
// repository can find-or-create a concept cheaply. `id` is Isar's local
// autoincrement and is deliberately NOT part of identity (see the sync-ready
// note in `domain/memory/concept_mastery.dart`).
//
// NOTE: two `@Index()` fields means `.where()` loses findAll()/deleteAll() —
// the repository uses `.filter()` throughout (same gotcha as FlashcardRecord
// and SummaryCache).

import 'package:isar/isar.dart';

import '../../domain/memory/concept_mastery.dart';

part 'concept_mastery_record.g.dart';

@collection
class ConceptMasteryRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int notebookId;

  @Index()
  late String conceptKey;

  late String conceptName;
  int? lastPageId;

  /// [MasteryLevel.storageKey] — stored as text so an unknown value degrades to
  /// `unseen` instead of throwing on read.
  late String level;

  late DateTime lastSeenAt;
  DateTime? lastReviewedAt;
  late int timesReviewed;
  late int timesMissedInQuiz;
  late int timesFlaggedAsGap;

  ConceptMastery toDomain() => ConceptMastery(
        conceptName: conceptName,
        conceptKey: conceptKey,
        notebookId: notebookId,
        lastPageId: lastPageId,
        level: MasteryLevelX.fromStorageKey(level),
        lastSeenAt: lastSeenAt,
        lastReviewedAt: lastReviewedAt,
        timesReviewed: timesReviewed,
        timesMissedInQuiz: timesMissedInQuiz,
        timesFlaggedAsGap: timesFlaggedAsGap,
      );

  static ConceptMasteryRecord fromDomain(ConceptMastery mastery) =>
      ConceptMasteryRecord()
        ..notebookId = mastery.notebookId
        ..conceptKey = mastery.conceptKey
        ..conceptName = mastery.conceptName
        ..lastPageId = mastery.lastPageId
        ..level = mastery.level.storageKey
        ..lastSeenAt = mastery.lastSeenAt
        ..lastReviewedAt = mastery.lastReviewedAt
        ..timesReviewed = mastery.timesReviewed
        ..timesMissedInQuiz = mastery.timesMissedInQuiz
        ..timesFlaggedAsGap = mastery.timesFlaggedAsGap;
}
