// The shadow re-index (docs/TECH_MIGRATION_PLAN.md, phase 4.5) changes embedding
// models without a search gap. The state of that change is kept here, as data,
// so that a crash at any point resumes where it stopped: which model serves,
// which is being built, and how far the build has got.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/domain/rag/embedder_rollout.dart';

final _now = DateTime(2026, 10, 8, 23, 0);

/// A rollout parked at [status], reached through the legal moves, from a serving
/// model called `serving` and a target called `target` of [total] pages.
EmbedderRollout rolloutAt(RolloutStatus status, {int total = 3}) {
  const idle = EmbedderRollout(servingModelId: 'serving');
  final downloading = idle.start(
    targetModelId: 'target',
    totalPages: total,
    now: _now,
  );
  if (status == RolloutStatus.downloading) return downloading;
  final indexing = downloading.downloaded();
  if (status == RolloutStatus.indexing) return indexing;
  final ready = indexing.progress(total).finishIndexing();
  if (status == RolloutStatus.ready) return ready;
  if (status == RolloutStatus.cuttingOver) return ready.beginCutover();
  return idle;
}

void main() {
  test('a rollout starts from idle, to a different model, keeping the serving one',
      () {
    final started = const EmbedderRollout(servingModelId: 'serving').start(
      targetModelId: 'target',
      totalPages: 12,
      now: _now,
    );

    expect(started.status, RolloutStatus.downloading);
    expect(started.servingModelId, 'serving');
    expect(started.targetModelId, 'target');
    expect(started.totalPages, 12);
    expect(started.indexedPages, 0);
    expect(started.startedAt, _now);
  });

  test('a rollout cannot target the model already serving', () {
    expect(
      () => const EmbedderRollout(servingModelId: 'serving').start(
        targetModelId: 'serving',
        totalPages: 1,
        now: _now,
      ),
      throwsStateError,
    );
  });

  test('a second rollout cannot start while one is running', () {
    expect(
      () => rolloutAt(RolloutStatus.indexing).start(
        targetModelId: 'other',
        totalPages: 1,
        now: _now,
      ),
      throwsStateError,
    );
  });

  test('progress counts forward only, and never past the total', () {
    final two = rolloutAt(RolloutStatus.indexing).progress(2);

    expect(two.indexedPages, 2);
    expect(() => two.progress(1), throwsStateError);
    expect(() => two.progress(4), throwsStateError);
  });

  test('ready only once every page has its target-model chunks', () {
    final indexing = rolloutAt(RolloutStatus.indexing);

    expect(() => indexing.finishIndexing(), throwsStateError);
    expect(indexing.progress(3).finishIndexing().status, RolloutStatus.ready);
  });

  test('a cut-over makes the target the serving model and clears the rollout',
      () {
    final done = rolloutAt(RolloutStatus.ready).beginCutover().completeCutover();

    expect(done.servingModelId, 'target');
    expect(done.targetModelId, isNull);
    expect(done.status, RolloutStatus.idle);
  });

  test('a cut-over cannot be cancelled, since it resumes instead', () {
    expect(
      () => rolloutAt(RolloutStatus.cuttingOver).cancel(),
      throwsStateError,
    );
  });

  test('cancel from any other status returns to idle and keeps the serving model',
      () {
    for (final status in [
      RolloutStatus.downloading,
      RolloutStatus.indexing,
      RolloutStatus.ready,
    ]) {
      final cancelled = rolloutAt(status).cancel();

      expect(cancelled.status, RolloutStatus.idle, reason: status.name);
      expect(cancelled.servingModelId, 'serving', reason: status.name);
      expect(cancelled.targetModelId, isNull, reason: status.name);
    }
  });

  test('every status survives a save and a load, so a crash resumes there', () {
    for (final status in RolloutStatus.values) {
      final original = rolloutAt(status);
      final restored = EmbedderRollout.fromJson(original.toJson());

      expect(restored.servingModelId, original.servingModelId,
          reason: status.name);
      expect(restored.targetModelId, original.targetModelId,
          reason: status.name);
      expect(restored.status, original.status, reason: status.name);
      expect(restored.indexedPages, original.indexedPages, reason: status.name);
      expect(restored.totalPages, original.totalPages, reason: status.name);
      expect(restored.startedAt, original.startedAt, reason: status.name);
    }
  });

  test('a move out of order throws rather than guessing', () {
    expect(() => rolloutAt(RolloutStatus.idle).downloaded(), throwsStateError);
    expect(() => rolloutAt(RolloutStatus.downloading).progress(0),
        throwsStateError);
    expect(() => rolloutAt(RolloutStatus.indexing).beginCutover(),
        throwsStateError);
  });

  test('the total can grow while indexing, but never drop below what is done', () {
    final indexing = rolloutAt(RolloutStatus.indexing).progress(2);

    expect(indexing.retarget(5).totalPages, 5);
    expect(() => indexing.retarget(1), throwsStateError);
  });

  test('a ready rollout reopens to indexing when a page changed after it was ready',
      () {
    final reopened = rolloutAt(RolloutStatus.ready).reopen();

    expect(reopened.status, RolloutStatus.indexing);
    expect(reopened.targetModelId, 'target');
    expect(() => rolloutAt(RolloutStatus.indexing).reopen(), throwsStateError);
  });
}
