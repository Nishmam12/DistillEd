// Structured understanding of one page — the Context Engine's output and the
// substrate every Phase 1+ feature (sidebar, explain, quiz, flashcards)
// builds on.

import 'package:flutter/foundation.dart' show immutable;

import '../ai_provenance.dart';
import '../knowledge_graph/concept_relation.dart';

/// The writer's apparent grasp of the page's topic.
enum KnowledgeLevel { beginner, intermediate, advanced }

/// What the engine understood about a page. Produced by one structured-output
/// model call, so every field is best-effort: [confidence] says how much to
/// trust the read (a page with three words of ink must not produce a
/// confident topic classification).
@immutable
class PageContext {
  /// Main topic as a short phrase ('' when the engine couldn't tell).
  final String currentTopic;

  final List<String> subtopics;
  final List<String> keyConcepts;
  final List<String> namedEntities;

  /// term → definition, only where the note itself states one.
  final Map<String, String> definitions;

  /// Study gaps a tutor would flag — "term X used but never defined",
  /// "section ends mid-thought".
  final List<String> knowledgeGaps;

  /// How the page's concepts relate (`from —relation→ to`), for the Knowledge
  /// Graph. Emitted by the SAME analysis call — no second model pass.
  final List<ConceptRelation> relatedConcepts;

  final KnowledgeLevel estimatedLevel;

  /// 0.0–1.0 — the engine's confidence in this read.
  final double confidence;

  /// Which tier actually produced this analysis, so the panel can show it.
  ///
  /// NOT parsed from the model's JSON — the engine stamps it from the provider
  /// it used, because a model cannot be trusted to report where it ran.
  final AiRanOn ranOn;

  const PageContext({
    required this.currentTopic,
    this.subtopics = const [],
    this.keyConcepts = const [],
    this.namedEntities = const [],
    this.definitions = const {},
    this.knowledgeGaps = const [],
    this.relatedConcepts = const [],
    this.estimatedLevel = KnowledgeLevel.beginner,
    this.confidence = 0.0,
    this.ranOn = AiRanOn.onDevice,
  });

  /// Same context, restamped with where it ran.
  PageContext withRanOn(AiRanOn value) => PageContext(
        currentTopic: currentTopic,
        subtopics: subtopics,
        keyConcepts: keyConcepts,
        namedEntities: namedEntities,
        definitions: definitions,
        knowledgeGaps: knowledgeGaps,
        relatedConcepts: relatedConcepts,
        estimatedLevel: estimatedLevel,
        confidence: confidence,
        ranOn: value,
      );

  /// The "engine has nothing to say" value — too little content, or the model
  /// produced nothing usable. Never null so consumers don't branch on null.
  static const empty = PageContext(currentTopic: '');

  bool get isEmpty =>
      currentTopic.isEmpty &&
      subtopics.isEmpty &&
      keyConcepts.isEmpty &&
      namedEntities.isEmpty &&
      definitions.isEmpty &&
      knowledgeGaps.isEmpty &&
      relatedConcepts.isEmpty;

  /// Tolerant parse of model-produced JSON: missing or mistyped fields fall
  /// back to their defaults rather than throwing — a small local model's
  /// output is never trusted to be perfectly shaped.
  factory PageContext.fromJson(Map<String, dynamic> json) {
    return PageContext(
      currentTopic: _string(json['currentTopic']),
      subtopics: _strings(json['subtopics']),
      keyConcepts: _strings(json['keyConcepts']),
      namedEntities: _strings(json['namedEntities']),
      definitions: _stringMap(json['definitions']),
      knowledgeGaps: _strings(json['knowledgeGaps']),
      relatedConcepts: ConceptRelation.parseList(json['relatedConcepts']),
      estimatedLevel: _level(json['estimatedLevel']),
      confidence: _confidence(json['confidence']),
    );
  }

  static String _string(Object? v) => v is String ? v.trim() : '';

  static List<String> _strings(Object? v) => v is List
      ? List.unmodifiable([
          for (final e in v)
            if (e is String && e.trim().isNotEmpty) e.trim(),
        ])
      : const [];

  static Map<String, String> _stringMap(Object? v) => v is Map
      ? Map.unmodifiable({
          for (final e in v.entries)
            if (e.key is String &&
                (e.key as String).trim().isNotEmpty &&
                e.value is String &&
                (e.value as String).trim().isNotEmpty)
              (e.key as String).trim(): (e.value as String).trim(),
        })
      : const <String, String>{};

  static KnowledgeLevel _level(Object? v) {
    if (v is! String) return KnowledgeLevel.beginner;
    switch (v.trim().toLowerCase()) {
      case 'advanced':
        return KnowledgeLevel.advanced;
      case 'intermediate':
        return KnowledgeLevel.intermediate;
      default:
        return KnowledgeLevel.beginner;
    }
  }

  static double _confidence(Object? v) =>
      v is num ? v.toDouble().clamp(0.0, 1.0) : 0.0;
}
