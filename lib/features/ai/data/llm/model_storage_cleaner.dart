// Finds and reclaims model files that are on disk but not tracked as installed.
//
// These exist because flutter_edge_ai records a model as installed only AFTER the
// downloaded file has landed (`NetworkSourceHandler` downloads, then calls
// `repository.saveModel`). A process death in that window — or a failure part
// way through the embedder's two-file install, which has no transaction around
// it — leaves a file nothing will ever look at again. `isModelInstalled` is
// metadata-only, so such a file is invisible to every other screen in the app
// while still costing up to 2.4 GB.
//
// SAFETY: the plugin's `cleanupStorage()` decides what to spare from
// `_getProtectedFiles()`, which swallows its own errors and returns a PARTIAL
// list when something inside it throws. A degraded list means installed models
// stop being protected and get deleted — silently, since cleanupStorage only
// returns a count. [EdgeAiStorageCleaner.cleanup] therefore refuses to
// run unless it has independently confirmed the plugin's view of "orphaned"
// still agrees with ours. See [_assertSafeToDelete].

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../embeddings/embedder_spec.dart';
import 'gemma_adapter.dart';
import 'llm_exceptions.dart';
import 'llm_model_spec.dart';

/// A file occupying space that no installed model claims.
class OrphanedModelFile {
  final String filename;
  final int sizeBytes;

  const OrphanedModelFile({required this.filename, required this.sizeBytes});
}

/// Whether a batch of [orphanFilenames] is safe to delete, given the app files
/// currently recorded as installed ([installedKnownFiles]).
///
/// Pure and top-level so the rule can be tested directly rather than through a
/// fake that restates it. Throws [StorageCleanupUnsafeException] when any
/// installed model appears in the orphan list — see
/// [EdgeAiStorageCleaner.cleanup] for why that combination means the
/// plugin's protected-file bookkeeping came back degraded.
///
/// One bad entry vetoes the whole batch: `cleanupStorage()` is all-or-nothing
/// from the outside, and a protected list that is wrong about one file has
/// given us no reason to trust it about the rest.
void assertSafeToDelete({
  required Iterable<String> orphanFilenames,
  required Set<String> installedKnownFiles,
}) {
  final listed = orphanFilenames.toSet();
  for (final filename in installedKnownFiles) {
    if (listed.contains(filename)) throw StorageCleanupUnsafeException();
  }
}

/// Seam over the plugin's storage APIs — see [EdgeAiStorageCleaner].
abstract class ModelStorageCleaner {
  /// Read-only. Returns an empty list when nothing is reclaimable, and also
  /// when the plugin cannot answer — it fails closed rather than guessing.
  Future<List<OrphanedModelFile>> findOrphans();

  /// Deletes the orphaned files and returns how many went.
  ///
  /// Throws [StorageCleanupUnsafeException] rather than deleting anything when
  /// the plugin's bookkeeping looks inconsistent.
  Future<int> cleanup();
}

class EdgeAiStorageCleaner implements ModelStorageCleaner {
  /// Every file this app legitimately installs. Used as a tripwire: not one of
  /// these may EVER be listed as orphaned while it is installed.
  static Set<String> get _knownModelFiles => {
        LlmModelSpec.active.filename,
        for (final spec in EmbedderSpec.registry) ...spec.files,
      };

  @override
  Future<List<OrphanedModelFile>> findOrphans() async {
    await GemmaBootstrap.ensureInitialized();
    final orphans =
        await FlutterEdgeAiPlugin.instance.modelManager.getOrphanedFiles();
    return [
      for (final o in orphans)
        OrphanedModelFile(filename: o.filename, sizeBytes: o.sizeBytes),
    ];
  }

  @override
  Future<int> cleanup() async {
    await GemmaBootstrap.ensureInitialized();

    final orphans = await findOrphans();
    // Nothing to do — and, importantly, this is also what an internal plugin
    // failure looks like (`getOrphanedFiles` catches and returns []). Treating
    // "I cannot see" the same as "there is nothing" keeps us from deleting
    // blind.
    if (orphans.isEmpty) return 0;

    // Both `getOrphanedFiles()` and `cleanupStorage()` derive their exclusions
    // from the same `_getProtectedFiles()`, so the read is a faithful preview
    // of what the write would spare. An installed model showing up as
    // "orphaned" is the exact signature of that protected list having come
    // back degraded — the one case where cleanupStorage would delete gigabytes
    // the user asked us to keep.
    assertSafeToDelete(
      orphanFilenames: orphans.map((o) => o.filename),
      installedKnownFiles: await _installedKnownFiles(),
    );

    return FlutterEdgeAiPlugin.instance.modelManager.cleanupStorage();
  }

  /// Which of this app's own model files are currently recorded as installed.
  Future<Set<String>> _installedKnownFiles() async {
    final installed = <String>{};
    for (final filename in _knownModelFiles) {
      if (await FlutterEdgeAi.isModelInstalled(filename)) {
        installed.add(filename);
      }
    }
    return installed;
  }
}
