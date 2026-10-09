// The on-device embedding model used for RAG — one constant to swap models,
// mirroring `llm_model_spec.dart`.
//
// NAMING: this is deliberately NOT called `EmbeddingModelSpec` — flutter_edge_ai
// already exports a type by that name (`core/model_management/model_specs.dart`),
// and the installer builds one internally from what we pass it. Two types with
// one name would force an aliased import at every call site.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_edge_ai/flutter_edge_ai.dart'
    show EmbeddingModelSpec, ModelSource;

import '../../domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import '../../domain/rag/prompt_contract.dart';

/// How a model's files reach the device, and how they run.
enum EmbedderFormat {
  /// A .tflite weights file and a sentencepiece tokenizer, run by flutter_edge_ai's
  /// TFLite embedding backend.
  tfliteWithTokenizer,

  /// A single .litertlm bundle with its tokenizer inside. Not runnable yet.
  litertlmBundle,
}

/// Identity, source, and shape of the embedding model.
class EmbedderSpec {
  final String displayName;

  /// Stable identity of the VECTOR SPACE, stored on every embedded chunk.
  ///
  /// Includes the sequence length because switching it changes results even
  /// though the weights are identical: a chunk that was truncated at seq256
  /// embeds differently once seq512 can see all of it. The same goes for what is
  /// fed in — the `-titled` suffix marks vectors built from `<notebook title>`
  /// + passage, which are not comparable with the bare-passage vectors before
  /// them. Changing this string is what invalidates an index: old chunks stop
  /// being ranked and each page is re-embedded the next time it is seen (see
  /// [TextEmbedder.modelId]).
  final String modelId;

  final String modelUrl;

  /// Null for a single-file bundle. A [EmbedderFormat.tfliteWithTokenizer] model
  /// has one; the constructor asserts it.
  final String? tokenizerUrl;

  /// How the files reach the device and how they run.
  final EmbedderFormat format;

  /// The input window this build uses for the model.
  final int maxInputTokens;

  /// Words per chunk, and the overlap between chunks, for this model.
  final int chunkWords;
  final int chunkOverlapWords;

  /// Who adds the task prefixes, and what text the model sees. Part of the
  /// vector space, so part of [modelId].
  final PromptContract promptContract;

  /// False for a spec the app knows about but cannot run yet. The UI never offers
  /// such a spec for download or rollout.
  final bool runtimeSupported;

  /// Combined download size, for the free-space check and download UI.
  final int approxSizeBytes;

  /// Length of the vectors produced. EmbeddingGemma is natively 768-dim with
  /// Matryoshka truncation to 512/256/128 available if storage ever bites.
  final int dimensions;

  /// Whether [modelUrl]/[tokenizerUrl] require a HuggingFace token. Drives the
  /// "add your token in Settings" prompt instead of an opaque 401.
  final bool needsAuth;

  /// SHA-256 of each file, checked after a fresh download. Null skips the check.
  final String? modelSha256;
  final String? tokenizerSha256;

  /// A modelId must name its [promptContract]. That is checked by
  /// embedder_spec_identity_test.dart, because a const constructor cannot call
  /// `String.contains`.
  const EmbedderSpec({
    required this.displayName,
    required this.modelId,
    required this.modelUrl,
    required this.format,
    this.tokenizerUrl,
    required this.maxInputTokens,
    required this.chunkWords,
    required this.chunkOverlapWords,
    required this.promptContract,
    required this.runtimeSupported,
    required this.approxSizeBytes,
    required this.dimensions,
    required this.needsAuth,
    this.modelSha256,
    this.tokenizerSha256,
  }) : assert(
          format != EmbedderFormat.tfliteWithTokenizer || tokenizerUrl != null,
          'a tflite model needs its tokenizer',
        );

  /// On-disk name of the model file, and flutter_edge_ai's id for it.
  ///
  /// Derived from the URL rather than stored separately because the plugin
  /// derives it the same way (`path.basename(Uri.parse(url).path)`) when it
  /// installs the file — two hand-maintained copies could disagree, and the
  /// symptom would be an "installed" model that never resolves.
  String get modelFilename => _basename(modelUrl);

  /// The tokenizer's id, which is NOT its bare filename: since flutter_gemma 1.5
  /// it is filed as `<model>__<file>` (two embedding models both ship a
  /// `sentencepiece.model`), and the plugin migrates an older install to that on
  /// start. Asked of the plugin's own spec — the one its installer records from —
  /// so it cannot drift; a hand-built `sentencepiece.model` reads "not installed"
  /// for a model that is on the disk.
  String get tokenizerFilename {
    final url = tokenizerUrl;
    if (url == null) throw StateError('$displayName has no tokenizer');
    return EmbeddingModelSpec(
      name: modelFilename,
      modelSource: ModelSource.network(modelUrl),
      tokenizerSource: ModelSource.network(url),
    ).files[1].filename;
  }

  /// Every on-disk file this spec installs. Install, uninstall, the installed
  /// check and the storage cleaner all read this list, not the two names.
  List<String> get files => [
        modelFilename,
        if (tokenizerUrl != null) tokenizerFilename,
      ];

