// The concept map for a notebook (Phase 2, Loop 2.4): mastery-tagged nodes and
// the relationships between them, assembled from Learning Memory ([ConceptMastery])
// and the Context Engine's edges ([ConceptRelation]).
//
// Pure: this builds the graph STRUCTURE (who connects to whom, how well each is
// known). Layout is a separate pure step (`graph_layout.dart`) and drawing is
// presentation — so the interesting logic is unit-tested without a canvas.

import '../memory/concept_mastery.dart';
import 'concept_relation.dart';

/// A concept in the graph, with how well the learner knows it.
class GraphNode {
  /// Normalized identity ([normalizeConceptKey]) — matches edge endpoints and
  /// the mastery store.
  final String key;

  /// Human spelling for the label.
  final String name;

  final MasteryLevel level;

  /// True when this concept appears ONLY as the endpoint of a relationship and
  /// was never studied directly — a gap the notebook gestures at but never
  /// covers. Rendered distinctly, and exactly the "referenced but never studied"
  /// signal Loop 2.5's planner wants.
  final bool referencedOnly;

  /// Number of edges touching this node — drives node size (a hub concept reads
  /// as bigger) and a stable layout seed.
  final int degree;

  const GraphNode({
    required this.key,
    required this.name,
    required this.level,
    required this.referencedOnly,
    required this.degree,
  });
}

/// A drawable edge, endpoints guaranteed to exist in [KnowledgeGraph.nodes].
class GraphEdge {
  final String fromKey;
  final String toKey;
  final String relation;
  const GraphEdge({
    required this.fromKey,
    required this.toKey,
    required this.relation,
  });
}

class KnowledgeGraph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const KnowledgeGraph({required this.nodes, required this.edges});

  static const empty = KnowledgeGraph(nodes: [], edges: []);

  bool get isEmpty => nodes.isEmpty;

  GraphNode? nodeFor(String key) {
    for (final n in nodes) {
      if (n.key == key) return n;
    }
    return null;
  }

  /// Assembles the graph for one notebook from its mastery [concepts] and
  /// [relations].
  ///
  /// Nodes come from BOTH sources: every studied concept, plus every concept an
  /// edge references. An edge endpoint with no mastery record becomes a
  /// [GraphNode.referencedOnly] node (a gap) rather than being dropped — losing
  /// it would hide exactly the "mentioned but never studied" concepts the graph
  /// exists to reveal. Edges whose endpoints collapse to the same node, or
  /// duplicate (from,to) pairs, are dropped so the drawing stays clean.
  factory KnowledgeGraph.build({
    required List<ConceptMastery> concepts,
    required List<ConceptRelation> relations,
  }) {
    // Studied concepts first — they own the display name and real mastery.
    final names = <String, String>{}; // key → best display name
    final levels = <String, MasteryLevel>{};
    for (final c in concepts) {
      final key = normalizeConceptKey(c.conceptName);
      if (key.isEmpty) continue;
      names[key] = c.conceptName;
      levels[key] = c.level;
    }

    // Fold in edge endpoints, minting referenced-only nodes for any unknown.
    final validEdges = <GraphEdge>[];
    final degree = <String, int>{};
    final edgeSeen = <String>{};
    for (final r in relations) {
      if (!r.isValid) continue;
      if (!edgeSeen.add('${r.fromKey} ${r.toKey}')) continue;
      for (final (key, name) in [(r.fromKey, r.fromName), (r.toKey, r.toName)]) {
        names.putIfAbsent(key, () => name);
      }
      degree[r.fromKey] = (degree[r.fromKey] ?? 0) + 1;
      degree[r.toKey] = (degree[r.toKey] ?? 0) + 1;
      validEdges.add(
          GraphEdge(fromKey: r.fromKey, toKey: r.toKey, relation: r.relation));
    }

    final nodes = [
      for (final entry in names.entries)
        GraphNode(
          key: entry.key,
          name: entry.value,
          level: levels[entry.key] ?? MasteryLevel.unseen,
          referencedOnly: !levels.containsKey(entry.key),
          degree: degree[entry.key] ?? 0,
        ),
    ];
    // Stable order: most-connected first (the layout seeds off index, and a UI
    // list reads better hub-first).
    nodes.sort((a, b) {
      final byDegree = b.degree.compareTo(a.degree);
      return byDegree != 0 ? byDegree : a.key.compareTo(b.key);
    });

    return KnowledgeGraph(nodes: nodes, edges: validEdges);
  }
}
