// What the learner knows about one concept, and how that changes over time.
//
// This is the pure heart of Phase 2's Learning Memory: every state transition
// (seeing a concept, answering a quiz question about it, falling due for review)
// is an immutable, side-effect-free function here, so the rules are unit-tested
// without Isar. `data/memory/` persists these; it owns no rules.
//
// SYNC-READY (per phase spec §1): identity is the natural key
// [notebookId] + [conceptKey] — deterministic, so two devices that independently
// observe "Photosynthesis" in the same notebook derive the SAME identity and
// merge cleanly. Isar's autoincrement id is a local storage detail only and is
// never part of identity.
//
// KNOWN BOUNDARY (decided 2026-07-17, Nabil): the *concept* half of that key is
// genuinely stable, but `notebookId` is itself `Isar.autoIncrement` on the
// `Notebook` collection, which has no stable uid — so the pair is not yet
// cross-device stable. Deliberately left as-is: Phase 2 is local-only and the
// spec says not to build sync or guess at Supabase's shape. A future sync layer
// gives Notebook a stable uid and remaps this foreign key once; nothing in the
// rules below depends on notebookId being anything but an opaque scope handle.

/// How well the learner knows a concept. Ordered — later means stronger.
enum MasteryLevel { unseen, learning, practiced, mastered }

extension MasteryLevelX on MasteryLevel {
  /// Rank for comparisons; mirrors declaration order.
  int get rank => index;

  bool isStrongerThan(MasteryLevel other) => rank > other.rank;

  /// One step up, saturating at [MasteryLevel.mastered].
  MasteryLevel get promoted => switch (this) {
        MasteryLevel.unseen => MasteryLevel.learning,
        MasteryLevel.learning => MasteryLevel.practiced,
        MasteryLevel.practiced => MasteryLevel.mastered,
        MasteryLevel.mastered => MasteryLevel.mastered,
      };

  /// One step down, saturating at [MasteryLevel.learning] — once a concept has
  /// been seen it never returns to `unseen`.
  MasteryLevel get demoted => switch (this) {
        MasteryLevel.unseen => MasteryLevel.learning,
        MasteryLevel.learning => MasteryLevel.learning,
        MasteryLevel.practiced => MasteryLevel.learning,
        MasteryLevel.mastered => MasteryLevel.practiced,
      };

  String get storageKey => name;

  /// Tolerant parse — unknown/blank values fall back to [MasteryLevel.unseen],
  /// consistent with how the rest of `features/ai` treats untrusted input.
  static MasteryLevel fromStorageKey(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    return MasteryLevel.values.firstWhere(
      (l) => l.name == key,
      orElse: () => MasteryLevel.unseen,
    );
  }
}

/// The stable identity for a concept within a notebook: case/whitespace-folded
/// so "Cell  Wall", "cell wall" and " Cell Wall " are one concept, not three.
/// The human-facing spelling is kept separately in [ConceptMastery.conceptName].
String normalizeConceptKey(String conceptName) =>
    conceptName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// How long a concept rests before it's worth reviewing again — an SM-2-lite
/// ladder (the phase spec explicitly does not want a full spaced-repetition
/// engine). Stronger mastery earns a longer interval.
Duration reviewIntervalFor(MasteryLevel level) => switch (level) {
      MasteryLevel.unseen => Duration.zero,
      MasteryLevel.learning => const Duration(days: 1),
      MasteryLevel.practiced => const Duration(days: 3),
      MasteryLevel.mastered => const Duration(days: 7),
    };

/// Which of [conceptNames] are mentioned in [text], as normalized keys.
///
/// Used to attribute a quiz question to the concepts it actually tests, so a
/// miss decrements those concepts rather than the whole topic. Matching is a
/// normalized substring check — deliberately simple and predictable; a question
/// that names no known concept attributes to nothing rather than guessing.
List<String> conceptKeysMentionedIn(String text, Iterable<String> conceptNames) {
  final haystack = normalizeConceptKey(text);
  if (haystack.isEmpty) return const [];
  final keys = <String>{};
  for (final name in conceptNames) {
    final key = normalizeConceptKey(name);
    if (key.isNotEmpty && haystack.contains(key)) keys.add(key);
  }
  return keys.toList();
}

/// Which of [concepts] a Context Engine knowledge-gap line refers to.
///
/// `knowledgeGaps` are prose a tutor would say ("photosynthesis is used but
/// never defined"), not concept names — feeding them in as concepts would mint
/// junk entries. Instead each gap is matched back onto concepts the page
/// actually has, by normalized mention.
List<ConceptMastery> conceptsMentionedIn(
  String gapText,
  Iterable<ConceptMastery> concepts,
) {
  final haystack = normalizeConceptKey(gapText);
  if (haystack.isEmpty) return const [];
  return [
    for (final c in concepts)
      if (c.conceptKey.isNotEmpty && haystack.contains(c.conceptKey)) c,
  ];
}

/// Concepts the learner is measurably struggling with, weakest first (lowest
/// mastery, then most-missed). The definition of "weak" lives here, not in a
/// query, so every caller and every test agrees on it.
List<ConceptMastery> selectWeak(Iterable<ConceptMastery> all) {
  final weak = all.where((c) => c.isWeak).toList();
  weak.sort((a, b) {
    final byLevel = a.level.rank.compareTo(b.level.rank);
    if (byLevel != 0) return byLevel;
    return b.timesMissedInQuiz.compareTo(a.timesMissedInQuiz);
  });
  return weak;
}

/// Concepts at [MasteryLevel.mastered].
List<ConceptMastery> selectMastered(Iterable<ConceptMastery> all) =>
    all.where((c) => c.level == MasteryLevel.mastered).toList();

