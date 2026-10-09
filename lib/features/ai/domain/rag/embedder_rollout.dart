// The shadow re-index's state (docs/TECH_MIGRATION_PLAN.md, phase 4.5): which
// embedding model serves questions, which one is being built beside it, and how
// far the build has got.
//
// Plain data with checked moves. A move the state does not allow throws instead
// of guessing, so a crash can only ever leave a status the next launch knows how
// to resume: the store is written after each move, and each status says what to
// do next. Persistence and the indexing itself live elsewhere; this only decides
// what is legal.

/// Where a rollout is. A rollout that is not [idle] names a target model.
enum RolloutStatus {
  /// No rollout. The serving model answers, and nothing else is built.
  idle,

  /// The target model's files are being downloaded.
  downloading,

  /// The target's chunks are being built, page by page, beside the serving ones.
  indexing,

  /// Every page has target chunks. Waiting for the switch.
  ready,

  /// The switch is being made. It resumes on the next launch if interrupted.
  cuttingOver,
}

class EmbedderRollout {
  const EmbedderRollout({
    required this.servingModelId,
    this.targetModelId,
    this.status = RolloutStatus.idle,
    this.indexedPages = 0,
    this.totalPages = 0,
    this.startedAt,
  }) : assert(
          (status == RolloutStatus.idle) == (targetModelId == null),
          'a target is named exactly while a rollout runs',
        );

  /// The model that answers questions. It changes only by a completed cut-over.
  final String servingModelId;

  /// The model being built, or null when no rollout runs.
  final String? targetModelId;

  final RolloutStatus status;

  /// Pages of the notebook that have target-model chunks, counted from zero.
  final int indexedPages;

  final int totalPages;

  final DateTime? startedAt;

  /// Whether a rollout is in progress: anything but idle.
  bool get isRunning => status != RolloutStatus.idle;

  /// The model that answers questions right now. A switch under way has already
  /// removed the old model's chunks, so the target answers from then on, and a
  /// crash mid-switch must not leave questions on a model with none.
  String get answeringModelId =>
      status == RolloutStatus.cuttingOver ? targetModelId! : servingModelId;

  /// Begins a rollout to [targetModelId], which must not be the serving model.
  EmbedderRollout start({
    required String targetModelId,
    required int totalPages,
    required DateTime now,
  }) {
    _require(status == RolloutStatus.idle, 'a rollout is already running');
    _require(
      targetModelId != servingModelId,
      'the target is the model already serving',
    );
    return EmbedderRollout(
      servingModelId: servingModelId,
      targetModelId: targetModelId,
      status: RolloutStatus.downloading,
      totalPages: totalPages,
      startedAt: now,
    );
  }

  /// The target's files are in place, so indexing can begin.
  EmbedderRollout downloaded() {
    _require(status == RolloutStatus.downloading, 'nothing is downloading');
    return _with(status: RolloutStatus.indexing);
  }

  /// Records how many pages have target chunks. Only moves forward, within the
  /// total.
  EmbedderRollout progress(int indexedPages) {
    _require(status == RolloutStatus.indexing, 'nothing is being indexed');
    _require(
      indexedPages >= this.indexedPages && indexedPages <= totalPages,
      'progress moves forward only, and not past the total',
    );
    return _with(indexedPages: indexedPages);
  }

  /// The page count may grow while indexing (a page added during the rollout is
  /// counted), but never drops below what is already done.
  EmbedderRollout retarget(int totalPages) {
    _require(status == RolloutStatus.indexing, 'nothing is being indexed');
    _require(
      totalPages >= indexedPages,
      'the total cannot drop below what is done',
    );
    return _with(totalPages: totalPages);
  }

  /// Every page is built, so the rollout waits for the switch.
  EmbedderRollout finishIndexing() {
    _require(status == RolloutStatus.indexing, 'nothing is being indexed');
    _require(indexedPages == totalPages, 'not every page is indexed yet');
    return _with(status: RolloutStatus.ready);
  }

  /// A page changed after the rollout was ready, so the target is not complete:
  /// back to indexing, where the changed page is rebuilt.
  EmbedderRollout reopen() {
    _require(status == RolloutStatus.ready, 'the target is not ready');
    return _with(status: RolloutStatus.indexing);
  }

  /// Starts the switch. The serving model is still the old one until it ends.
  EmbedderRollout beginCutover() {
    _require(status == RolloutStatus.ready, 'the target is not ready yet');
    return _with(status: RolloutStatus.cuttingOver);
  }

  /// Ends the switch: the target serves, and no rollout is left.
  EmbedderRollout completeCutover() {
    _require(status == RolloutStatus.cuttingOver, 'no switch is under way');
    return EmbedderRollout(servingModelId: targetModelId!);
  }

  /// Abandons a rollout before its switch, leaving the serving model as it was.
  /// A switch that has begun cannot be abandoned: it is finished instead.
  EmbedderRollout cancel() {
    _require(
      status != RolloutStatus.cuttingOver,
      'a switch under way is finished, not cancelled',
    );
    return EmbedderRollout(servingModelId: servingModelId);
  }

  Map<String, Object?> toJson() => {
        'servingModelId': servingModelId,
        'targetModelId': targetModelId,
        'status': status.name,
        'indexedPages': indexedPages,
        'totalPages': totalPages,
        'startedAt': startedAt?.toIso8601String(),
      };

  factory EmbedderRollout.fromJson(Map<String, Object?> json) =>
      EmbedderRollout(
        servingModelId: json['servingModelId']! as String,
        targetModelId: json['targetModelId'] as String?,
        status: RolloutStatus.values.byName(json['status']! as String),
        indexedPages: json['indexedPages']! as int,
        totalPages: json['totalPages']! as int,
        startedAt: switch (json['startedAt']) {
          final String text => DateTime.parse(text),
          _ => null,
        },
      );

  EmbedderRollout _with({
    RolloutStatus? status,
    int? indexedPages,
    int? totalPages,
  }) =>
      EmbedderRollout(
        servingModelId: servingModelId,
        targetModelId: targetModelId,
        status: status ?? this.status,
        indexedPages: indexedPages ?? this.indexedPages,
        totalPages: totalPages ?? this.totalPages,
        startedAt: startedAt,
      );

  static void _require(bool ok, String why) {
    if (!ok) throw StateError(why);
  }
}
