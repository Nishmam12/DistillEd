// A coarse "the learner sat down and worked" log.
//
// Deliberately thin — the phase spec is explicit that this is not an analytics
// platform. It exists so the Study Planner (Loop 2.5) can say something honest
// about cadence ("you haven't opened this notebook in nine days"), not to build
// a behavioural profile. No per-interaction events, no timings beyond a
// duration, nothing that leaves the device.

import 'stable_id.dart';

/// The AI features a session touched. Kept as free-form short tags rather than
/// an enum so a new feature doesn't force a schema migration.
class StudySession {
  final String sessionId;
  final int notebookId;
  final DateTime startedAt;
  final Duration duration;
  final List<String> featuresUsed;

  const StudySession({
    required this.sessionId,
    required this.notebookId,
    required this.startedAt,
    required this.duration,
    this.featuresUsed = const [],
  });

  factory StudySession.record({
    required int notebookId,
    required DateTime startedAt,
    required Duration duration,
    List<String> featuresUsed = const [],
    String? sessionId,
  }) =>
      StudySession(
        sessionId: sessionId ?? newStableId(),
        notebookId: notebookId,
        startedAt: startedAt,
        duration: duration,
        featuresUsed: featuresUsed,
      );

  DateTime get endedAt => startedAt.add(duration);
}
