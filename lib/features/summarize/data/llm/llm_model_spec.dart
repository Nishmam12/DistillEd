// The on-device LLM used for summarization — one constant to swap models.

import 'package:flutter_gemma/flutter_gemma.dart';

/// Identity + tuning of the local model. Values mirror flutter_gemma 1.3.0's
/// official model catalog (example/lib/models/model.dart).
class LlmModelSpec {
  final String displayName;

  /// Model file name — doubles as flutter_gemma's modelId for
  /// isModelInstalled/uninstallModel.
  final String filename;

  /// Direct download URL. The litert-community HuggingFace repos are ungated
  /// (needsAuth: false in the flutter_gemma catalog) — no token required. If
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

  const LlmModelSpec({
    required this.displayName,
    required this.filename,
    required this.downloadUrl,
    required this.approxSizeBytes,
    required this.modelType,
    required this.fileType,
    required this.maxTokens,
    this.authToken,
  });

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
