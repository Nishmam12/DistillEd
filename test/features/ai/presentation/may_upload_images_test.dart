// Page images leave the device without a per-call prompt, so the switch alone is
// not consent: the privacy setting must also allow it.

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';

SettingsState _s(AiProcessingMode mode, CloudPrivacy privacy) =>
    SettingsState(aiMode: mode, cloudPrivacy: privacy);

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
}
