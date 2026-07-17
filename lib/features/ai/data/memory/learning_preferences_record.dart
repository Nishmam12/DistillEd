// Isar persistence for [LearningPreferences] — a singleton row (id [singletonId]),
// since preferences describe the one learner using this install.
//
// Only the *stored* preferences live here. The derived pace signal
// (`averageReviewsToMastery`) is deliberately absent: it's recomputed from
// mastery data on load so it can't go stale.
//
// Enums are stored as text and parsed tolerantly — an unknown value reads back
// as null (fall back to the caller's default) rather than throwing.

import 'package:isar/isar.dart';

import '../../domain/context_engine/page_context.dart';
import '../../domain/features/explainer.dart';
import '../../domain/memory/learning_preferences.dart';

part 'learning_preferences_record.g.dart';

@collection
class LearningPreferencesRecord {
  /// Fixed: there is exactly one preferences row per install.
  static const int singletonId = 0;

  Id id = singletonId;

  String? preferredExplainMode;
  String? preferredDifficulty;

  LearningPreferences toDomain() => LearningPreferences(
        preferredExplainMode: _explainMode(preferredExplainMode),
        preferredDifficulty: _difficulty(preferredDifficulty),
      );

  static LearningPreferencesRecord fromDomain(LearningPreferences prefs) =>
      LearningPreferencesRecord()
        ..id = singletonId
        ..preferredExplainMode = prefs.preferredExplainMode?.name
        ..preferredDifficulty = prefs.preferredDifficulty?.name;

  static ExplainMode? _explainMode(String? raw) =>
      _byName(ExplainMode.values, raw);

  static KnowledgeLevel? _difficulty(String? raw) =>
      _byName(KnowledgeLevel.values, raw);

  static T? _byName<T extends Enum>(List<T> values, String? raw) {
    final key = (raw ?? '').trim();
    if (key.isEmpty) return null;
    for (final v in values) {
      if (v.name == key) return v;
    }
    return null;
  }
}
