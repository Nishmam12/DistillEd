// What the tutor knows about this student and how they asked to be taught,
// gathered for one notebook. A notifier reads it just before it generates and
// hands the result to `tutorTail`.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../domain/tutor/tutor_prompt.dart';
import 'ai_providers.dart' show learningMemoryProvider;
import 'tutor_note_store.dart';

/// The [TutorContext] for a notebook: the teaching style from Settings and a
/// [LearnerProfile] from Learning Memory.
///
/// Two rules, both about never guessing:
///
///   * A concept is "shaky" only on evidence: the student missed it in a quiz,
///     or the Context Engine flagged it as a gap. `weakConcepts` also returns
///     every concept that has merely appeared on a page, and telling a model a
///     student struggles with something they have only seen is a guess.
///   * If Learning Memory cannot be read, the profile is empty and the style
///     still applies. A missing profile must never cost the student an answer.
///
/// Auto-disposed, and meant to be read with `ref.read(...future)` just before
/// a generation, so each question sees the result of the quiz the student
/// finished a minute ago. Do not `watch` it from a widget to keep it warm: a
/// profile held for the session goes stale the first time mastery changes.
final tutorContextProvider = FutureProvider.autoDispose
    .family<TutorContext, int>((ref, notebookId) async {
  final style = ref.watch(settingsProvider.select((s) => s.teachingStyle));
  final memory = ref.watch(learningMemoryProvider);

  var profile = LearnerProfile.none;
  try {
    final weak = await memory.weakConcepts(notebookId);
    final preferences = await memory.loadPreferences();
    final aboutMe = await TutorNoteStore.load();
    final shaky = [
      for (final c in weak)
        if (c.timesMissedInQuiz > 0 || c.timesFlaggedAsGap > 0) c.conceptName,
    ].take(kMaxProfileConcepts).toList();
    final candidate = LearnerProfile(
      level: preferences.preferredDifficulty,
      weakConcepts: shaky,
      preferredMode: preferences.preferredExplainMode,
      aboutMe: aboutMe,
    );
    if (!candidate.isEmpty) profile = candidate;
  } catch (e) {
    debugPrint('tutorContextProvider: no learner profile ($e)');
  }

  return TutorContext(style: style, profile: profile);
});
