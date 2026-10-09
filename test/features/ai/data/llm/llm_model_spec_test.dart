import 'package:flutter_test/flutter_test.dart';

import 'package:distill_ed/features/ai/data/llm/llm_model_spec.dart';
import 'package:distill_ed/features/ai/domain/device_state.dart';

void main() {
  const base = LlmModelSpec.gemma4E2B;

  group('forProfile', () {
    test('a full device gets the model exactly as specified', () {
      expect(base.forProfile(AiProfile.full).maxTokens, base.maxTokens);
    });

    test('a lite or cloud-assisted device loads a smaller context window', () {
      // The KV cache for past tokens grows with the window, and on a phone that
      // is already short of RAM it is the part that can be traded away.
      for (final profile in [AiProfile.lite, AiProfile.cloudAssisted]) {
        final spec = base.forProfile(profile);
        expect(spec.maxTokens, lessThan(base.maxTokens));
        // 1,024 is the floor a .litertlm file's baked KV cache allows; below it
        // the plugin clamps up (or fails to allocate tensors).
        expect(spec.maxTokens, greaterThanOrEqualTo(1024));
      }
    });

    test('nothing else about the model changes — it is the same download', () {
      final lite = base.forProfile(AiProfile.lite);

      expect(lite.filename, base.filename);
      expect(lite.downloadUrl, base.downloadUrl);
      expect(lite.displayName, base.displayName);
      expect(lite.approxSizeBytes, base.approxSizeBytes);
      expect(lite.modelType, base.modelType);
      expect(lite.fileType, base.fileType);
      expect(lite.speculativeDecodingOnGpu, base.speculativeDecodingOnGpu);
      expect(lite.shareVisionEngine, base.shareVisionEngine);
    });
  });
}
