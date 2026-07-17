// A directed relationship between two concepts — the edge type of the Knowledge
// Graph (Phase 2, Loop 2.4).
//
// Produced by the Context Engine in its EXISTING analysis pass (the schema now
// asks for `relatedConcepts` alongside topic/concepts), never a second LLM call.
// Identity is the natural key (fromKey, toKey) within a notebook, folded the
// same way concepts are ([normalizeConceptKey]) so the graph and the mastery
// store speak the same node ids.

import '../memory/concept_mastery.dart' show normalizeConceptKey;

/// One edge: [fromName] —[relation]→ [toName].
class ConceptRelation {
  /// Human spellings, kept for display.
  final String fromName;
  final String toName;

  /// A short relationship label as the model phrased it, folded to lower-case
  /// (e.g. `is-a`, `part-of`, `leads-to`, `related-to`). Free text on purpose:
  /// a small model won't respect a fixed ontology, and the graph only needs it
  /// as an edge caption — it never branches on the value.
  final String relation;

  /// 0.0–1.0 — how sure the model was. Defaulted high because the model only
  /// emits a relation it saw; used to break ties / thin a dense graph, not to
  /// gate storage.
  final double confidence;

  const ConceptRelation({
    required this.fromName,
    required this.toName,
    required this.relation,
    this.confidence = 0.8,
  });

  /// Normalized endpoint ids — the same keys [ConceptMastery] uses, so an edge
  /// lines up with a mastery node without a second lookup table.
  String get fromKey => normalizeConceptKey(fromName);
  String get toKey => normalizeConceptKey(toName);

  /// True when this is a usable edge: two DIFFERENT, non-empty concepts. A
  /// self-loop or a blank endpoint is dropped rather than drawn.
  bool get isValid =>
      fromKey.isNotEmpty && toKey.isNotEmpty && fromKey != toKey;

  static const _relationMaxLen = 24;

  /// Tolerant parse of one `{from,to,relation}` object from model JSON. Returns
  /// null for anything unusable (missing endpoints, self-loop) so the caller can
  /// simply skip it.
  static ConceptRelation? tryFromJson(Object? v) {
    if (v is! Map) return null;
    final from = _str(v['from']);
    final to = _str(v['to']);
    var relation = _str(v['relation']).toLowerCase();
    if (relation.length > _relationMaxLen) {
      relation = relation.substring(0, _relationMaxLen).trim();
    }
    final rel = ConceptRelation(
      fromName: from,
      toName: to,
      relation: relation.isEmpty ? 'related-to' : relation,
      confidence: _confidence(v['confidence']),
    );
    return rel.isValid ? rel : null;
  }

  /// Parses the `relatedConcepts` array, dropping unusable entries and
  /// collapsing duplicate (fromKey,toKey) edges (keeping the first).
  static List<ConceptRelation> parseList(Object? v) {
    if (v is! List) return const [];
    final seen = <String>{};
    final out = <ConceptRelation>[];
    for (final e in v) {
      final rel = tryFromJson(e);
      if (rel == null) continue;
      if (!seen.add('${rel.fromKey} ${rel.toKey}')) continue;
      out.add(rel);
    }
    return List.unmodifiable(out);
  }

  static String _str(Object? v) => v is String ? v.trim() : '';

  static double _confidence(Object? v) =>
      v is num ? v.toDouble().clamp(0.0, 1.0) : 0.8;

  @override
  bool operator ==(Object other) =>
      other is ConceptRelation &&
      other.fromKey == fromKey &&
      other.toKey == toKey &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(fromKey, toKey, relation);
}
