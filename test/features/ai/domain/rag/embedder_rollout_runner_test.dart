// The shadow re-index, run step by step (docs/TECH_MIGRATION_PLAN.md, phase 4.5).
// The runner is tested with fakes for its ports: each fake records what the
// runner asked of it, so the tests can check the order of the steps.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/domain/rag/embedder_rollout.dart';
import 'package:distill_ed/features/ai/domain/rag/embedder_rollout_runner.dart';
import 'package:distill_ed/features/ai/domain/rag/text_embedder.dart';

final _now = DateTime(2026, 10, 9, 0, 10);

class _Embedder implements TextEmbedder {
  _Embedder(this.modelId);

  @override
  final String modelId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _States implements RolloutStateStore {
  _States([this.saved]);

  EmbedderRollout? saved;

  @override
  Future<EmbedderRollout> load(String servingModelId) async =>
      saved ?? EmbedderRollout(servingModelId: servingModelId);

  @override
  Future<void> save(EmbedderRollout rollout) async => saved = rollout;
}

class _Models implements RolloutModels {
  _Models(Set<String> installed) : installed = {...installed};

  final Set<String> installed;
  final log = <String>[];
  int failingDownloads = 0;

  @override
  Future<bool> isInstalled(String modelId) async => installed.contains(modelId);

  @override
  Future<void> download(String modelId) async {
    if (failingDownloads > 0) {
      failingDownloads--;
      throw StateError('network down');
    }
    log.add('download $modelId');
    installed.add(modelId);
  }

  @override
  Future<void> uninstall(String modelId, {String? keeping}) async {
    log.add(keeping == null
        ? 'uninstall $modelId'
        : 'uninstall $modelId keeping $keeping');
    installed.remove(modelId);
  }
}

/// One entry per chunk: the model that built it.
class _Chunks implements RolloutChunks {
  _Chunks(List<String> rows) : rows = [...rows];

  final List<String> rows;
  final log = <String>[];

  @override
  Future<void> deleteModel(String modelId) async {
    log.add('delete $modelId');
    rows.removeWhere((m) => m == modelId);
  }

  @override
  Future<void> deleteModelsExcept(Set<String> keep) async {
    log.add('keep ${keep.toList()..sort()}');
    rows.removeWhere((m) => !keep.contains(m));
  }
}

class _Index implements RolloutIndex {
  _Index(
    this.chunks, {
    required this.total,
    required this.pending,
    this.pendingScript = const [],
  });

  final _Chunks chunks;
  final int total;
  int pending;

  /// Answers to the first pendingPages calls, before [pending] takes over.
  final List<int> pendingScript;
  int passes = 0;

  @override
  Future<int> indexablePages() async => total;

  @override
  Future<int> pendingPages(TextEmbedder target) async =>
      pendingScript.isNotEmpty ? pendingScript.removeAt(0) : pending;

