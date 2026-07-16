// The single contract every AI backend implements.
//
// Phase 0 has one implementation (on-device Gemma). Phases 2–3 add cloud Gemma
// and optional frontier providers (Gemini/Claude/GPT) behind this same
// interface, and the Phase 3 intelligent router dispatches across a list of
// them using [AiCapabilities]. Designed so adding a provider never requires
// changing this file: implement [AiProvider], expose your [capabilities], done.

import 'ai_capabilities.dart';
import 'ai_generation_options.dart';
import 'ai_message.dart';

// Re-export the value types so callers only need `import 'ai_provider.dart'`.
export 'ai_capabilities.dart';
export 'ai_exception.dart';
export 'ai_generation_options.dart';
export 'ai_message.dart';

/// Provider-agnostic AI backend.
///
/// Streaming is the default shape for [generate] because the product requires
/// live token output everywhere; a non-streaming backend simply yields a single
/// chunk. Failures are reported as `AiException` subtypes (see
/// `ai_exception.dart`) — thrown for setup errors, or emitted as a stream error
/// for mid-generation failures.
abstract class AiProvider {
  /// Streams the model's reply incrementally.
  ///
  /// - [prompt] is the immediate user input.
  /// - [systemPrompt] sets behaviour/instructions for this call.
  /// - [history] is prior turns for multi-turn context (oldest first). Callers
  ///   are responsible for keeping it within [capabilities] `contextWindowTokens`.
  /// - [options] tunes sampling; null uses provider defaults.
  ///
  /// Emitted chunks are meant to be concatenated in order to form the full
  /// reply. May throw [AiModelNotReadyException] / [AiUnavailableException]
  /// before yielding, or emit an [AiGenerationException] as a stream error.
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  });

  /// Returns an embedding vector for [text], for Phase 2 RAG semantic search.
  ///
  /// Providers without embedding support must throw
  /// [AiUnsupportedOperationException] (and report `supportsEmbeddings: false`
  /// in [capabilities]) rather than returning a placeholder.
  Future<List<double>> embed(String text);

  /// Static description of this provider's identity and limits, used by the
  /// router to choose a backend. Should be a cheap `const`.
  AiCapabilities get capabilities;
}
