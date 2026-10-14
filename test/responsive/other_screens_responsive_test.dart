// Settings, About and Trash across the Android device matrix, in portrait and
// landscape, at normal and large system font sizes. A RenderFlex overflow or
// any layout exception fails the case.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:margo/core/theme/margo_theme.dart';
import 'package:margo/features/home/data/repositories/note_repository.dart';
import 'package:margo/features/home/domain/models/notebook.dart';
import 'package:margo/features/home/presentation/home_notifier.dart'
    show noteRepositoryProvider;
import 'package:margo/features/home/presentation/screens/trash_screen.dart';
import 'package:margo/features/settings/presentation/screens/about_screen.dart';
import 'package:margo/features/settings/presentation/screens/settings_screen.dart';

import '../support/device_matrix.dart';
import '../support/load_fonts.dart';

class _Repo implements NoteRepository {
  @override
  Future<List<Notebook>> getTrashedNotebooks() async => [
    for (var i = 1; i <= 4; i++)
      Notebook()
        ..id = i
        ..title = i == 2
            ? 'A very long trashed note title that must truncate cleanly'
            : 'Trashed $i'
        ..createdAt = DateTime(2027, 7, 9)
        ..modifiedAt = DateTime(2027, 7, 9)
        ..deletedAt = DateTime.now().subtract(Duration(days: i)),
  ];

  @override
  Future<List<Notebook>> getAllNotebooks() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _screens = <String, Widget>{
  'settings': const SettingsScreen(),
  'about': const AboutScreen(),
  'trash': const TrashScreen(),
};

void main() {
  setUpAll(loadAppFonts);

  for (final entry in _screens.entries) {
    for (final device in androidDevices) {
      for (final landscape in [false, true]) {
        for (final scale in textScales) {
          final size = landscape ? device.landscape : device.portrait;
          final label =
              '${entry.key}: $device ${landscape ? 'landscape' : 'portrait'} @${scale}x';

          testWidgets(label, (tester) async {
            SharedPreferences.setMockInitialValues({});
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
                  home: entry.value,
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
