// The runtime names each embedder's own files (docs/TECH_MIGRATION_PLAN.md, phase
// 4.5). It does not go through the plugin's active model, and opening never
// installs, so loading a target model never makes it the active one.

import 'package:flutter_edge_ai/flutter_edge_ai.dart' show CancelToken, EmbeddingModel;
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:distill_ed/features/ai/data/embeddings/embedder_spec.dart';
import 'package:distill_ed/features/ai/data/llm/llm_exceptions.dart';

class _Installer implements EmbedderInstaller {
  _Installer({this.installed = true});

  final bool installed;
  int installs = 0;

  @override
  Future<bool> isInstalled(EmbedderSpec spec) async => installed;

  @override
  Future<bool> isPartiallyInstalled(EmbedderSpec spec) async => false;

  @override
  Future<void> install({
    required EmbedderSpec spec,
    String? authToken,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    installs++;
  }

  @override
  Future<void> uninstall(EmbedderSpec spec) async {}
}

class _Model implements EmbeddingModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the model and tokenizer are the files the spec names', () async {
    final loaded = <(String, String)>[];
    final runtime = EdgeAiEmbeddingRuntime(
      installer: _Installer(),
      pathOf: (name) async => '/models/$name',
      createModel: ({required modelPath, required tokenizerPath}) async {
        loaded.add((modelPath, tokenizerPath));
        return _Model();
      },
    );

    await runtime.open(EmbedderSpec.active);

    expect(loaded.single, (
      '/models/${EmbedderSpec.active.modelFilename}',
      '/models/${EmbedderSpec.active.tokenizerFilename}',
    ));
  });

  test('opening never installs, so the active model is left alone', () async {
    final installer = _Installer();
    final runtime = EdgeAiEmbeddingRuntime(
      installer: installer,
      pathOf: (name) async => '/models/$name',
      createModel: ({required modelPath, required tokenizerPath}) async =>
          _Model(),
    );

    await runtime.open(EmbedderSpec.active);

    expect(installer.installs, 0);
  });

  test('a model that is not installed is not loaded', () async {
    var loads = 0;
    final runtime = EdgeAiEmbeddingRuntime(
      installer: _Installer(installed: false),
      pathOf: (name) async => '/models/$name',
      createModel: ({required modelPath, required tokenizerPath}) async {
        loads++;
        return _Model();
      },
    );

    await expectLater(
      runtime.open(EmbedderSpec.active),
      throwsA(isA<LlmNotReadyException>()),
    );
    expect(loads, 0);
  });
}
