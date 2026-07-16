// On-demand local inference: load → generate → unload.
//
// Target devices have ~8 GB RAM and the model is effective-2B, so weights are
// NEVER kept resident: every call loads the model, runs one generation, and
// releases everything in a finally block. A mutex serializes calls, which is
// what guarantees at most one LLM is in memory at any time.

import 'dart:async';

import 'gemma_adapter.dart';
import 'llm_exceptions.dart';
import 'llm_model_spec.dart';

class LocalLlmService {
  final LlmModelSpec spec;
  final LlmRuntime _runtime;

  LocalLlmService({
    this.spec = LlmModelSpec.active,
    LlmRuntime? runtime,
  }) : _runtime = runtime ?? FlutterGemmaRuntime();

  /// Mutex: chain of futures; each call awaits the previous one.
  Future<void> _lock = Future.value();

  /// Runs one generation and fully unloads the model afterwards.
  ///
  /// Defaults are tuned for faithful summarization (low temperature), not
  /// creative chat. Throws [LlmNotReadyException] when the model isn't
  /// downloaded, [LlmTimeoutException] when generation exceeds [timeout],
  /// [LlmGenerationException] on runtime failure.
  Future<String> generateOnce({
    required String prompt,
    double temperature = 0.2,
    int topK = 40,
    double topP = 0.95,
    int? maxOutputTokens = 512,
    Duration timeout = const Duration(minutes: 2),
  }) {
    final previous = _lock;
    final gate = Completer<void>();
    _lock = gate.future;

    return previous
        .then((_) => _generate(
              prompt: prompt,
              temperature: temperature,
              topK: topK,
              topP: topP,
              maxOutputTokens: maxOutputTokens,
              timeout: timeout,
            ))
        .whenComplete(gate.complete);
  }

  Future<String> _generate({
    required String prompt,
    required double temperature,
    required int topK,
    required double topP,
    required int? maxOutputTokens,
    required Duration timeout,
  }) async {
    final session = await _runtime.open(
      spec: spec,
      temperature: temperature,
      topK: topK,
      topP: topP,
      maxOutputTokens: maxOutputTokens,
    );

    try {
      final text = await session.respond(prompt).timeout(timeout);
      return text.trim();
    } on TimeoutException {
      throw LlmTimeoutException(timeout);
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmGenerationException('Local model inference failed.', e);
    } finally {
      // Unload no matter what — nothing stays resident after a call.
      await session.close();
    }
  }
}
