// The setting actually drives the theme.
//
// This is the bug these tests exist for: `darkMode` persisted correctly for a
// long time while nothing read it, so the toggle moved a stored value and
// changed no pixels. Persistence tests alone could not catch that — the gap was
// between the provider and the MaterialApp.
//
// The widget below mirrors `lib/app/app.dart`'s theme wiring exactly. The real
// InkFlowApp cannot be pumped here because its router opens Isar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/theme/ink_colors.dart';

class _ThemedApp extends ConsumerWidget {
  final void Function(InkPalette) onBuild;
  const _ThemedApp(this.onBuild);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode.toThemeMode,
      home: Builder(builder: (context) {
        onBuild(context.ink);
        return const SizedBox();
      }),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Pumps the app and returns a handle for reading the resolved palette and
  /// driving the setting.
  Future<(List<InkPalette>, ProviderContainer)> boot(
      WidgetTester tester) async {
    final seen = <InkPalette>[];
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _ThemedApp(seen.add),
    ));
    await tester.pump(); // let the async settings restore land

    return (seen, container);
  }

  testWidgets('choosing Dark repaints the app dark', (tester) async {
    final (seen, container) = await boot(tester);
    expect(seen.last, same(InkPalette.light),
        reason: 'test binding reports a light platform brightness');

    await container.read(settingsProvider.notifier).setThemeMode(
          AppThemeMode.dark,
        );
    await tester.pumpAndSettle();

    expect(seen.last, same(InkPalette.dark));
  });

  testWidgets('choosing Light pins light regardless of the device',
      (tester) async {
    final (seen, container) = await boot(tester);

    await container
        .read(settingsProvider.notifier)
        .setThemeMode(AppThemeMode.light);
    await tester.pumpAndSettle();

    expect(seen.last, same(InkPalette.light));
  });

  testWidgets('a stored preference applies on launch', (tester) async {
    SharedPreferences.setMockInitialValues({'ui.themeMode': 'dark'});

    final (seen, _) = await boot(tester);
    await tester.pumpAndSettle();

    expect(seen.last, same(InkPalette.dark));
  });

  testWidgets('upgrading from the old darkMode bool applies on launch',
      (tester) async {
    SharedPreferences.setMockInitialValues({'ui.darkMode': true});

    final (seen, _) = await boot(tester);
    await tester.pumpAndSettle();

    expect(seen.last, same(InkPalette.dark));
  });
}
