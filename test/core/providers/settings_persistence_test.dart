// Tier 0.2: dark mode, dev mode, and the default export format must survive a
// relaunch. Before this, only the AI settings were persisted and these three
// reset on every launch.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/providers/settings_provider.dart';

/// Builds a notifier and waits for its async `_restore()` to land.
Future<SettingsNotifier> _restored() async {
  final notifier = SettingsNotifier();
  await Future<void>.delayed(Duration.zero);
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('defaults', () {
    test('start light, non-dev, PNG', () async {
      final notifier = await _restored();

      expect(notifier.state.darkMode, isFalse);
      expect(notifier.state.devMode, isFalse);
      expect(notifier.state.exportDefault, 'PNG');
    });
  });

  group('dark mode', () {
    test('is written to prefs', () async {
      final notifier = await _restored();

      await notifier.toggleDarkMode(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ui.darkMode'), isTrue);
    });

    test('survives a relaunch', () async {
      SharedPreferences.setMockInitialValues({'ui.darkMode': true});

      final notifier = await _restored();

      expect(notifier.state.darkMode, isTrue);
    });

    test('can be turned back off', () async {
      SharedPreferences.setMockInitialValues({'ui.darkMode': true});
      final notifier = await _restored();

      await notifier.toggleDarkMode(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ui.darkMode'), isFalse);
      expect((await _restored()).state.darkMode, isFalse);
    });
  });

  group('dev mode', () {
    test('survives a relaunch', () async {
      SharedPreferences.setMockInitialValues({'ui.devMode': true});

      expect((await _restored()).state.devMode, isTrue);
    });

    test('is written to prefs', () async {
      final notifier = await _restored();

      await notifier.toggleDevMode(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ui.devMode'), isTrue);
    });
  });

  group('export default', () {
    test('survives a relaunch', () async {
      SharedPreferences.setMockInitialValues({'ui.exportDefault': 'PDF'});

      expect((await _restored()).state.exportDefault, 'PDF');
    });

    test('is written to prefs', () async {
      final notifier = await _restored();

      await notifier.setExportDefault('PDF');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui.exportDefault'), 'PDF');
    });

    test('rejects a format the picker cannot show', () async {
      final notifier = await _restored();

      await notifier.setExportDefault('TIFF');

      expect(notifier.state.exportDefault, 'PNG');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui.exportDefault'), isNull);
    });

    test('falls back to PNG when the stored value is no longer offered',
        () async {
      SharedPreferences.setMockInitialValues({'ui.exportDefault': 'SVG'});

      expect((await _restored()).state.exportDefault, 'PNG');
    });
  });

  group('AI settings still restore', () {
    test('cloud opt-in is unaffected by the new keys', () async {
      SharedPreferences.setMockInitialValues({
        'ai.cloudEnabled': true,
        'ui.darkMode': true,
      });

      final notifier = await _restored();

      expect(notifier.state.cloudAiEnabled, isTrue);
      expect(notifier.state.darkMode, isTrue);
      expect(notifier.state.cloudPrivacy, CloudPrivacy.askEachTime);
    });
  });
}
