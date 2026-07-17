import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/knowledge_graph/concept_relation.dart';

void main() {
  group('tryFromJson', () {
    test('parses a well-formed edge and normalizes endpoint keys', () {
      final rel = ConceptRelation.tryFromJson(
          {'from': ' Machine Learning ', 'to': 'Regression', 'relation': 'Is-A'});
      expect(rel, isNotNull);
      expect(rel!.fromKey, 'machine learning');
      expect(rel.toKey, 'regression');
      expect(rel.relation, 'is-a'); // folded to lower-case
    });

    test('drops a self-loop (same concept both ends)', () {
      expect(
        ConceptRelation.tryFromJson(
            {'from': 'Cell', 'to': 'cell', 'relation': 'is-a'}),
        isNull,
      );
    });

    test('drops an edge missing an endpoint', () {
      expect(ConceptRelation.tryFromJson({'from': 'A', 'relation': 'x'}), isNull);
      expect(ConceptRelation.tryFromJson({'to': 'B'}), isNull);
    });

    test('a blank relation defaults to related-to', () {
      final rel =
          ConceptRelation.tryFromJson({'from': 'A', 'to': 'B', 'relation': ''});
      expect(rel!.relation, 'related-to');
    });

    test('a runaway relation label is capped', () {
      final rel = ConceptRelation.tryFromJson(
          {'from': 'A', 'to': 'B', 'relation': 'x' * 100});
      expect(rel!.relation.length, lessThanOrEqualTo(24));
    });

    test('non-map input is null, not a throw', () {
      expect(ConceptRelation.tryFromJson('nope'), isNull);
      expect(ConceptRelation.tryFromJson(null), isNull);
    });
  });

  group('parseList', () {
    test('keeps valid edges and drops the rest', () {
      final list = ConceptRelation.parseList([
        {'from': 'A', 'to': 'B', 'relation': 'leads-to'},
        {'from': 'X'}, // invalid
        'garbage', // invalid
        {'from': 'C', 'to': 'C'}, // self-loop
      ]);
      expect(list, hasLength(1));
      expect(list.single.fromKey, 'a');
    });

    test('collapses duplicate (from,to) edges, keeping the first', () {
      final list = ConceptRelation.parseList([
        {'from': 'A', 'to': 'B', 'relation': 'is-a'},
        {'from': 'a', 'to': 'b', 'relation': 'part-of'}, // same keys
      ]);
      expect(list, hasLength(1));
      expect(list.single.relation, 'is-a');
    });

    test('non-list input is empty', () {
      expect(ConceptRelation.parseList(null), isEmpty);
      expect(ConceptRelation.parseList('x'), isEmpty);
    });
  });
}
