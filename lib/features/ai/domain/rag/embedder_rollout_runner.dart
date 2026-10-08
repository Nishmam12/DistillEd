// Runs the shadow re-index step by step (docs/TECH_MIGRATION_PLAN.md, phase 4.5).
//
// The target model is downloaded; every page is embedded with it beside the
// serving chunks; once every page is current, the switch makes the target the
// serving model and removes the old one. Each step saves its state before the
// next one starts, and each step can run again, so a crash resumes where it
// stopped. Nothing here answers a question: the serving model does that throughout.

import 'dart:math' as math;

import 'embedder_rollout.dart';
import 'text_embedder.dart';

/// The target model's files: fetched, removed, and asked about.
abstract class RolloutModels {
  Future<bool> isInstalled(String modelId);
  Future<void> download(String modelId);

  /// Removes [modelId]'s files, unless [keeping] (the model that stays) uses them.
  Future<void> uninstall(String modelId, {String? keeping});
}

/// The chunks the rollout removes.
abstract class RolloutChunks {
  /// Drops every chunk built with [modelId].
  Future<void> deleteModel(String modelId);

  /// Drops every chunk built with a model that is not in [keep].
  Future<void> deleteModelsExcept(Set<String> keep);
}

/// The indexing job: embeds every page that is not current for a target.
abstract class RolloutIndex {
  /// How many indexable pages the notebooks have.
  Future<int> indexablePages();

  /// How many pages lack chunks for [target], or have stale ones.
  Future<int> pendingPages(TextEmbedder target);

  /// Brings every pending page current for [target].
  Future<void> indexPending(TextEmbedder target);
}

/// Where the rollout's state lives between launches.
abstract class RolloutStateStore {
  /// The saved rollout, or an idle one for [servingModelId] when none is saved.
  Future<EmbedderRollout> load(String servingModelId);

  Future<void> save(EmbedderRollout rollout);
}

class EmbedderRolloutRunner {
  EmbedderRolloutRunner({
    required this.states,
    required this.models,
    required this.chunks,
    required this.index,
    required this.embedderFor,
    required this.now,
  });

  final RolloutStateStore states;
  final RolloutModels models;
  final RolloutChunks chunks;
  final RolloutIndex index;

  /// The embedder for a model id. Production builds one per spec.
  final TextEmbedder Function(String modelId) embedderFor;

  final DateTime Function() now;

  /// Begins a rollout to [targetModelId]. The saved state must be idle.
  Future<void> start({
    required String servingModelId,
    required String targetModelId,
  }) async {
    final current = await states.load(servingModelId);
    final total = await index.indexablePages();
    await states.save(current.start(
      targetModelId: targetModelId,
      totalPages: total,
      now: now(),
    ));
  }

  /// The pass in progress, if one is. A second [advance] joins it, rather than
  /// running the same pages twice.
  Future<EmbedderRollout>? _advancing;

  /// Whether a pass runs in this process. A cancel during one would be overwritten
  /// by the pass's next save, so the UI offers Cancel only while this is false.
  bool get isAdvancing => _advancing != null;

  /// Runs the rollout until it is idle again, or until a step fails. A failed
  /// step leaves its state saved, so calling this again resumes the rollout.
  Future<EmbedderRollout> advance(String servingModelId) => _advancing ??=
      _advance(servingModelId).whenComplete(() => _advancing = null);

  Future<EmbedderRollout> _advance(String servingModelId) async {
    var rollout = await states.load(servingModelId);
    while (rollout.isRunning) {
      rollout = await _step(rollout);
    }
    return rollout;
  }

  /// Cancels a rollout before its switch. Its chunks and files go, and the
  /// serving model is left as it was.
  Future<EmbedderRollout> cancel(String servingModelId) async {
    final rollout = await states.load(servingModelId);
    final cancelled = rollout.cancel(); // refused during a switch
    final target = rollout.targetModelId;
    if (target != null) {
      await chunks.deleteModel(target);
      if (await models.isInstalled(target)) {
        await models.uninstall(target, keeping: rollout.servingModelId);
      }
    }
    await states.save(cancelled);
    return cancelled;
  }

  Future<EmbedderRollout> _step(EmbedderRollout rollout) async {
    switch (rollout.status) {
      case RolloutStatus.idle:
        return rollout;
      case RolloutStatus.downloading:
        final target = rollout.targetModelId!;
        if (!await models.isInstalled(target)) await models.download(target);
        return _save(rollout.downloaded());
      case RolloutStatus.indexing:
        return _indexingPass(rollout);
      case RolloutStatus.ready:
        // A page edited after its target pass is stale for the target: check
        // again, and rebuild such pages, before the switch.
        final target = embedderFor(rollout.targetModelId!);
        if (await index.pendingPages(target) > 0) {
          return _save(rollout.reopen());
        }
        return _save(rollout.beginCutover());
      case RolloutStatus.cuttingOver:
        // Idempotent: a crash part way through simply runs these again.
        final retired = rollout.servingModelId;
        await chunks.deleteModelsExcept({rollout.targetModelId!});
        if (await models.isInstalled(retired)) {
          await models.uninstall(retired, keeping: rollout.targetModelId!);
        }
        return _save(rollout.completeCutover());
    }
  }

  Future<EmbedderRollout> _indexingPass(EmbedderRollout rollout) async {
    final target = embedderFor(rollout.targetModelId!);
    final before = await index.pendingPages(target);
    await index.indexPending(target);
    final pending = await index.pendingPages(target);
    if (pending > 0 && pending == before) {
      throw StateError(
          'indexing made no progress: $pending pages still pending');
    }
    final total = math.max(await index.indexablePages(), rollout.indexedPages);
    final done = math.max(rollout.indexedPages, total - pending);
    var next = rollout.retarget(total).progress(done);
    if (pending == 0) next = next.finishIndexing();
    return _save(next);
  }

  Future<EmbedderRollout> _save(EmbedderRollout rollout) async {
    await states.save(rollout);
    return rollout;
  }
}