  @override
  Future<void> indexPending(TextEmbedder target) async {
    passes++;
    for (var i = 0; i < pending; i++) {
      chunks.rows.add(target.modelId);
    }
    pending = 0;
  }
}

EmbedderRolloutRunner _runner({
  required _States states,
  required _Models models,
  required _Chunks chunks,
  required _Index index,
}) =>
    EmbedderRolloutRunner(
      states: states,
      models: models,
      chunks: chunks,
      index: index,
      embedderFor: _Embedder.new,
      now: () => _now,
    );

/// A rollout saved at [status], reached through the legal moves, of [total] pages.
EmbedderRollout _saved(RolloutStatus status, {int total = 3, int done = 0}) {
  const idle = EmbedderRollout(servingModelId: 'serving');
  final downloading = idle.start(
    targetModelId: 'target',
    totalPages: total,
    now: _now,
  );
  if (status == RolloutStatus.downloading) return downloading;
  final indexing = downloading.downloaded().progress(done);
  if (status == RolloutStatus.indexing) return indexing;
  final ready = indexing.retarget(total).progress(total).finishIndexing();
  if (status == RolloutStatus.ready) return ready;
  return ready.beginCutover();
}

void main() {
  test(
      'a second advance joins the pass in progress, and runs no pass of its own',
      () async {
    final chunks = _Chunks(['serving', 'serving', 'serving']);
    final index = _Index(chunks, total: 3, pending: 3);
    final runner = _runner(
      states: _States(_saved(RolloutStatus.indexing)),
      models: _Models({'serving', 'target'}),
      chunks: chunks,
      index: index,
    );

    final first = runner.advance('serving');
    final second = runner.advance('serving');
    expect(runner.isAdvancing, isTrue);
    final results = await Future.wait([first, second]);

    expect(index.passes, 1);
    expect(results.map((r) => r.status), everyElement(RolloutStatus.idle));
    expect(runner.isAdvancing, isFalse);
  });

  test('a full run downloads, indexes, switches, and removes the old model',
      () async {
    final states = _States();
    final models = _Models({'serving'});
    final chunks = _Chunks(['serving', 'serving', 'serving']);
    final index = _Index(chunks, total: 3, pending: 3);
    final runner =
        _runner(states: states, models: models, chunks: chunks, index: index);

    await runner.start(servingModelId: 'serving', targetModelId: 'target');
    final finished = await runner.advance('serving');

    expect(finished.status, RolloutStatus.idle);
    expect(finished.servingModelId, 'target');
    expect(finished.targetModelId, isNull);
    expect(models.log, ['download target', 'uninstall serving keeping target']);
    expect(chunks.log, ['keep [target]']);
    expect(chunks.rows, ['target', 'target', 'target']);
    expect(index.passes, 1);
  });

  test('advancing an idle rollout does nothing', () async {
    final models = _Models({'serving'});
    final chunks = _Chunks(['serving']);
    final index = _Index(chunks, total: 1, pending: 0);
    final runner = _runner(
        states: _States(), models: models, chunks: chunks, index: index);

    final idle = await runner.advance('serving');

    expect(idle.status, RolloutStatus.idle);
    expect(models.log, isEmpty);
    expect(chunks.log, isEmpty);
  });

  test(
      'a restart during the download skips the download when the files are there',
      () async {
    final models = _Models({'serving', 'target'});
    final chunks = _Chunks(['serving', 'serving', 'serving']);
    final index = _Index(chunks, total: 3, pending: 3);
    final runner = _runner(
        states: _States(_saved(RolloutStatus.downloading)),
        models: models,
        chunks: chunks,
        index: index);

    await runner.advance('serving');

    expect(models.log, ['uninstall serving keeping target']);
    expect(index.passes, 1);
  });

  test('a restart while indexing indexes only what is left, then switches',
      () async {
    final models = _Models({'serving', 'target'});
    final chunks =
        _Chunks(['serving', 'serving', 'serving', 'target', 'target']);
    final index = _Index(chunks, total: 3, pending: 1);
    final runner = _runner(
        states: _States(_saved(RolloutStatus.indexing, done: 2)),
        models: models,
        chunks: chunks,
        index: index);

    final finished = await runner.advance('serving');

    expect(finished.servingModelId, 'target');
    expect(index.passes, 1);
    expect(chunks.rows, ['target', 'target', 'target']);
  });

  test('a page edited after the target pass is rebuilt before the switch',
      () async {
    final models = _Models({'serving', 'target'});
    final chunks = _Chunks(
        ['serving', 'serving', 'serving', 'target', 'target', 'target']);
    // Before the first pass 3 pages are pending, then none; after the pass the
    // ready check finds one edited page, and the second pass rebuilds it.
    final index =
        _Index(chunks, total: 3, pending: 3, pendingScript: [3, 0, 1]);
    final runner = _runner(
        states: _States(_saved(RolloutStatus.indexing)),
        models: models,
        chunks: chunks,
        index: index);

    final finished = await runner.advance('serving');

    expect(finished.servingModelId, 'target');
    expect(index.passes, 2);
  });

  test(
      'cancelling mid-indexing removes the target chunks and files, and keeps the serving model',
      () async {
    final models = _Models({'serving', 'target'});
    final chunks = _Chunks(['serving', 'serving', 'target']);
    final index = _Index(chunks, total: 3, pending: 2);
    final runner = _runner(
        states: _States(_saved(RolloutStatus.indexing, done: 1)),
        models: models,
        chunks: chunks,
        index: index);

    final cancelled = await runner.cancel('serving');

    expect(cancelled.status, RolloutStatus.idle);
    expect(cancelled.servingModelId, 'serving');
    expect(chunks.rows, ['serving', 'serving']);
    expect(models.log, ['uninstall target keeping serving']);
  });

  test('a switch under way cannot be cancelled, and nothing is removed',
      () async {
    final models = _Models({'serving', 'target'});
    final chunks = _Chunks(['serving', 'target']);
    final index = _Index(chunks, total: 1, pending: 0);
    final states = _States(_saved(RolloutStatus.cuttingOver, total: 1));
    final runner =
        _runner(states: states, models: models, chunks: chunks, index: index);

    await expectLater(runner.cancel('serving'), throwsStateError);
    expect(chunks.rows, ['serving', 'target']);
    expect(models.log, isEmpty);
    expect(states.saved!.status, RolloutStatus.cuttingOver);
  });

  test(
      'a restart during the switch finishes it, and running it again changes nothing',
      () async {
    final models = _Models({'serving', 'target'});
    final chunks = _Chunks(['serving', 'serving', 'target', 'target']);
    final index = _Index(chunks, total: 2, pending: 0);
    final runner = _runner(
        states: _States(_saved(RolloutStatus.cuttingOver, total: 2)),
        models: models,
        chunks: chunks,
        index: index);

    final first = await runner.advance('serving');
    final second = await runner.advance('serving');

    expect(first.servingModelId, 'target');
    expect(second.status, RolloutStatus.idle);
    expect(second.servingModelId, 'target');
    expect(chunks.rows, ['target', 'target']);
    expect(models.log, ['uninstall serving keeping target']);
  });

  test(
      'a failed download keeps the rollout where it was, and the next advance resumes it',
      () async {
    final models = _Models({'serving'})..failingDownloads = 1;
    final chunks = _Chunks(['serving', 'serving', 'serving']);
    final index = _Index(chunks, total: 3, pending: 3);
    final states = _States();
    final runner =
        _runner(states: states, models: models, chunks: chunks, index: index);
    await runner.start(servingModelId: 'serving', targetModelId: 'target');

    await expectLater(runner.advance('serving'), throwsStateError);
    expect(states.saved!.status, RolloutStatus.downloading);

    final finished = await runner.advance('serving');
    expect(finished.servingModelId, 'target');
  });

  group('resume', () {
    test('a bumped active model starts and completes a rollout', () async {
      final states = _States(const EmbedderRollout(servingModelId: 'serving'));
      final chunks = _Chunks(['serving', 'serving']);
      final runner = _runner(
        states: states,
        models: _Models({'serving'}),
        chunks: chunks,
        index: _Index(chunks, total: 2, pending: 2),
      );

      await runner.resume('target');

      expect(states.saved!.servingModelId, 'target');
      expect(chunks.rows, ['target', 'target']);
    });

    test('a refused download waits, then goes ahead once allowed', () async {
      final states = _States(const EmbedderRollout(servingModelId: 'serving'));
      final models = _Models({'serving'});
      final chunks = _Chunks(['serving']);
      final runner = _runner(
        states: states,
        models: models,
        chunks: chunks,
        index: _Index(chunks, total: 1, pending: 1),
      );

      expect(await runner.resume('target', mayDownload: () async => false),
          isTrue);
      expect(states.saved!.status, RolloutStatus.downloading);
      expect(models.log, isEmpty);

      expect(await runner.resume('target', mayDownload: () async => true),
          isFalse);
      expect(states.saved!.servingModelId, 'target');
    });

    test('an unchanged active model only pins the serving id', () async {
      final states = _States();
      final chunks = _Chunks(['serving']);
      final runner = _runner(
        states: states,
        models: _Models({'serving'}),
        chunks: chunks,
        index: _Index(chunks, total: 1, pending: 0),
      );

      await runner.resume('serving');

      expect(states.saved!.servingModelId, 'serving');
      expect(states.saved!.isRunning, isFalse);
    });

    test('a switch interrupted by a crash is finished', () async {
      final states = _States(_saved(RolloutStatus.cuttingOver));
      final chunks = _Chunks(['target', 'target', 'target']);
      final runner = _runner(
        states: states,
        models: _Models({'serving', 'target'}),
        chunks: chunks,
        index: _Index(chunks, total: 3, pending: 0),
      );

      await runner.resume('target');

      expect(states.saved!.servingModelId, 'target');
      expect(states.saved!.isRunning, isFalse);
    });
  });

  test('during a switch the target answers', () {
    expect(_saved(RolloutStatus.ready).answeringModelId, 'serving');
    expect(_saved(RolloutStatus.cuttingOver).answeringModelId, 'target');
  });
}
