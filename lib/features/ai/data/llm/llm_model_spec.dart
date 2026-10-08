// The on-device LLM used for summarization — one constant to swap models.

import 'dart:math' as math;

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../../domain/device_state.dart';

/// Identity + tuning of the local model. Values mirror flutter_gemma 1.3.0's
/// official model catalog (example/lib/models/model.dart).
class LlmModelSpec {
  final String displayName;

  /// Model file name — doubles as flutter_edge_ai's modelId for
  /// isModelInstalled/uninstallModel.
  final String filename;

  /// Direct download URL. The litert-community HuggingFace repos are ungated
  /// (needsAuth: false in the flutter_edge_ai catalog) — no token required. If
  /// the model is ever swapped to a gated repo, pass a token via
  /// [authToken] instead of hardcoding one.
  final String downloadUrl;
  final String? authToken;

  /// Approximate download size — drives the free-space check and download UI.
  final int approxSizeBytes;

  final ModelType modelType;
  final ModelFileType fileType;

  /// Context window (input + output tokens) to load the model with.
  final int maxTokens;

  /// Disk the engine needs for its own load cache on top of the download.
  ///
  /// LiteRT-LM keeps an XNNPACK weight cache in the app support directory — a
  /// few hundred MB — so a device with room for the file alone can still fill
  /// up on first load. An ESTIMATE ("hundreds of MB"), to be replaced by a
  /// measurement from the target device. The cache is keyed to the model file's
  /// modification time and size, so nothing may touch the file after download.
  final int approxLoadCacheBytes;

  /// Enable multi-token prediction when the model runs on the GPU.
  ///
  /// Google reports ~1.6x faster decoding for Gemma 4 E2B, but it needs the MTP
  /// drafter inside the `.litertlm` file (an older file ignores the flag) and
  /// the drafter costs memory — so peak memory should be measured with it on
  /// and off before keeping it. Never enabled on the CPU, where running the
  /// drafter is overhead; see `EdgeAiRuntime.open`.
  final bool speculativeDecodingOnGpu;

  /// Load the vision encoder for EVERY call, text ones included, so text and
  /// image calls share one resident engine instead of rebuilding it each time
  /// they alternate (a deep page read does exactly that: image reads, then a
  /// text analysis). The price is the encoder's memory while the model is
  /// resident — measure it on the target device; set false to go back to
  /// text-only sessions loading without it.
  final bool shareVisionEngine;

  /// The precision of the text decoder's activations on the GPU, or null to let
  /// the model file decide (LiteRT-LM's own choice is float16).
  ///
  /// Set [ActivationDataType.float32] if a device's GPU writes wrong digits — a
  /// maths tutor cannot shrug that off. It costs more GPU memory, so it is off
  /// until a device shows the problem; measure the memory before turning it on
  /// for everyone. Not sent when the model runs on the CPU, which is already full
  /// precision.
  final ActivationDataType? activationDataType;

  const LlmModelSpec({
    required this.displayName,
    required this.filename,
    required this.downloadUrl,
    required this.approxSizeBytes,
    required this.modelType,
    required this.fileType,
    required this.maxTokens,
    this.authToken,
    this.approxLoadCacheBytes = 512 * 1024 * 1024,
    this.speculativeDecodingOnGpu = true,
    this.shareVisionEngine = true,
    this.activationDataType,
  });

  /// The context window a device short on RAM loads instead of [maxTokens].
  ///
  /// The memory for past tokens grows with the window, and it is the part of a
  /// model's footprint that can be traded away without a different download.
  /// 2,048 stays above the 1,024 a `.litertlm` file's baked KV cache requires;
  /// every feature re-budgets from the provider's window automatically.
  static const int liteMaxTokens = 2048;

  /// This model as it should be loaded on a device of class [profile]: the same
  /// file, with a smaller window on anything but [AiProfile.full].
  LlmModelSpec forProfile(AiProfile profile) {
    if (profile == AiProfile.full) return this;
    return LlmModelSpec(
      displayName: displayName,
      filename: filename,
      downloadUrl: downloadUrl,
      authToken: authToken,
      approxSizeBytes: approxSizeBytes,
      approxLoadCacheBytes: approxLoadCacheBytes,
      modelType: modelType,
      fileType: fileType,
      maxTokens: math.min(maxTokens, liteMaxTokens),
      speculativeDecodingOnGpu: speculativeDecodingOnGpu,
      shareVisionEngine: shareVisionEngine,
      activationDataType: activationDataType,
    );
  }

  /// The model the app uses. Swap here (e.g. to a Gemma 3 1B for a smaller
  /// download) — everything else adapts.
  static const LlmModelSpec active = gemma4E2B;

  /// Gemma 4 E2B instruction-tuned, LiteRT-LM build (~2.4 GB download,
  /// effective-2B MatFormer — fits the 8 GB RAM device target with the
  /// load→generate→unload lifecycle).
  static const LlmModelSpec gemma4E2B = LlmModelSpec(
    displayName: 'Gemma 4 E2B',
    filename: 'gemma-4-E2B-it.litertlm',
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    approxSizeBytes: 2600 * 1024 * 1024, // ~2.4 GiB catalog size, rounded up
    modelType: ModelType.gemma4,
    fileType: ModelFileType.litertlm,
    maxTokens: 4096,
  );
}
