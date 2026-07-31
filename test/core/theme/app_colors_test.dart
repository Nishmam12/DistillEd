// The navy/gold token layer: every hex matches design/THEME_SPEC.md, the
// three-tier hierarchy holds in both brightnesses, and `copyWith`/`lerp` reach
// all nine fields.
//
// These exist because the two failure modes here are silent. A field missing
// from `lerp` holds its old value through a whole transition and then snaps at
// the end — a flicker nobody can reproduce on demand. And `textPrimary` drifting
// onto the gold in dark is the exact "fix" the spec warns against twice: it
// compiles, it looks fine in a screenshot of one row, and it flattens the
// hierarchy across a list of thirty.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/core/theme/app_colors.dart';
import 'package:inkflow/core/theme/distill_theme.dart';

/// Every field, by name, so a test can assert on the whole set rather than a
/// hand-picked few. Adding a token to [AppColors] and not to this map makes the
/// coverage tests below fail rather than silently narrow.
Map<String, Color> _fields(AppColors c) => {
      'bgPrimary': c.bgPrimary,
      'surface': c.surface,
      'surfaceSubtle': c.surfaceSubtle,
      'accent': c.accent,
      'onAccent': c.onAccent,
      'textPrimary': c.textPrimary,
      'textSecondary': c.textSecondary,
      'border': c.border,
      'accentMuted': c.accentMuted,
    };

