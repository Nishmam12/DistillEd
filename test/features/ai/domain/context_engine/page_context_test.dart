import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';

void main() {
  group('PageContext.fromJson', () {
    test('parses a fully-shaped object', () {
      final context = PageContext.fromJson(const {
        'currentTopic': 'Photosynthesis',
        'subtopics': ['light reactions', 'Calvin cycle'],
        'keyConcepts': ['chlorophyll', 'ATP'],
        'namedEntities': ['Melvin Calvin'],
        'definitions': {'ATP': 'the cell\'s energy currency'},
        'knowledgeGaps': ['NADPH used but never defined'],
        'estimatedLevel': 'intermediate',
        'confidence': 0.85,
      });

      expect(context.currentTopic, 'Photosynthesis');
      expect(context.subtopics, ['light reactions', 'Calvin cycle']);
      expect(context.keyConcepts, ['chlorophyll', 'ATP']);
      expect(context.namedEntities, ['Melvin Calvin']);
      expect(context.definitions, {'ATP': 'the cell\'s energy currency'});
      expect(context.knowledgeGaps, ['NADPH used but never defined']);
      expect(context.estimatedLevel, KnowledgeLevel.intermediate);
      expect(context.confidence, 0.85);
      expect(context.isEmpty, isFalse);
    });

    test('missing fields fall back to defaults instead of throwing', () {
      final context = PageContext.fromJson(const {'currentTopic': 'Algebra'});

      expect(context.currentTopic, 'Algebra');
      expect(context.subtopics, isEmpty);
      expect(context.definitions, isEmpty);
      expect(context.estimatedLevel, KnowledgeLevel.beginner);
      expect(context.confidence, 0.0);
    });

    test('mistyped fields fall back to defaults instead of throwing', () {
      final context = PageContext.fromJson(const {
        'currentTopic': 42,
        'subtopics': 'not a list',
        'definitions': ['not', 'a', 'map'],
        'estimatedLevel': 7,
        'confidence': 'very sure',
      });

      expect(context.currentTopic, '');
      expect(context.subtopics, isEmpty);
      expect(context.definitions, isEmpty);
      expect(context.estimatedLevel, KnowledgeLevel.beginner);
      expect(context.confidence, 0.0);
    });

    test('confidence is clamped to 0..1', () {
      expect(PageContext.fromJson(const {'confidence': 1.7}).confidence, 1.0);
      expect(PageContext.fromJson(const {'confidence': -0.3}).confidence, 0.0);
      expect(PageContext.fromJson(const {'confidence': 1}).confidence, 1.0);
    });

    test('level parsing is case-insensitive; unknown values → beginner', () {
      expect(PageContext.fromJson(const {'estimatedLevel': 'Advanced'}).estimatedLevel,
          KnowledgeLevel.advanced);
      expect(
          PageContext.fromJson(const {'estimatedLevel': 'INTERMEDIATE'})
              .estimatedLevel,
          KnowledgeLevel.intermediate);
      expect(PageContext.fromJson(const {'estimatedLevel': 'expert'}).estimatedLevel,
          KnowledgeLevel.beginner);
    });

    test('list entries are trimmed; non-strings and blanks are dropped', () {
      final context = PageContext.fromJson(const {
        'keyConcepts': [1, 'ok', '', '  spaced  ', null],
      });
      expect(context.keyConcepts, ['ok', 'spaced']);
    });

    test('definition entries with blank or non-string parts are dropped', () {
      final context = PageContext.fromJson(const {
        'definitions': {'term': ' def ', '': 'x', 'n': 1},
      });
      expect(context.definitions, {'term': 'def'});
    });
  });

  test('empty is empty; a topic-only context is not', () {
    expect(PageContext.empty.isEmpty, isTrue);
    expect(const PageContext(currentTopic: 'Sets').isEmpty, isFalse);
  });
}
