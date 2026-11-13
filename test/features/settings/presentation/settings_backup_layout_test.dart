// The Backup card with automatic backup on shows the "How often" chips as well.
// They must wrap, not overflow, on the narrowest phones at large text sizes. The
// shared responsive test runs with defaults (backup off) and cannot see this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/theme/margo_theme.dart';
import 'package:margo/features/home/data/repositories/note_repository.dart';
import 'package:margo/features/home/presentation/home_notifier.dart'
    show noteRepositoryProvider;
import 'package:margo/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/load_fonts.dart';

class _Repo implements NoteRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(loadAppFonts);

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(346, 832), 2.0),
    (const Size(412, 915), 1.0),
  ]) {
    testWidgets('backup on: no overflow at ${size.width.toInt()}px @${scale}x', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'backup.auto': true});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [noteRepositoryProvider.overrideWithValue(_Repo())],
          child: MaterialApp(
            theme: MargoTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('backupFrequency')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
