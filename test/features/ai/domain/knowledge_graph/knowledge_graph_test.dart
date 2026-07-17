import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/knowledge_graph/concept_relation.dart';
import 'package:inkflow/features/ai/domain/knowledge_graph/knowledge_graph.dart';
import 'package:inkflow/features/ai/domain/memory/concept_mastery.dart';

ConceptMastery _mastery(String name, MasteryLevel level) => ConceptMastery(
      conceptName: name,
      conceptKey: normalizeConceptKey(name),
      notebookId: 1,
      level: level,
      lastSeenAt: DateTime(2026, 7, 17),
    );

ConceptRelation _rel(String from, String to, [String relation = 'is-a']) =>
    ConceptRelation(fromName: from, toName: to, relation: relation);

void main() {
  test('an empty graph builds empty', () {
    final g = KnowledgeGraph.build(concepts: const [], relations: const []);
    expect(g.isEmpty, isTrue);
  });

  test('studied concepts become nodes carrying their mastery level', () {
    final g = KnowledgeGraph.build(
      concepts: [
        _mastery('Photosynthesis', MasteryLevel.mastered),
        _mastery('Chlorophyll', MasteryLevel.learning),
      ],
      relations: const [],
    );

    expect(g.nodes, hasLength(2));
    expect(g.nodeFor('photosynthesis')!.level, MasteryLevel.mastered);
    expect(g.nodeFor('photosynthesis')!.referencedOnly, isFalse);
  });

  test('a concept only referenced by an edge becomes a referenced-only node',
      () {
    final g = KnowledgeGraph.build(
      concepts: [_mastery('Machine Learning', MasteryLevel.practiced)],
      // Regression is never studied — only mentioned as a relationship target.
      relations: [_rel('Machine Learning', 'Regression', 'includes')],
    );

    final regression = g.nodeFor('regression');
    expect(regression, isNotNull);
    expect(regression!.referencedOnly, isTrue);
    expect(regression.level, MasteryLevel.unseen);
    // The studied one is not flagged.
    expect(g.nodeFor('machine learning')!.referencedOnly, isFalse);
  });

  test('edges connect existing nodes and duplicates collapse', () {
    final g = KnowledgeGraph.build(
      concepts: [
        _mastery('A', MasteryLevel.learning),
        _mastery('B', MasteryLevel.learning),
      ],
      relations: [
        _rel('A', 'B', 'leads-to'),
        _rel('a', 'b', 'part-of'), // same normalized pair → dropped
      ],
    );

    expect(g.edges, hasLength(1));
    expect(g.edges.single.fromKey, 'a');
    expect(g.edges.single.toKey, 'b');
  });

  test('degree counts every touching edge and orders nodes hub-first', () {
    final g = KnowledgeGraph.build(
      concepts: [
        _mastery('Hub', MasteryLevel.learning),
        _mastery('X', MasteryLevel.learning),
        _mastery('Y', MasteryLevel.learning),
      ],
      relations: [_rel('Hub', 'X'), _rel('Hub', 'Y')],
    );

    expect(g.nodeFor('hub')!.degree, 2);
    expect(g.nodeFor('x')!.degree, 1);
    // Hub is most-connected, so it sorts first.
    expect(g.nodes.first.key, 'hub');
  });

  test('a self-loop edge is dropped, not drawn', () {
    final g = KnowledgeGraph.build(
      concepts: [_mastery('A', MasteryLevel.learning)],
      relations: [_rel('A', 'a')], // normalizes to a self-loop
    );
    expect(g.edges, isEmpty);
  });
}
