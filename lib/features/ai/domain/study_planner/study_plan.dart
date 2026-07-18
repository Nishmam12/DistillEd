// The Study Planner's data model (Phase 2, Loop 2.5): a day-by-day plan built
// from real Learning-Memory signals, not invented by the model.
//
// The schedule — WHICH concept, on WHICH day, for WHAT reason — is decided by a
// pure, deterministic scheduler (`study_scheduler.dart`). The local model's only
// job is optional prose framing (`StudyPlan.strategyNote`), grounded in these
// same concepts; it never chooses or reorders the work. So a plan is fully
// usable offline with no model downloaded, and can never schedule a concept the
// learner's notes don't contain.

/// Why a concept is on the plan — drives the suggested activity and its colour.
enum StudyTaskKind {
  /// A weak concept (low mastery / missed in quizzes / flagged in a gap):
  /// re-read and re-understand.
  review,

  /// A concept whose spaced-review interval has elapsed: test recall.
  quiz,

  /// A concept the notes reference but never actually explain (a Knowledge
  /// Graph gap): study it fresh.
  learnNew,
}

extension StudyTaskKindLabel on StudyTaskKind {
  /// Imperative label for the activity list.
  String get verb => switch (this) {
        StudyTaskKind.review => 'Review',
        StudyTaskKind.quiz => 'Quiz yourself on',
        StudyTaskKind.learnNew => 'Learn',
      };

  /// Short reason shown under the task.
  String get reason => switch (this) {
        StudyTaskKind.review => "you've been struggling with this",
        StudyTaskKind.quiz => 'due for review',
        StudyTaskKind.learnNew => 'mentioned in your notes but not explained yet',
      };

  String get storageKey => name;

  static StudyTaskKind fromStorageKey(String? raw) {
    final key = (raw ?? '').trim();
    return StudyTaskKind.values.firstWhere(
      (k) => k.name == key,
      orElse: () => StudyTaskKind.review,
    );
  }
}

/// One concept to work on, and why.
class StudyTask {
  final String conceptName;
  final StudyTaskKind kind;
  const StudyTask({required this.conceptName, required this.kind});

  /// A ready-to-read line, e.g. "Review mitosis". The screen can show this as-is
  /// or pair it with [StudyTaskKind.reason].
  String get label => '${kind.verb} $conceptName';
}

/// One day of the plan.
class StudyDay {
  final DateTime date;
  final List<StudyTask> tasks;

  /// Learner-toggled. A rest day (no tasks) counts as done once its date passes,
  /// but completion is the user's call — see [StudyPlan.progress].
  final bool completed;

  const StudyDay({
    required this.date,
    required this.tasks,
    this.completed = false,
  });

  bool get isRest => tasks.isEmpty;

  StudyDay copyWith({bool? completed}) => StudyDay(
        date: date,
        tasks: tasks,
        completed: completed ?? this.completed,
      );
}

/// The horizon a plan covers.
enum StudyHorizonKind { week, twoWeeks, month, exam }

extension StudyHorizonKindLabel on StudyHorizonKind {
  String get label => switch (this) {
        StudyHorizonKind.week => '7-day',
        StudyHorizonKind.twoWeeks => '14-day',
        StudyHorizonKind.month => '30-day',
        StudyHorizonKind.exam => 'Exam countdown',
      };

  String get storageKey => name;

  static StudyHorizonKind fromStorageKey(String? raw) {
    final key = (raw ?? '').trim();
    return StudyHorizonKind.values.firstWhere(
      (k) => k.name == key,
      orElse: () => StudyHorizonKind.week,
    );
  }
}

/// A start date, a kind, and (for [StudyHorizonKind.exam]) a target date.
class StudyHorizon {
  final StudyHorizonKind kind;

  /// Normalized to a date (midnight) so day arithmetic is clean.
  final DateTime startDate;

  /// The exam date, only for [StudyHorizonKind.exam]. Ignored otherwise.
  final DateTime? examDate;

  StudyHorizon({
    required this.kind,
    required DateTime startDate,
    DateTime? examDate,
  })  : startDate = DateTime(startDate.year, startDate.month, startDate.day),
        examDate = examDate == null
            ? null
            : DateTime(examDate.year, examDate.month, examDate.day);

  /// Fixed horizons; the exam horizon needs [examDate].
  static const _fixedDays = {
    StudyHorizonKind.week: 7,
    StudyHorizonKind.twoWeeks: 14,
    StudyHorizonKind.month: 30,
  };

  /// Longest exam countdown we'll schedule — a plan hundreds of days out is
  /// noise, and caps the number of [StudyDay]s we build/persist.
  static const int examDayCap = 60;

  /// How many days the plan spans, always at least 1.
  int get dayCount {
    if (kind != StudyHorizonKind.exam) return _fixedDays[kind]!;
    final exam = examDate;
    if (exam == null) return 1;
    // Inclusive of the exam day; clamped so a past/absurd date still yields a
    // sane plan.
    final span = exam.difference(startDate).inDays + 1;
    return span.clamp(1, examDayCap);
  }
}

class StudyPlan {
  final int notebookId;
  final StudyHorizonKind horizonKind;
  final DateTime createdAt;
  final List<StudyDay> days;

  /// Optional model-written framing, grounded in the plan's concepts. Empty when
  /// no model was available — the plan stands without it.
  final String strategyNote;

  const StudyPlan({
    required this.notebookId,
    required this.horizonKind,
    required this.createdAt,
    required this.days,
    this.strategyNote = '',
  });

  bool get isEmpty => days.every((d) => d.tasks.isEmpty);

  /// Distinct concepts the plan covers.
  int get conceptCount =>
      {for (final d in days) for (final t in d.tasks) t.conceptName}.length;

  /// Fraction of NON-rest days marked done, 0.0–1.0 (1.0 when there are none to
  /// do — an empty plan isn't "0% complete forever").
  double get progress {
    final workDays = days.where((d) => !d.isRest).toList();
    if (workDays.isEmpty) return 1.0;
    final done = workDays.where((d) => d.completed).length;
    return done / workDays.length;
  }

  StudyPlan copyWith({List<StudyDay>? days, String? strategyNote}) => StudyPlan(
        notebookId: notebookId,
        horizonKind: horizonKind,
        createdAt: createdAt,
        days: days ?? this.days,
        strategyNote: strategyNote ?? this.strategyNote,
      );

  /// Returns a copy with the day at [index] toggled complete/incomplete.
  StudyPlan toggleDay(int index, bool completed) {
    if (index < 0 || index >= days.length) return this;
    final next = [...days];
    next[index] = next[index].copyWith(completed: completed);
    return copyWith(days: next);
  }
}