/// Concepts whose review interval has elapsed by [now], most overdue first.
List<ConceptMastery> selectDueForReview(
  Iterable<ConceptMastery> all,
  DateTime now,
) {
  final due = all.where((c) => c.isDueForReview(now)).toList();
  due.sort((a, b) => a.dueAt().compareTo(b.dueAt()));
  return due;
}

/// One learner ↔ concept relationship.
class ConceptMastery {
  /// Display spelling, as the Context Engine first surfaced it.
  final String conceptName;

  /// Normalized identity — see [normalizeConceptKey]. Half of the natural key.
  final String conceptKey;

  /// The other half of the natural key. Mastery is tracked per notebook: the
  /// same word in two notebooks is two learning tracks.
  final int notebookId;

  /// The page the concept was most recently seen on (a breadcrumb for "jump to
  /// source" later, not part of identity).
  final int? lastPageId;

  final MasteryLevel level;

  /// When the concept was last encountered on a page.
  final DateTime lastSeenAt;

  /// When the learner last actively *reviewed* it (answered a quiz question).
  /// Null until the first review — drives [isDueForReview].
  final DateTime? lastReviewedAt;

  final int timesReviewed;
  final int timesMissedInQuiz;

  /// How often the Context Engine flagged this concept inside a knowledge gap
  /// ("used but never defined"). Evidence of shaky understanding that costs the
  /// learner nothing to produce — they never had to answer anything.
  final int timesFlaggedAsGap;

  const ConceptMastery({
    required this.conceptName,
    required this.conceptKey,
    required this.notebookId,
    required this.level,
    required this.lastSeenAt,
    this.lastPageId,
    this.lastReviewedAt,
    this.timesReviewed = 0,
    this.timesMissedInQuiz = 0,
    this.timesFlaggedAsGap = 0,
  });

  /// A concept the Context Engine just surfaced but that has no history yet.
  factory ConceptMastery.firstSeen({
    required String conceptName,
    required int notebookId,
    required DateTime at,
    int? pageId,
  }) =>
      ConceptMastery(
        conceptName: conceptName.trim(),
        conceptKey: normalizeConceptKey(conceptName),
        notebookId: notebookId,
        lastPageId: pageId,
        // Seeing a concept is evidence of exposure, never of mastery.
        level: MasteryLevel.learning,
        lastSeenAt: at,
      );

  /// The learner encountered this concept on a page again (Context Engine
  /// `keyConcepts`/`knowledgeGaps`). Exposure refreshes [lastSeenAt] and lifts
  /// an unseen concept to `learning`, but — per the phase spec — never promotes
  /// beyond that: reading is not testing, so an already-`practiced` or
  /// `mastered` concept keeps its hard-won level.
  ConceptMastery observed({required DateTime at, int? pageId}) => copyWith(
        level: level == MasteryLevel.unseen ? MasteryLevel.learning : level,
        lastSeenAt: at,
        lastPageId: pageId ?? lastPageId,
      );

  /// The learner answered a quiz question about this concept. A correct answer
  /// promotes one step; a miss demotes one step and is counted, so
  /// [weakConcepts]-style queries can rank genuine trouble spots.
  ConceptMastery afterQuiz({required bool correct, required DateTime at}) =>
      copyWith(
        level: correct ? level.promoted : level.demoted,
        lastReviewedAt: at,
        lastSeenAt: at,
        timesReviewed: timesReviewed + 1,
        timesMissedInQuiz: correct ? timesMissedInQuiz : timesMissedInQuiz + 1,
      );

  /// The Context Engine flagged this concept inside a knowledge gap. That's a
  /// weakness signal, not a test result: it counts the flag and refreshes
  /// exposure, but never moves [level] — only answering questions proves (or
  /// disproves) recall.
  ConceptMastery flaggedAsGap({required DateTime at, int? pageId}) => copyWith(
        level: level == MasteryLevel.unseen ? MasteryLevel.learning : level,
        lastSeenAt: at,
        lastPageId: pageId ?? lastPageId,
        timesFlaggedAsGap: timesFlaggedAsGap + 1,
      );

  /// When this concept next wants attention. A never-reviewed concept is due
  /// immediately — it's all exposure and no recall.
  DateTime dueAt() {
    final reviewed = lastReviewedAt;
    if (reviewed == null) return lastSeenAt;
    return reviewed.add(reviewIntervalFor(level));
  }

  bool isDueForReview(DateTime now) => !now.isBefore(dueAt());

  /// A concept the learner is measurably struggling with: below `practiced`,
  /// missed in a quiz, or flagged as a knowledge gap.
  bool get isWeak =>
      level.rank < MasteryLevel.practiced.rank ||
      timesMissedInQuiz > 0 ||
      timesFlaggedAsGap > 0;

  ConceptMastery copyWith({
    String? conceptName,
    int? lastPageId,
    MasteryLevel? level,
    DateTime? lastSeenAt,
    DateTime? lastReviewedAt,
    int? timesReviewed,
    int? timesMissedInQuiz,
    int? timesFlaggedAsGap,
  }) =>
      ConceptMastery(
        conceptName: conceptName ?? this.conceptName,
        conceptKey: conceptKey,
        notebookId: notebookId,
        lastPageId: lastPageId ?? this.lastPageId,
        level: level ?? this.level,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        timesReviewed: timesReviewed ?? this.timesReviewed,
        timesMissedInQuiz: timesMissedInQuiz ?? this.timesMissedInQuiz,
        timesFlaggedAsGap: timesFlaggedAsGap ?? this.timesFlaggedAsGap,
      );
}
