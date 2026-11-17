// Page images leave the device without a per-call prompt, so the switch alone is
// not consent: the privacy setting must also allow it.

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';

/// Settings with a saved cloud provider, model and key, so the mode and the
/// privacy setting are what decide.
SettingsState _s(AiProcessingMode mode, CloudPrivacy privacy) => SettingsState(
      aiMode: mode,
      cloudPrivacy: privacy,
      cloudPresetId: 'openrouter',
      cloudBaseUrl: 'https://openrouter.ai/api/v1',
      cloudModel: 'test-model',
      cloudApiKey: 'sk-test',
    );

void main() {
  test('images upload only with cloud on AND privacy set to allow', () {
    for (final mode in AiProcessingMode.values) {
      for (final privacy in CloudPrivacy.values) {
        final expected = mode.allowsCloud &&
            privacy == CloudPrivacy.allowCloudForNonSensitive;
        expect(mayUploadImages(_s(mode, privacy)), expected,
            reason: '$mode / $privacy');
      }
    }
  });

  test('the default settings never upload', () {
    expect(mayUploadImages(SettingsState()), isFalse);
  });

  test('nothing goes to the cloud without a saved key', () {
    final s = SettingsState(
        aiMode: AiProcessingMode.cloudFirst,
        cloudPrivacy: CloudPrivacy.allowCloudForNonSensitive);
    expect(mayUploadImages(s), isFalse);
    expect(mayAnalyzeInCloud(s), isFalse);
  });

  test('background page analysis goes to the cloud only when pre-allowed', () {
    for (final mode in AiProcessingMode.values) {
      for (final privacy in CloudPrivacy.values) {
        expect(
            mayAnalyzeInCloud(_s(mode, privacy)),
            mode == AiProcessingMode.cloudFirst &&
                privacy == CloudPrivacy.allowCloudForNonSensitive,
            reason: '$mode / $privacy');
      }
    }
  });
}
