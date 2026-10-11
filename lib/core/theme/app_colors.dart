// The sage token layer — eleven semantic roles, two brightnesses.
//
// Source of truth: `design/THEME_SPEC.md`. Every hex below is copied from that
// document's Light and Dark tables verbatim (sage palette, from the margo
// Figma file; dark derived from it). Do not sample values from the
// mockup PNGs and do not invent new ones — if a screen needs a colour that is
// not one of these eleven, the spec needs a new token, not the screen a literal.
//
// ── Why exactly nine ──────────────────────────────────────────────────────
// The warm skin this replaced carried thirty-odd roles, and the cost of that was
// real: a role defined for one brightness and forgotten in the other is
// invisible until someone opens the app at night. Eleven roles fit
// in your head, and `copyWith`/`lerp` below enumerate all eleven explicitly so a
// forgotten field is a compile error rather than a colour that refuses to
// animate.
//
// ── The hierarchy, and the two things people "fix" ────────────────────────
// Three tiers: accent (brand, headings, active states), primary (row titles,
// content text), secondary (descriptions, meta).
//
//   * In BOTH brightnesses `accent` and `textPrimary` differ. Light: sage
//     #4F6B5A accents over near-black #171D1B content text. Dark: light sage
//     #9CC5AB accents over warm cream #E8E4DA content text. Thirty accent-
//     coloured row titles in a note list would be a wall of colour that
//     signals nothing, so repeated content text never takes the accent.
//
// `test/core/theme/app_colors_test.dart` pins the condition and the contrast.
//
// ── Reading these ─────────────────────────────────────────────────────────
//   context.colors.accent      — inside build(), follows the live theme
//
// `light` and `dark` are `const` because they are the *source* of the tokens.
// That is not the same thing as a widget capturing `AppColors.light.surface`
// into a `static final` — that would freeze a colour outside the theme and is
// exactly what breaks live switching. Read through `context.colors` at the
// point of use, always.

import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Scaffold background.
  final Color bgPrimary;

  /// Cards, settings rows.
  final Color surface;

  /// Icon tiles, search field fill, toolbar strip.
  final Color surfaceSubtle;

  /// Brand, headings, active/selected states, filled buttons.
  final Color accent;

  /// Glyph/text on a filled accent surface.
  final Color onAccent;

  /// Row titles, note titles, content text.
  ///
  /// Equal to [accent] in light and deliberately different in dark — see the
  /// hierarchy note in this file's header before changing either.
  final Color textPrimary;

  /// Descriptions, placeholders, meta text.
  final Color textSecondary;

  /// Card outlines, chip outlines, hairlines.
  final Color border;

  /// Active-tool halo, selected segment fill. [accent] at low alpha.
  final Color accentMuted;

  /// The wordmark. Darker than [accent] in light, lighter in dark.
  final Color brand;

  /// Text-field pill fill (note title, search field).
  final Color fieldFill;

  const AppColors({
    required this.bgPrimary,
    required this.surface,
    required this.surfaceSubtle,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accentMuted,
    required this.brand,
    required this.fieldFill,
  });

  /// THEME_SPEC.md § Design tokens → Light.
  static const AppColors light = AppColors(
    bgPrimary: Color(0xFFF6F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFC9D6C3),
    accent: Color(0xFF4F6B5A),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF171D1B),
    textSecondary: Color(0xFF4A574F),
    border: Color(0xFFD5DCCF),
    // Spec: `accent @ 12%`; (0.12 * 255).round() == 31 == 0x1F.
    accentMuted: Color(0x1F4F6B5A),
    brand: Color(0xFF385343),
    fieldFill: Color(0xFF8ABD9E),
  );

  /// THEME_SPEC.md § Design tokens → Dark.
  static const AppColors dark = AppColors(
    bgPrimary: Color(0xFF121614),
    surface: Color(0xFF1A201D),
    surfaceSubtle: Color(0xFF222B26),
    accent: Color(0xFF9CC5AB),
    onAccent: Color(0xFF0F1A14),
    textPrimary: Color(0xFFE8E4DA),
    textSecondary: Color(0xFF9AA59E),
    border: Color(0xFF2C3631),
    // Spec: `accent @ 16%`; (0.16 * 255).round() == 41 == 0x29.
    accentMuted: Color(0x299CC5AB),
    brand: Color(0xFFB3D3BE),
    fieldFill: Color(0xFF2E4638),
  );

  @override
  AppColors copyWith({
    Color? bgPrimary,
    Color? surface,
    Color? surfaceSubtle,
    Color? accent,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? accentMuted,
    Color? brand,
    Color? fieldFill,
  }) {
    return AppColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      accentMuted: accentMuted ?? this.accentMuted,
      brand: brand ?? this.brand,
      fieldFill: fieldFill ?? this.fieldFill,
    );
  }

  /// Blends two token sets so a theme switch crossfades instead of snapping.
  ///
  /// Every field is listed. A field omitted here would hold its `this` value
  /// for the whole transition and then jump at the end — the kind of bug that
  /// only shows up as a flicker on a real device.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bgPrimary: c(bgPrimary, other.bgPrimary),
      surface: c(surface, other.surface),
      surfaceSubtle: c(surfaceSubtle, other.surfaceSubtle),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      border: c(border, other.border),
      accentMuted: c(accentMuted, other.accentMuted),
      brand: c(brand, other.brand),
      fieldFill: c(fieldFill, other.fieldFill),
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The eleven sage tokens for the current brightness.
  ///
  /// Falls back to the set matching the theme's own [Brightness] if the
  /// extension is absent, so a call site never crashes on a half-configured
  /// theme (a bare `MaterialApp` in a widget test, say) and never hands a dark
  /// screen the light tokens.
  AppColors get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
  }

  /// The lift under a floating surface such as a popover, tinted with the
  /// accent. Light only: THEME_SPEC.md replaces shadow with a hairline border in
  /// dark, and the caller draws that border itself.
  List<BoxShadow> get floatShadow {
    if (Theme.of(this).brightness == Brightness.dark) return const [];
    final accent = colors.accent;
    return [
      BoxShadow(
        color: accent.withValues(alpha: 0.12),
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: accent.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
