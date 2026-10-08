// The files of the two models a rollout moves between (docs/TECH_MIGRATION_PLAN.md,
// phase 4.5). A model is looked up by its id among the specs the app knows. Removing
// a model never removes a file that the model staying in use still needs.

import '../../domain/rag/embedder_rollout_runner.dart';
import 'embedder_adapter.dart';
import 'embedder_spec.dart';

class EmbedderRolloutModels implements RolloutModels {
  EmbedderRolloutModels({
    required this.installerFor,
    required this.downloadFor,
    List<EmbedderSpec>? specs,
  }) : _specs = specs ?? EmbedderSpec.registry;

  /// The installer for a spec. Production uses [embedderInstallerFor].
  final EmbedderInstaller Function(EmbedderSpec spec) installerFor;

  /// Downloads a spec's files. Production uses the download manager.
  final Future<void> Function(EmbedderSpec spec) downloadFor;

  final List<EmbedderSpec> _specs;

  EmbedderSpec _spec(String modelId) => _specs.firstWhere(
        (spec) => spec.modelId == modelId,
        orElse: () => throw StateError('no embedder spec has the id $modelId'),
      );

  @override
  Future<bool> isInstalled(String modelId) async {
    final spec = _spec(modelId);
    return installerFor(spec).isInstalled(spec);
  }

  @override
  Future<void> download(String modelId) async => downloadFor(_spec(modelId));

  @override
  Future<void> uninstall(String modelId, {String? keeping}) async {
    final spec = _spec(modelId);
    if (keeping != null) {
      final kept = _spec(keeping).files;
      // The model that stays uses one of these files. Remove nothing: a half
      // removed model is worse than an orphan the storage cleaner can find.
      if (spec.files.any(kept.contains)) return;
    }
    await installerFor(spec).uninstall(spec);
  }
}