void main() {
  group('spec values', () {
    test('light matches THEME_SPEC.md § Design tokens → Light', () {
      const c = AppColors.light;
      expect(c.bgPrimary, const Color(0xFFF4F2EE));
      expect(c.surface, const Color(0xFFFFFFFF));
      expect(c.surfaceSubtle, const Color(0xFFF0EDE7));
      expect(c.accent, const Color(0xFF192841));
      expect(c.onAccent, const Color(0xFFFFFFFF));
      expect(c.textPrimary, const Color(0xFF192841));
      expect(c.textSecondary, const Color(0xFF6E6A64));
      expect(c.border, const Color(0xFFE6E2DA));
      expect(c.accentMuted, const Color(0x1F192841));
    });

    test('dark matches THEME_SPEC.md § Design tokens → Dark', () {
      const c = AppColors.dark;
      expect(c.bgPrimary, const Color(0xFF0D0D0F));
      expect(c.surface, const Color(0xFF1A1A1C));
      expect(c.surfaceSubtle, const Color(0xFF232326));
      expect(c.accent, const Color(0xFFDDAC5F));
      expect(c.onAccent, const Color(0xFF14140F));
      expect(c.textPrimary, const Color(0xFFE6E2DB));
      expect(c.textSecondary, const Color(0xFF8E8A84));
      expect(c.border, const Color(0xFF2A2A2D));
      expect(c.accentMuted, const Color(0x29DDAC5F));
    });

    test('accentMuted is the accent at the spec alpha, not a separate hue', () {
      // The literals above stay `const`; this proves they are still the value
      // the spec describes ("accent @ 12%" / "@ 16%") rather than a hex that
      // drifted away from `accent` when someone edited one and not the other.
      expect(AppColors.light.accentMuted,
          AppColors.light.accent.withValues(alpha: 0.12));
      expect(AppColors.dark.accentMuted,
          AppColors.dark.accent.withValues(alpha: 0.16));
    });
  });

  group('colour hierarchy', () {
    // THEME_SPEC.md § Color hierarchy. Both halves must hold; either one alone
    // is the bug the other prevents.
    test('light: accent and textPrimary are the same navy, deliberately', () {
      expect(AppColors.light.textPrimary, AppColors.light.accent);
    });

    test('dark: textPrimary is cream, NOT the gold accent', () {
      expect(AppColors.dark.textPrimary, isNot(AppColors.dark.accent));
      expect(AppColors.dark.textPrimary, const Color(0xFFE6E2DB));
    });

    test('secondary sits below primary in both modes', () {
      expect(AppColors.light.textSecondary, isNot(AppColors.light.textPrimary));
      expect(AppColors.dark.textSecondary, isNot(AppColors.dark.textPrimary));
    });
  });

  group('field coverage', () {
    test('the set is exactly nine tokens', () {
      expect(_fields(AppColors.light), hasLength(9));
    });

    test('no token was copied verbatim from light into dark', () {
      // A role identical in both brightnesses is almost always one that was
      // added to `light` and forgotten in `dark`. This palette has no genuine
      // exception — even `onAccent` differs (#FFFFFF vs #14140F).
      final light = _fields(AppColors.light);
      final dark = _fields(AppColors.dark);
      for (final name in light.keys) {
        expect(dark[name], isNot(light[name]), reason: '$name is identical in both brightnesses');
      }
    });

    test('copyWith reaches every field', () {
      // Overwrite all nine with sentinels; any field `copyWith` forgot keeps
      // its light value and fails here.
      const sentinel = Color(0xFF010203);
      final all = AppColors.light.copyWith(
        bgPrimary: sentinel,
        surface: sentinel,
        surfaceSubtle: sentinel,
        accent: sentinel,
        onAccent: sentinel,
        textPrimary: sentinel,
        textSecondary: sentinel,
        border: sentinel,
        accentMuted: sentinel,
      );
      for (final entry in _fields(all).entries) {
        expect(entry.value, sentinel, reason: 'copyWith dropped ${entry.key}');
      }
    });

    test('copyWith with no arguments preserves every field', () {
      expect(_fields(AppColors.dark.copyWith()), _fields(AppColors.dark));
    });

    test('lerp reaches every field', () {
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);
      final light = _fields(AppColors.light);
      final dark = _fields(AppColors.dark);
      for (final name in light.keys) {
        expect(_fields(mid)[name], Color.lerp(light[name], dark[name], 0.5),
            reason: 'lerp dropped $name');
      }
    });

    test('lerp endpoints are the palettes themselves', () {
      expect(_fields(AppColors.light.lerp(AppColors.dark, 0.0)),
          _fields(AppColors.light));
      expect(_fields(AppColors.light.lerp(AppColors.dark, 1.0)),
          _fields(AppColors.dark));
    });
  });

  group('DistillTheme', () {
    test('each brightness carries its own token set', () {
      expect(DistillTheme.light.extension<AppColors>(), same(AppColors.light));
      expect(DistillTheme.dark.extension<AppColors>(), same(AppColors.dark));
      expect(DistillTheme.light.brightness, Brightness.light);
      expect(DistillTheme.dark.brightness, Brightness.dark);
    });

    test('base theme follows the tokens, not a Material default', () {
      final d = DistillTheme.dark;
      expect(d.scaffoldBackgroundColor, AppColors.dark.bgPrimary);
      expect(d.colorScheme.surface, AppColors.dark.surface);
      expect(d.colorScheme.onSurface, AppColors.dark.textPrimary);
      expect(d.colorScheme.primary, AppColors.dark.accent);
      expect(d.colorScheme.onPrimary, AppColors.dark.onAccent);
      expect(d.colorScheme.outline, AppColors.dark.border);
      expect(d.dividerColor, AppColors.dark.border);
      expect(d.iconTheme.color, AppColors.dark.textPrimary);
      expect(d.appBarTheme.backgroundColor, AppColors.dark.bgPrimary);
      expect(d.cardTheme.color, AppColors.dark.surface);
    });

    test('body text is textPrimary, never accent', () {
      for (final (theme, c) in [
        (DistillTheme.light, AppColors.light),
        (DistillTheme.dark, AppColors.dark),
      ]) {
        final t = theme.textTheme;
        expect(t.bodyLarge?.color, c.textPrimary);
        expect(t.bodyMedium?.color, c.textPrimary);
        expect(t.bodySmall?.color, c.textPrimary);
        // Row titles too — the spec moves these off accent explicitly.
        expect(t.titleMedium?.color, c.textPrimary);
        expect(t.titleSmall?.color, c.textPrimary);
      }
      // In dark the two are different hexes, so this actually asserts something
      // that light mode cannot (there, textPrimary == accent by design).
      expect(DistillTheme.dark.textTheme.bodyMedium?.color,
          isNot(AppColors.dark.accent));
    });

    test('shadows do not carry into dark', () {
      // THEME_SPEC.md § asymmetries: soft shadow in light, hairline border in
      // dark. A `Card` must obey without the screen branching.
      expect(DistillTheme.light.cardTheme.elevation, greaterThan(0));
      expect(DistillTheme.dark.cardTheme.elevation, 0);
    });

    test('useMaterial3 stays on, matching the rest of the app', () {
      expect(DistillTheme.light.useMaterial3, isTrue);
      expect(DistillTheme.dark.useMaterial3, isTrue);
    });
  });

  group('context.colors', () {
    testWidgets('resolves the registered extension', (tester) async {
      late AppColors seen;
      await tester.pumpWidget(MaterialApp(
        theme: DistillTheme.dark,
        home: Builder(builder: (context) {
          seen = context.colors;
          return const SizedBox();
        }),
      ));
      expect(seen, same(AppColors.dark));
    });

    testWidgets('falls back by brightness when the extension is absent',
        (tester) async {
      // A bare MaterialApp registers no extension. The fallback must follow the
      // theme's brightness, or a half-configured dark screen gets light tokens.
      late AppColors seen;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (context) {
          seen = context.colors;
          return const SizedBox();
        }),
      ));
      expect(seen, same(AppColors.dark));
    });
  });
}
