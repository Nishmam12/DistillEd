// The token layer: both brightnesses resolve, every role is defined in each,
// text stays legible, and ink/paper stay out of it.
//
// These guard the thing that made the old Dark Mode toggle inert: a colour read
// from a `static const` cannot follow the theme. Everything chrome now comes
// from an InkPalette carried on the ThemeData.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/core/constants/app_colors.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/core/theme/ink_colors.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  final argb = c.toARGB32();
  double channel(int shift) {
    final v = ((argb >> shift) & 0xFF) / 255.0;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('theme construction', () {
    test('light and dark each carry their own palette', () {
      expect(AppTheme.light().extension<InkColors>()?.palette,
          same(InkPalette.light));
      expect(AppTheme.dark().extension<InkColors>()?.palette,
          same(InkPalette.dark));
    });

    test('brightness matches the palette', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('scaffold and colour scheme follow the palette, not a default', () {
      final dark = AppTheme.dark();

      expect(dark.scaffoldBackgroundColor, InkPalette.dark.background);
      expect(dark.colorScheme.surface, InkPalette.dark.surface);
      expect(dark.colorScheme.onSurface, InkPalette.dark.textPrimary);
      expect(dark.colorScheme.primary, InkPalette.dark.accent);
    });

    test('the warm light theme is unchanged from before the token layer', () {
      // Pins that adding dark mode did not re-skin light mode.
      final light = AppTheme.light();

      expect(light.scaffoldBackgroundColor, const Color(0xFFF4ECE1));
      expect(light.colorScheme.primary, const Color(0xFFD9654E));
      expect(light.colorScheme.onSurface, const Color(0xFF33302E));
    });
  });

  group('palette completeness', () {
    // A role that is identical in both brightnesses is almost always one that
    // was added to `light` and forgotten in `dark`. The genuine exceptions are
    // listed explicitly rather than skipped wholesale.
    test('no surface or text role was copied verbatim into dark', () {
      const l = InkPalette.light;
      const d = InkPalette.dark;

      final pairs = <String, (Color, Color)>{
        'background': (l.background, d.background),
        'surface': (l.surface, d.surface),
        'surfaceWarm': (l.surfaceWarm, d.surfaceWarm),
        'surfaceAlt': (l.surfaceAlt, d.surfaceAlt),
        'surfaceHighlight': (l.surfaceHighlight, d.surfaceHighlight),
        'border': (l.border, d.border),
        'borderStrong': (l.borderStrong, d.borderStrong),
        'textPrimary': (l.textPrimary, d.textPrimary),
        'textSecondary': (l.textSecondary, d.textSecondary),
        'textMuted': (l.textMuted, d.textMuted),
        'textOnAccent': (l.textOnAccent, d.textOnAccent),
        'accent': (l.accent, d.accent),
        'accentRed': (l.accentRed, d.accentRed),
        'accentGreen': (l.accentGreen, d.accentGreen),
        'notes.background': (l.notes.background, d.notes.background),
        'notes.card': (l.notes.card, d.notes.card),
        'notes.accent': (l.notes.accent, d.notes.accent),
      };

      for (final entry in pairs.entries) {
        final (light, dark) = entry.value;
        expect(light, isNot(dark), reason: '${entry.key} is the same in both');
      }
    });

    test('every preview tint has a dark counterpart', () {
      expect(InkPalette.dark.notes.previewTints.length,
          InkPalette.light.notes.previewTints.length);
    });

    test('tintFor is stable and wraps', () {
      final notes = InkPalette.light.notes;

      expect(notes.tintFor(3), notes.tintFor(3));
      expect(notes.tintFor(0), notes.tintFor(notes.previewTints.length));
      expect(notes.tintFor(-1), isNotNull); // negative seeds must not throw
    });
  });

  group('legibility', () {
    // 4.5:1 is WCAG AA for body text. Checked on both surfaces a run of text
    // can land on.
    void expectReadable(String label, Color fg, Color bg) {
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5),
          reason: '$label is ${_contrast(fg, bg).toStringAsFixed(2)}:1');
    }

    test('light body text carries on both surfaces', () {
      const p = InkPalette.light;

      expectReadable('textPrimary on background', p.textPrimary, p.background);
      expectReadable('textPrimary on surface', p.textPrimary, p.surface);
      expectReadable(
          'textSecondary on background', p.textSecondary, p.background);
      expectReadable('textSecondary on surface', p.textSecondary, p.surface);
    });

    test('dark body text carries on both surfaces', () {
      const p = InkPalette.dark;

      expectReadable('textPrimary on background', p.textPrimary, p.background);
      expectReadable('textPrimary on surface', p.textPrimary, p.surface);
      expectReadable(
          'textSecondary on background', p.textSecondary, p.background);
      expectReadable('textSecondary on surface', p.textSecondary, p.surface);
    });

    test('the notes browser is legible in both brightnesses', () {
      for (final p in [InkPalette.light, InkPalette.dark]) {
        expectReadable('notes textPrimary', p.notes.textPrimary, p.notes.card);
        expectReadable(
            'notes textSecondary', p.notes.textSecondary, p.notes.card);
      }
    });

    test('the browser secondary grey stays at the fixed value', () {
      // The pre-token palette had #7A7A7A here, at 4.29:1 — under AA. Pinned
      // so a future palette edit cannot quietly walk it back up.
      expect(InkPalette.light.notes.textSecondary, const Color(0xFF6E6E6E));
    });

    test('the accent meets the 3:1 bar for large text and controls', () {
      // Not 4.5: the coral is used for headings, icons and button fills, not
      // body copy. The light value sits at ~3.5:1 and is inherited unchanged
      // from before the token layer; the dark value clears it comfortably.
      for (final p in [InkPalette.light, InkPalette.dark]) {
        expect(_contrast(p.accent, p.surface), greaterThanOrEqualTo(3.0));
      }
    });

    test('text on the accent fill carries', () {
      for (final p in [InkPalette.light, InkPalette.dark]) {
        expect(_contrast(p.textOnAccent, p.accent), greaterThanOrEqualTo(3.0));
      }
    });
  });

  group('ink and paper are content, not chrome', () {
    test('paper colours do not vary by brightness', () {
      // They are plain constants with no dark counterpart, deliberately: a
      // page set to Cream stays Cream with the lights off. If this ever needs
      // a `context`, the decision in app_colors.dart's header changed.
      expect(AppColors.paperWhite, const Color(0xFFFFFFFF));
      expect(AppColors.paperCream, const Color(0xFFFAF4EA));
      expect(AppColors.paperBlush, const Color(0xFFFBEFEA));
    });

    test('the ink palette is not part of the theme', () {
      final darkExt = AppTheme.dark().extension<InkColors>()!;

      for (final ink in AppColors.penPalette) {
        expect(darkExt.palette.background, isNot(ink));
      }
    });
  });

  group('lerp', () {
    test('crossfades rather than snapping', () {
      final mid = InkPalette.lerp(InkPalette.light, InkPalette.dark, 0.5);

      expect(mid.background, isNot(InkPalette.light.background));
      expect(mid.background, isNot(InkPalette.dark.background));
    });

    test('the endpoints are exact', () {
      expect(InkPalette.lerp(InkPalette.light, InkPalette.dark, 0).background,
          InkPalette.light.background);
      expect(InkPalette.lerp(InkPalette.light, InkPalette.dark, 1).background,
          InkPalette.dark.background);
    });

    test('the extension delegates to the palette', () {
      final mid = InkColors.light.lerp(InkColors.dark, 0.5);

      expect(mid.palette.background,
          InkPalette.lerp(InkPalette.light, InkPalette.dark, 0.5).background);
    });
  });

  group('context accessors', () {
    testWidgets('resolve the active brightness', (tester) async {
      late InkPalette seen;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Builder(builder: (context) {
          seen = context.ink;
          return const SizedBox();
        }),
      ));

      expect(seen, same(InkPalette.dark));
    });

    testWidgets('follow a theme change without a restart', (tester) async {
      late InkPalette seen;

      Widget app(ThemeMode mode) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: Builder(builder: (context) {
              seen = context.ink;
              return const SizedBox();
            }),
          );

      await tester.pumpWidget(app(ThemeMode.light));
      expect(seen, same(InkPalette.light));

      await tester.pumpWidget(app(ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(seen, same(InkPalette.dark));
    });

    testWidgets('context.notes reaches the browser group', (tester) async {
      late NotesInk seen;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(builder: (context) {
          seen = context.notes;
          return const SizedBox();
        }),
      ));

      expect(seen.card, InkPalette.dark.notes.card);
    });

    testWidgets('fall back to light when no extension is installed',
        (tester) async {
      // A bare MaterialApp — as used by many widget tests — must not crash.
      late InkPalette seen;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          seen = context.ink;
          return const SizedBox();
        }),
      ));

      expect(seen, same(InkPalette.light));
    });
  });
}
