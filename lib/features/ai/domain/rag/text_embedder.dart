// The contract for turning text into vectors — RAG's other half (Phase 2,
// Loop 2.2), alongside `page_chunker.dart` and `vector_math.dart`.
//
// WHY THIS IS NOT ON [AiProvider], despite `AiProvider.embed` existing:
// embeddings are MODEL-LOCKED. A vector only means anything next to vectors
// from the same model, so a corpus indexed by EmbeddingGemma can only be
// searched by EmbeddingGemma. [AiProvider] is the *routable* contract — the
// Phase 3 router picks a backend per request by cost/capability, which is
// exactly the right behaviour for generation and exactly the wrong behaviour
// here: routing one embed call to a cheaper provider would silently poison
// retrieval, with no error and no failing test. So RAG depends on this narrow
// seam and never on the router. `AiProvider.embed` stays for the platform
// contract's sake (see its doc comment) and delegates here.

/// Which side of a retrieval pair some text is being embedded for.
///
/// EmbeddingGemma — like Gecko, E5, and most cloud embedding APIs — is
/// ASYMMETRIC: it is trained with a different prefix for stored passages than
/// for search queries, and the runtime prepends that prefix for us
/// (flutter_gemma's `TaskType.prefix`: `'title: none | text: '` vs
/// `'task: search result | query: '`). Embed a document as a query and you
/// still get a 768-float vector back — just a worse one, in a subtly different
/// region of the space. Nothing throws; recall simply degrades.
///
/// That is why this is a required argument everywhere below rather than a
/// defaulted one: the failure is invisible, so the compiler should be the thing
/// that catches it.
enum EmbedTaskType {
  /// Text being stored/indexed for later retrieval (a note chunk).
  document,

  /// Text being used to search the index (a question).
  query,
}

/// Embeds text into vectors comparable with [cosineSimilarity].
///
/// Implementations must be safe to call concurrently — callers do not
/// serialize; the on-device implementation holds the model mutex itself.
abstract class TextEmbedder {
  /// Identity of the underlying model, e.g. `embeddinggemma-300m-seq512`.
  ///
  /// Stored alongside every chunk so the retriever can refuse to compare
  /// vectors produced by a DIFFERENT model (see [NoteChunk.embeddingModelId]).
  /// Changing models must invalidate the index, not silently rank nonsense.
  String get modelId;

  /// Length of the vectors this embedder produces. Lets callers reject a
  /// dimension mismatch before it reaches the math.
  int get dimensions;

  /// Embeds [texts] in one pass, returning one vector per input, in order.
  ///
  /// Batch is the primitive rather than a convenience: an on-device embedder
  /// pays a large model load per session, and indexing a page means embedding
  /// ~10 chunks. One load for ten chunks, not ten loads.
  ///
  /// Throws [AiModelNotReadyException] if the model isn't installed, or
  /// [AiGenerationException] if embedding fails. An empty [texts] returns an
  /// empty list WITHOUT loading the model.
  Future<List<List<double>>> embedAll(
    List<String> texts, {
    required EmbedTaskType taskType,
  });

  /// Convenience for the one-text case (a search query, typically).
  Future<List<double>> embedOne(
    String text, {
    required EmbedTaskType taskType,
  });
}
