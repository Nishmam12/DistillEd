// Tier 0.2: theme mode, dev mode, and the default export format must survive a
// relaunch. Before this, only the AI settings were persisted and these three
// reset on every launch.
//
// Theme mode replaced a `darkMode` bool that persisted fine but drove nothing —
// see the migration group at the bottom, which covers upgrading from it.

import 'package:flutter/material.dart' show ThemeMode;
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
    test('follow the system theme, non-dev, PNG', () async {
      final notifier = await _restored();

      expect(notifier.state.themeMode, AppThemeMode.system);
      expect(notifier.state.devMode, isFalse);
      expect(notifier.state.exportDefault, 'PNG');
    });
  });

  group('theme mode', () {
    test('is written to prefs by name, not by ordinal', () async {
      final notifier = await _restored();

      await notifier.setThemeMode(AppThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui.themeMode'), 'dark');
    });

    test('survives a relaunch', () async {
      SharedPreferences.setMockInitialValues({'ui.themeMode': 'dark'});

      expect((await _restored()).state.themeMode, AppThemeMode.dark);
    });

    test('can be set back to light', () async {
      SharedPreferences.setMockInitialValues({'ui.themeMode': 'dark'});
      final notifier = await _restored();

      await notifier.setThemeMode(AppThemeMode.light);

      expect((await _restored()).state.themeMode, AppThemeMode.light);
    });

    test('an unrecognised stored value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'ui.themeMode': 'sepia'});

      expect((await _restored()).state.themeMode, AppThemeMode.system);
    });

    test('maps onto the framework enum', () {
      expect(AppThemeMode.system.toThemeMode, ThemeMode.system);
      expect(AppThemeMode.light.toThemeMode, ThemeMode.light);
      expect(AppThemeMode.dark.toThemeMode, ThemeMode.dark);
    });
  });

  group('upgrading from the old darkMode bool', () {
    test('someone who had it on lands in dark', () async {
      SharedPreferences.setMockInitialValues({'ui.darkMode': true});

      expect((await _restored()).state.themeMode, AppThemeMode.dark);
    });

    test('someone who had it off follows the system', () async {
      SharedPreferences.setMockInitialValues({'ui.darkMode': false});

      expect((await _restored()).state.themeMode, AppThemeMode.system);
    });

    test('an explicit choice wins over the legacy key', () async {
      SharedPreferences.setMockInitialValues({
        'ui.darkMode': true,
        'ui.themeMode': 'light',
      });

      expect((await _restored()).state.themeMode, AppThemeMode.light);
    });

    test('the legacy key is never written back', () async {
      final notifier = await _restored();

      await notifier.setThemeMode(AppThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ui.darkMode'), isNull);
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
        'ui.themeMode': 'dark',
      });

      final notifier = await _restored();

      expect(notifier.state.cloudAiEnabled, isTrue);
      expect(notifier.state.themeMode, AppThemeMode.dark);
      expect(notifier.state.cloudPrivacy, CloudPrivacy.askEachTime);
    });
  });
}
