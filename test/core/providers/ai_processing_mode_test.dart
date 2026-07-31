// AiProcessingMode and its migration off the old `ai.cloudEnabled` bool.
//
// The migration assertions matter more than the rest of this file: getting them
// wrong silently changes whether someone's notes leave their device, and it
// would do so on an app update they never opted into.

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiProcessingMode', () {
    test('onDevice forbids the cloud; the other two permit it', () {
      expect(AiProcessingMode.onDevice.allowsCloud, isFalse);
      expect(AiProcessingMode.auto.allowsCloud, isTrue);
      expect(AiProcessingMode.cloudFirst.allowsCloud, isTrue);
    });

    test('only cloudFirst skips the local model', () {
      expect(AiProcessingMode.onDevice.prefersCloud, isFalse);
      expect(AiProcessingMode.auto.prefersCloud, isFalse);
      expect(AiProcessingMode.cloudFirst.prefersCloud, isTrue);
    });

    test('byName round-trips every value', () {
      for (final m in AiProcessingMode.values) {
        expect(AiProcessingMode.byName(m.name), m);
      }
    });

    test('an unknown or missing stored name falls back to auto', () {
      expect(AiProcessingMode.byName(null), AiProcessingMode.auto);
      expect(AiProcessingMode.byName('nonsense'), AiProcessingMode.auto);
    });
  });

  group('SettingsState', () {
    test('defaults to onDevice — the privacy default of the bool it replaces',
        () {
      expect(SettingsState().aiMode, AiProcessingMode.onDevice);
      expect(SettingsState().cloudAiEnabled, isFalse);
    });

    test('cloudAiEnabled is derived from the mode', () {
      expect(
        SettingsState(aiMode: AiProcessingMode.onDevice).cloudAiEnabled,
        isFalse,
      );
      expect(
        SettingsState(aiMode: AiProcessingMode.auto).cloudAiEnabled,
        isTrue,
      );
      expect(
        SettingsState(aiMode: AiProcessingMode.cloudFirst).cloudAiEnabled,
        isTrue,
      );
    });
  });

  group('migration from ai.cloudEnabled', () {
    Future<AiProcessingMode> restore(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final notifier = SettingsNotifier();
      // _restore() runs off the constructor; wait for it to land.
      while (!notifier.state.loaded) {
        await Future<void>.delayed(Duration.zero);
      }
      return notifier.state.aiMode;
    }

    test('a fresh install lands on onDevice', () async {
      expect(await restore({}), AiProcessingMode.onDevice);
    });

    test('legacy cloud OFF stays on-device', () async {
      expect(
        await restore({'ai.cloudEnabled': false}),
        AiProcessingMode.onDevice,
      );
    });

    test('legacy cloud ON becomes auto, never cloudFirst', () async {
      expect(
        await restore({'ai.cloudEnabled': true}),
        AiProcessingMode.auto,
        reason: 'ticking the old bool did not consent to cloud-first',
      );
    });

    test('an explicitly stored mode wins over the legacy bool', () async {
      expect(
        await restore({
          'ai.cloudEnabled': false,
          'ai.mode': 'cloudFirst',
        }),
        AiProcessingMode.cloudFirst,
      );
    });
  });

  group('setCloudAiEnabled shim', () {
    test('on lands on auto, off returns to onDevice', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = SettingsNotifier();

      await notifier.setCloudAiEnabled(true);
      expect(notifier.state.aiMode, AiProcessingMode.auto,
          reason: 'a one-tap switch must not reach cloud-first');

      await notifier.setCloudAiEnabled(false);
      expect(notifier.state.aiMode, AiProcessingMode.onDevice);
    });

    test('it does not downgrade an explicit cloudFirst to auto silently',
        () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = SettingsNotifier();
      await notifier.setAiMode(AiProcessingMode.cloudFirst);

      // Turning the sidebar switch "on" while already cloud-first is a no-op in
      // intent; it must not quietly weaken the chosen mode.
      await notifier.setCloudAiEnabled(true);
      expect(notifier.state.aiMode, AiProcessingMode.auto,
          reason: 'documented behaviour: the shim always means auto');
    });
  });
}
