import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/knowledge_graph/concept_relation.dart';
import 'package:inkflow/features/ai/domain/knowledge_graph/graph_layout.dart';
import 'package:inkflow/features/ai/domain/knowledge_graph/knowledge_graph.dart';
import 'package:inkflow/features/ai/domain/memory/concept_mastery.dart';

KnowledgeGraph _graph(int n, {List<ConceptRelation> relations = const []}) {
  return KnowledgeGraph.build(
    concepts: [
      for (var i = 0; i < n; i++)
        ConceptMastery(
          conceptName: 'C$i',
          conceptKey: 'c$i',
          notebookId: 1,
          level: MasteryLevel.learning,
          lastSeenAt: DateTime(2026, 7, 17),
        ),
    ],
    relations: relations,
  );
}

void main() {
  test('an empty graph lays out to nothing', () {
    expect(computeGraphLayout(KnowledgeGraph.empty), isEmpty);
  });

  test('a single node is centred', () {
    final layout = computeGraphLayout(_graph(1));
    expect(layout.values.single, const Offset(0.5, 0.5));
  });

  test('every node gets a position inside the unit square', () {
    final layout = computeGraphLayout(_graph(12), iterations: 60);
    expect(layout, hasLength(12));
    for (final p in layout.values) {
      expect(p.dx, inInclusiveRange(0.0, 1.0));
      expect(p.dy, inInclusiveRange(0.0, 1.0));
    }
  });

  test('is deterministic — same graph, same layout', () {
    final a = computeGraphLayout(_graph(8), iterations: 50);
    final b = computeGraphLayout(_graph(8), iterations: 50);
    expect(a.keys.toSet(), b.keys.toSet());
    for (final key in a.keys) {
      expect(a[key]!.dx, closeTo(b[key]!.dx, 1e-12));
      expect(a[key]!.dy, closeTo(b[key]!.dy, 1e-12));
    }
  });

  test('connected nodes settle closer than unconnected ones', () {
    // Three nodes; A–B share an edge, C is isolated. After layout, A and B
    // should be nearer each other than A is to C (attraction vs. pure
    // repulsion). Uses concrete concept names so keys are predictable.
    final graph = KnowledgeGraph.build(
      concepts: [
        for (final name in ['A', 'B', 'C'])
          ConceptMastery(
            conceptName: name,
            conceptKey: normalizeConceptKey(name),
            notebookId: 1,
            level: MasteryLevel.learning,
            lastSeenAt: DateTime(2026, 7, 17),
          ),
      ],
      relations: [
        const ConceptRelation(fromName: 'A', toName: 'B', relation: 'is-a'),
      ],
    );

    final layout = computeGraphLayout(graph, iterations: 300);
    double dist(String x, String y) => (layout[x]! - layout[y]!).distance;

    expect(dist('a', 'b'), lessThan(dist('a', 'c')));
  });
}
