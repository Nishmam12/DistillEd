// The files of the two models in a rollout (docs/TECH_MIGRATION_PLAN.md, phase 4.5):
// a model is removed only when the model that stays does not use its files.

import 'package:flutter_edge_ai/flutter_edge_ai.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_rollout_models.dart';
import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';

EmbedderSpec _spec(String id, {String? file}) => EmbedderSpec(
      displayName: id,
      modelId: '$id-titled',
      modelUrl: 'https://example.com/${file ?? id}.tflite',
      tokenizerUrl: 'https://example.com/${file ?? id}-tokenizer.model',
      format: EmbedderFormat.tfliteWithTokenizer,
      maxInputTokens: 512,
      chunkWords: 250,
      chunkOverlapWords: 30,
      promptContract: PromptContract.pluginGemma300m,
      runtimeSupported: true,
      approxSizeBytes: 1,
      dimensions: 3,
      needsAuth: false,
    );

class _Installer implements EmbedderInstaller {
  _Installer(this.log, {this.installed = const {}});

  final List<String> log;
  final Set<String> installed;

  @override
  Future<bool> isInstalled(EmbedderSpec spec) async =>
      installed.contains(spec.displayName);

  @override
  Future<bool> isPartiallyInstalled(EmbedderSpec spec) async => false;

  @override
  Future<void> install({
    required EmbedderSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {}

  @override
  Future<void> uninstall(EmbedderSpec spec) async =>
      log.add('uninstall ${spec.displayName}');
}

void main() {
  test('a model with its own files is removed', () async {
    final log = <String>[];
    final serving = _spec('serving');
    final target = _spec('target');
    final models = EmbedderRolloutModels(
      installerFor: (_) => _Installer(log),
      downloadFor: (_) async {},
      specs: [serving, target],
    );

    await models.uninstall('serving-titled', keeping: 'target-titled');

    expect(log, ['uninstall serving']);
  });

  test('a model whose files the staying model uses is left alone', () async {
    final log = <String>[];
    final serving = _spec('serving', file: 'shared');
    final copy = _spec('copy', file: 'shared');
    final models = EmbedderRolloutModels(
      installerFor: (_) => _Installer(log),
      downloadFor: (_) async {},
      specs: [serving, copy],
    );

    await models.uninstall('serving-titled', keeping: 'copy-titled');

    expect(log, isEmpty);
  });

  test('a model is removed when nothing is kept', () async {
    final log = <String>[];
    final models = EmbedderRolloutModels(
      installerFor: (_) => _Installer(log),
      downloadFor: (_) async {},
      specs: [_spec('serving')],
    );

    await models.uninstall('serving-titled');

    expect(log, ['uninstall serving']);
  });

  test('installed and download are asked of the model the id names', () async {
    final log = <String>[];
    final downloaded = <String>[];
    final models = EmbedderRolloutModels(
      installerFor: (_) => _Installer(log, installed: {'target'}),
      downloadFor: (spec) async => downloaded.add(spec.displayName),
      specs: [_spec('target')],
    );

    expect(await models.isInstalled('target-titled'), isTrue);
    await models.download('target-titled');

    expect(downloaded, ['target']);
  });

  test('an id no spec has is an error, not a guess', () async {
    final models = EmbedderRolloutModels(
      installerFor: (_) => _Installer([]),
      downloadFor: (_) async {},
      specs: [_spec('serving')],
    );

    await expectLater(models.isInstalled('nope'), throwsStateError);
  });
}
