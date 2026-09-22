// Dark mode is the one setting that has to reach every surface at once: the
// app styles itself from `AppColors` statics rather than `Theme.of(context)`,
// so these tests pin both halves of the mechanism — the palette actually
// swaps, and the running widget tree repaints when the toggle flips.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/constants/app_colors.dart';
import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/home/presentation/notes_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.install(Brightness.light);
  });

  tearDown(() => AppColors.install(Brightness.light));

  group('palette', () {
    test('tokens follow the installed brightness', () {
      final lightBackground = AppColors.background;
      final lightText = AppColors.textPrimary;

      AppColors.install(Brightness.dark);

      expect(AppColors.isDark, isTrue);
      expect(AppColors.background, isNot(lightBackground));
      expect(AppColors.textPrimary, isNot(lightText));
      // The ramp inverts: dark surfaces carry light text.
      expect(
        AppColors.textPrimary.computeLuminance(),
        greaterThan(AppColors.background.computeLuminance()),
      );
    });

    test('install reports whether the value actually changed', () {
      expect(AppColors.install(Brightness.light), isFalse);
      expect(AppColors.install(Brightness.dark), isTrue);
      expect(AppColors.install(Brightness.dark), isFalse);
    });

    test('page backgrounds stay fixed — they are persisted note data', () {
      const light = AppColors.paperCream;
      AppColors.install(Brightness.dark);
      expect(AppColors.paperCream, light);
    });
  });

  group('notes browser palette', () {
    test('follows the mode, but stays cool where AppColors goes warm', () {
      AppColors.install(Brightness.dark);

      expect(NotesPalette.background.computeLuminance(), lessThan(0.05));
      expect(
        NotesPalette.textPrimary.computeLuminance(),
        greaterThan(NotesPalette.background.computeLuminance()),
      );
      // The two skins stay distinct in dark, as they are in light.
      expect(NotesPalette.background, isNot(AppColors.background));
      // Cool: blue channel leads red. AppColors' charcoal does the reverse.
      final bg = NotesPalette.background;
      expect(bg.b, greaterThan(bg.r));
      expect(AppColors.background.r, greaterThan(AppColors.background.b));
    });

    test('the navy accent inverts so it still reads on a dark canvas', () {
      final lightAccent = NotesPalette.accent;
      AppColors.install(Brightness.dark);

      expect(
        NotesPalette.accent.computeLuminance(),
        greaterThan(lightAccent.computeLuminance()),
      );
      // Type on the accent flips with it — white would fail on the light blue.
      expect(
        NotesPalette.textOnAccent.computeLuminance(),
        lessThan(NotesPalette.accent.computeLuminance()),
      );
    });

    test('every preview tint darkens, so cards do not glow', () {
      final light = NotesPalette.previewTints;
      AppColors.install(Brightness.dark);
      final dark = NotesPalette.previewTints;

      expect(dark, hasLength(light.length));
      for (var i = 0; i < dark.length; i++) {
        expect(dark[i].computeLuminance(), lessThan(0.1),
            reason: 'tint $i is too bright for a dark card');
      }
    });
  });

  group('theme', () {
    test('light and dark are genuinely different themes', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, Brightness.dark);
      expect(dark.colorScheme.brightness, Brightness.dark);

      final light = AppTheme.warmTheme;
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor,
          isNot(dark.scaffoldBackgroundColor));
    });

    test('building a theme installs its palette', () {
      AppTheme.darkTheme;
      expect(AppColors.isDark, isTrue);
      AppTheme.warmTheme;
      expect(AppColors.isDark, isFalse);
    });
  });

  group('setting', () {
    test('defaults to light and persists a change', () async {
      final notifier = SettingsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.state.darkMode, isFalse);

      await notifier.toggleDarkMode(true);
      expect(notifier.state.darkMode, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ui.darkMode'), isTrue);
    });

    test('a stored preference is restored on launch', () async {
      SharedPreferences.setMockInitialValues({'ui.darkMode': true});
      final notifier = SettingsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.state.darkMode, isTrue);
    });
  });

  testWidgets('a live tree repaints when the palette swaps', (tester) async {
    // Stands in for the app root: a `ThemeData` swap alone would leave
    // AppColors-styled subtrees stale, so the root keys on brightness.
    Widget host(Brightness brightness) {
      AppColors.install(brightness);
      return MaterialApp(
        key: ValueKey(brightness),
        theme: AppTheme.themeFor(brightness),
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: const ColoredBox(key: Key('swatch'), color: Colors.transparent),
        ),
      );
    }

    await tester.pumpWidget(host(Brightness.light));
    final lightScaffold = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;

    await tester.pumpWidget(host(Brightness.dark));
    await tester.pumpAndSettle();
    final darkScaffold = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;

    expect(darkScaffold, isNot(lightScaffold));
    expect(darkScaffold!.computeLuminance(), lessThan(0.2));
  });

  testWidgets('a const subtree under GoRouter repaints too', (tester) async {
    // The regression this pins: on device, everything on the Notes screen
    // went dark except the one `const` widget on it (the header), which kept
    // painting light type on a dark canvas.
    //
    // `const` widgets are canonicalized, so a rebuilding parent compares the
    // new child equal to the old one and skips it, and GoRouter holds route
    // subtrees across a `Router` rebuild so re-keying the root doesn't reach
    // them either. The app root works around it by dirtying every element;
    // this test fails for any fix that doesn't.
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, __) => const _ConstScreen())],
    );
    addTearDown(router.dispose);

    Widget host(Brightness brightness) {
      AppColors.install(brightness);
      return MaterialApp.router(
        theme: AppTheme.themeFor(brightness),
        routerConfig: router,
      );
    }

    Color headerColor() =>
        tester.widget<Text>(find.text('DistillEd')).style!.color!;

    await tester.pumpWidget(host(Brightness.light));
    final light = headerColor();

    await tester.pumpWidget(host(Brightness.dark));
    // What `_InkFlowAppState._repaintEverything` does after the swap.
    void dirty(Element e) {
      e.markNeedsBuild();
      e.visitChildren(dirty);
    }

    tester.binding.rootElement!.visitChildren(dirty);
    await tester.pumpAndSettle();

    expect(headerColor(), isNot(light),
        reason: 'the const header kept its light-palette color');
    expect(headerColor().computeLuminance(), greaterThan(0.5));
  });
}

/// A screen whose header is `const` — the shape that went stale on device.
class _ConstScreen extends StatelessWidget {
  const _ConstScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotesPalette.background,
      body: const Column(children: [_ConstHeader()]),
    );
  }
}

class _ConstHeader extends StatelessWidget {
  const _ConstHeader();

  @override
  Widget build(BuildContext context) {
    return Text('DistillEd',
        style: TextStyle(color: NotesPalette.textPrimary));
  }
}