  /// Everything that defines the vector space, as one key. Two specs with the same
  /// key must share a modelId, and two with different keys must not (see
  /// embedder_spec_identity_test.dart).
  String get identityKey => [
        maxInputTokens,
        chunkWords,
        chunkOverlapWords,
        promptContract.id,
        modelFilename,
      ].join('|');

  static String _basename(String url) => Uri.parse(url).pathSegments.last;

  /// The human-facing repo page — where a gated model's licence is accepted.
  ///
  /// Derived from [modelUrl] (host + `owner/repo`, dropping the
  /// `/resolve/<ref>/<file>` tail) for the same reason [modelFilename] is: a
  /// second hand-maintained copy of the same identity can drift, and the
  /// symptom would be sending a stuck user to the wrong page. For
  /// [embeddingGemma300m] this is
  /// `https://huggingface.co/litert-community/embeddinggemma-300m`.
  String get modelPageUrl {
    final uri = Uri.parse(modelUrl);
    final owner = uri.pathSegments.take(2); // <owner>/<repo>
    return Uri(scheme: uri.scheme, host: uri.host, pathSegments: owner)
        .toString();
  }

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
  ///   deliberately: the reference device, the Pixel 7 Pro, is a Google Tensor G2
  ///   (GS201), which matches none of them, and a per-SoC build would have to be chosen
  ///   at runtime per device. Revisit only with profiling numbers.
  static const EmbedderSpec embeddingGemma300m = EmbedderSpec(
    displayName: 'EmbeddingGemma 300M',
    modelId: 'embeddinggemma-300m-seq512-titled',
    // Pinned to a commit (not `main`) and checksums: a re-upload under the same
    // name would otherwise put different vectors under the same modelId. To
    // update, take the commit and hashes from
    // huggingface.co/api/models/<repo>?blobs=true, and change the modelId too.
    modelUrl: 'https://huggingface.co/litert-community/embeddinggemma-300m/'
        'resolve/459f1d37fec9635eb1730ebdbc219bfc3226c8e7/'
        'embeddinggemma-300M_seq512_mixed-precision.tflite',
    tokenizerUrl: 'https://huggingface.co/litert-community/embeddinggemma-300m/'
        'resolve/459f1d37fec9635eb1730ebdbc219bfc3226c8e7/sentencepiece.model',
    modelSha256:
        'ad09e81557203cb0e177abf9bf8727dfe138a7d394aa0f70f0b2ed16432e121a',
    tokenizerSha256:
        'd6daa52d93d7aad10e8388bd526c4e501d914b47177398d1d9621f1fe48438c7',
    format: EmbedderFormat.tfliteWithTokenizer,
    maxInputTokens: 512,
    // ~330 tokens at ~0.75 words per token, inside the 512 window.
    chunkWords: kChunkWords,
    chunkOverlapWords: kChunkOverlapWords,
    promptContract: PromptContract.pluginGemma300m,
    runtimeSupported: true,
    approxSizeBytes: 185 * 1024 * 1024, // 170.8 + 4.5 MB, rounded up
    dimensions: 768,
    needsAuth: true,
  );

  /// EmbeddingGemma 300M under other file names, for a rollout dry run (phase 4.5).
  /// The same weights and the same vector space: only its names differ, and so
  /// its id, and therefore its chunks.
  ///
  /// Never shipped. It is in [registry] in a debug build only, and the debug
  /// settings copy the active model's files into place for it
  /// (`installDryRunCopy`, in embedder_dry_run_copy.dart).
  static const EmbedderSpec dryRunCopy = EmbedderSpec(
    displayName: 'EmbeddingGemma 300M (dry-run copy)',
    modelId: 'embeddinggemma-300m-seq512-titled-dryrun',
    modelUrl: 'https://huggingface.co/litert-community/embeddinggemma-300m/'
        'resolve/main/embeddinggemma-300M_seq512_mixed-precision-dryrun.tflite',
    tokenizerUrl: 'https://huggingface.co/litert-community/embeddinggemma-300m/'
        'resolve/main/sentencepiece.model',
    format: EmbedderFormat.tfliteWithTokenizer,
    maxInputTokens: 512,
    chunkWords: kChunkWords,
    chunkOverlapWords: kChunkOverlapWords,
    promptContract: PromptContract.pluginGemma300m,
    runtimeSupported: true,
    approxSizeBytes: 185 * 1024 * 1024,
    dimensions: 768,
    needsAuth: false,
  );

  /// Every spec the shipped app knows about. Each one's identity is checked by
  /// embedder_spec_identity_test.dart.
  static const List<EmbedderSpec> all = [embeddingGemma300m];

  /// What this build knows: [all], plus the dry-run copy in a debug build. Looked
  /// up by id (the rollout, the serving model, the files a cleaner keeps), so a
  /// copy installed for a dry run is found there, and the shipped list never names it.
  static List<EmbedderSpec> get registry => [
        // A spec this build cannot run must never be found as a serving or
        // rollout target.
        for (final spec in all)
          if (spec.runtimeSupported) spec,
        if (kDebugMode) dryRunCopy,
      ];
}
