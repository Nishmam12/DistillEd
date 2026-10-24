// The embedding runtime (docs/TECH_MIGRATION_PLAN.md, phase 5). Since
// flutter_edge_ai 2.3.0 the plugin loads only its active embedder, so opening
// makes the spec active first — without a download — and then loads it. The
// session picks the plugin's prefix, or none for an app-owned prompt, and trims
// an input that is over the model's window instead of failing the batch.

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:margo/features/ai/data/embeddings/embedder_spec.dart';
import 'package:margo/features/ai/data/llm/llm_exceptions.dart';
import 'package:margo/features/ai/domain/rag/text_embedder.dart';

class _Installer implements EmbedderInstaller {
  _Installer({this.installed = true, this.log});

  final bool installed;
  final List<String>? log;
  final installs = <(EmbedderSpec, String?)>[];

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
    log?.add('activate');
    installs.add((spec, authToken));
  }

  @override
  Future<void> uninstall(EmbedderSpec spec) async {}
}

/// Answers a vector per input, and refuses any text longer than [maxChars].
final class _Model extends EmbeddingModel {
  _Model({this.maxChars = 1 << 30});

  final int maxChars;
  final embedded = <String>[];
  final taskTypes = <TaskType>[];

  @override
  int get dimension => 768;

  @override
  bool get isClosed => false;

  @override
  Future<List<double>> embed(
    EmbeddingInput input, {
    required TaskType taskType,
  }) async {
    final text = input.text!;
    if (text.length > maxChars) {
      throw EmbeddingInputTooLongException(
        'too long',
        maxInputTokens: maxChars,
        actualTokens: text.length,
      );
    }
    embedded.add(text);
    taskTypes.add(taskType);
    return List.filled(768, 0.0);
  }

  @override
  void addCloseListener(void Function() listener) {}

  @override
  Future<void> close() async {}
}

void main() {
  test('both formats run on the flutter_edge_ai runtime', () {
    for (final spec in EmbedderSpec.all) {
      expect(
        embeddingRuntimeFor(spec),
        isA<EdgeAiEmbeddingRuntime>(),
        reason: spec.displayName,
      );
    }
  });

  test(
    'opening makes the spec active, with no token, before loading it',
    () async {
      final log = <String>[];
      final installer = _Installer(log: log);
      final runtime = EdgeAiEmbeddingRuntime(
        installer: installer,
        loadActive: () async {
          log.add('load');
          return _Model();
        },
      );

      await runtime.open(EmbedderSpec.active);

      expect(log, ['activate', 'load']);
      expect(installer.installs.single, (EmbedderSpec.active, null));
    },
  );

  test(
    'a model that is not installed is neither installed nor loaded',
    () async {
      final installer = _Installer(installed: false);
      var loads = 0;
      final runtime = EdgeAiEmbeddingRuntime(
        installer: installer,
        loadActive: () async {
          loads++;
          return _Model();
        },
      );

      await expectLater(
        runtime.open(EmbedderSpec.active),
        throwsA(isA<LlmNotReadyException>()),
      );
      expect(installer.installs, isEmpty);
      expect(loads, 0);
    },
  );

  test('no active embedder in the plugin reads as not ready', () async {
    final runtime = EdgeAiEmbeddingRuntime(
      installer: _Installer(),
      loadActive: () async => throw StateError('no active embedding model'),
    );

    await expectLater(
      runtime.open(EmbedderSpec.active),
      throwsA(isA<LlmNotReadyException>()),
    );
  });

  Future<(_Model, EmbeddingSession)> open(
    EmbedderSpec spec, {
    int? maxChars,
  }) async {
    final model = maxChars == null ? _Model() : _Model(maxChars: maxChars);
    final session = await EdgeAiEmbeddingRuntime(
      installer: _Installer(),
      loadActive: () async => model,
    ).open(spec);
    return (model, session);
  }

  test(
    'a plugin-owned prompt asks the plugin for the retrieval prefixes',
    () async {
      final (model, session) = await open(EmbedderSpec.embeddingGemma300m);

      await session.embedAll(['a'], taskType: EmbedTaskType.document);
      await session.embedAll(['b'], taskType: EmbedTaskType.query);

      expect(model.taskTypes, [
        TaskType.retrievalDocument,
        TaskType.retrievalQuery,
      ]);
    },
  );

  test('an app-owned prompt asks the plugin for no prefix', () async {
    final (model, session) = await open(EmbedderSpec.embeddingGemma2Text);

    await session.embedAll(['a'], taskType: EmbedTaskType.document);
    await session.embedAll(['b'], taskType: EmbedTaskType.query);

    expect(model.taskTypes, [TaskType.none, TaskType.none]);
  });

  test(
    'an over-long input is trimmed from the end; the others are kept whole',
    () async {
      final (model, session) = await open(
        EmbedderSpec.embeddingGemma2Text,
        maxChars: 100,
      );
      final long = 'title: none | text: ${'x' * 200}';

      final vectors = await session.embedAll([
        'short',
        long,
      ], taskType: EmbedTaskType.document);

      expect(vectors, hasLength(2));
      expect(model.embedded.first, 'short');
      expect(model.embedded.last, startsWith('title: none | text: '));
      expect(model.embedded.last.length, lessThanOrEqualTo(100));
    },
  );
}
