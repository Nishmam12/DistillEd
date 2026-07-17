// The on-device embedding model used for RAG — one constant to swap models,
// mirroring `llm_model_spec.dart`.
//
// NAMING: this is deliberately NOT called `EmbeddingModelSpec` — flutter_gemma
// already exports a type by that name (`core/model_management/model_specs.dart`),
// and the installer builds one internally from what we pass it. Two types with
// one name would force an aliased import at every call site.

/// Identity, source, and shape of the embedding model.
class EmbedderSpec {
  final String displayName;

  /// Stable identity of the VECTOR SPACE, stored on every embedded chunk.
  ///
  /// Includes the sequence length because switching it changes results even
  /// though the weights are identical: a chunk that was truncated at seq256
  /// embeds differently once seq512 can see all of it. Changing this string is
  /// what invalidates an index (see [TextEmbedder.modelId]).
  final String modelId;

  final String modelUrl;
  final String tokenizerUrl;

  /// Combined download size, for the free-space check and download UI.
  final int approxSizeBytes;

  /// Length of the vectors produced. EmbeddingGemma is natively 768-dim with
  /// Matryoshka truncation to 512/256/128 available if storage ever bites.
  final int dimensions;

  /// Whether [modelUrl]/[tokenizerUrl] require a HuggingFace token. Drives the
  /// "add your token in Settings" prompt instead of an opaque 401.
  final bool needsAuth;

  const EmbedderSpec({
    required this.displayName,
    required this.modelId,
    required this.modelUrl,
    required this.tokenizerUrl,
    required this.approxSizeBytes,
    required this.dimensions,
    required this.needsAuth,
  });

  /// On-disk name of the model file, and flutter_gemma's id for it.
  ///
  /// Derived from the URL rather than stored separately because the plugin
  /// derives it the same way (`path.basename(Uri.parse(url).path)`) when it
  /// installs the file — two hand-maintained copies could disagree, and the
  /// symptom would be an "installed" model that never resolves.
  String get modelFilename => _basename(modelUrl);

  String get tokenizerFilename => _basename(tokenizerUrl);

  static String _basename(String url) => Uri.parse(url).pathSegments.last;

  /// The model the app embeds with. Swap here — chunks record [modelId], so a
  /// change invalidates the old index rather than corrupting search.
  static const EmbedderSpec active = embeddingGemma300m;

  /// EmbeddingGemma 300M, LiteRT build (~171 MB model + ~4.5 MB tokenizer).
  ///
  /// Verified against the HuggingFace API on 2026-07-17:
  ///
  /// • The repo is `gated: auto` — a licence click, no manual approval — and
  ///   returns 401 without a token. This is the whole reason the per-user
  ///   HuggingFace token setting exists.
  ///
  /// • seq512 over seq256: both weigh the same 170.8 MB (sequence length
  ///   changes the graph shape, not the weights), but a fixed-shape TFLite
  ///   graph pads every input to its full length — so seq1024/seq2048 would
  ///   cost 2–4x the compute per chunk for nothing. seq512 is free headroom
  ///   over seq256 and comfortably fits [kChunkWords] (~330 tokens).
  ///
  /// • The repo also ships per-SoC builds (qualcomm.sm8550/8650/8750/8850,
  ///   mediatek.mt6991/6993, google.tensor_g5). The generic build is used
  ///   deliberately: the target Xiaomi Pad 7 is a Snapdragon 7+ Gen 3 (SM7675),
  ///   which matches none of them, and a per-SoC build would have to be chosen
  ///   at runtime per device. Revisit only with profiling numbers.
  static const EmbedderSpec embeddingGemma300m = EmbedderSpec(
    displayName: 'EmbeddingGemma 300M',
    modelId: 'embeddinggemma-300m-seq512',
    modelUrl: 'https://huggingface.co/litert-community/embeddinggemma-300m/'
        'resolve/main/embeddinggemma-300M_seq512_mixed-precision.tflite',
    tokenizerUrl: 'https://huggingface.co/litert-community/embeddinggemma-300m/'
        'resolve/main/sentencepiece.model',
    approxSizeBytes: 185 * 1024 * 1024, // 170.8 + 4.5 MB, rounded up
    dimensions: 768,
    needsAuth: true,
  );
}
