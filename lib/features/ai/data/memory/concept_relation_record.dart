// Isar persistence for [ConceptRelation] — the Knowledge Graph's edges
// (Phase 2, Loop 2.4).
//
// Identity is the natural key (notebookId, fromKey, toKey): one directed edge
// per concept pair, so re-observing the same relationship updates it in place
// (refreshes the label/last-seen) instead of piling up duplicates. Same
// sync-ready boundary as ConceptMasteryRecord — `id` is a local storage detail.
//
// NOTE: multiple `@Index()` fields means `.where()` loses findAll()/deleteAll()
// — the store uses `.filter()` (same gotcha as ConceptMasteryRecord).

import 'package:isar/isar.dart';

import '../../domain/knowledge_graph/concept_relation.dart';

part 'concept_relation_record.g.dart';

@collection
class ConceptRelationRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int notebookId;

  /// Normalized endpoints — the same keys ConceptMasteryRecord stores, so an
  /// edge joins to its nodes without a translation table.
  @Index()
  late String fromKey;
  late String toKey;

  /// Human spellings, kept for display so the graph needn't re-derive them.
  late String fromName;
  late String toName;

  late String relation;
  late double confidence;
  late DateTime lastSeenAt;

  ConceptRelation toDomain() => ConceptRelation(
        fromName: fromName,
        toName: toName,
        relation: relation,
        confidence: confidence,
      );

  static ConceptRelationRecord fromDomain(
    ConceptRelation r, {
    required int notebookId,
    required DateTime at,
  }) =>
      ConceptRelationRecord()
        ..notebookId = notebookId
        ..fromKey = r.fromKey
        ..toKey = r.toKey
        ..fromName = r.fromName
        ..toName = r.toName
        ..relation = r.relation
        ..confidence = r.confidence
        ..lastSeenAt = at;
}
