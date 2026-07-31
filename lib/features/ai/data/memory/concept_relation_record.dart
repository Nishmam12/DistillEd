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

  /// The page whose analysis last produced this edge. Null for edges stored
  /// before page attribution existed.
  ///
  /// Mirrors [ConceptMastery.lastPageId], and for the same reason: the
  /// Knowledge Graph can now be built for one page or one imported PDF rather
  /// than only for a whole notebook (see `features/ai/domain/ai_scope.dart`),
  /// and an edge with no page cannot be placed in either. "Last" rather than
  /// "every" is deliberate — one page per edge keeps the natural key
  /// (notebookId, fromKey, toKey) intact, and a relationship the notes draw on
  /// several pages is the same relationship wherever it is drawn.
  int? lastPageId;

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
