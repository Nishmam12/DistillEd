// The navy/gold token layer — nine semantic roles, two brightnesses.
//
// Source of truth: `design/THEME_SPEC.md`. Every hex below is copied from that
// document's Light and Dark tables verbatim. Do not sample values from the
// mockup PNGs and do not invent new ones — if a screen needs a colour that is
// not one of these nine, the spec needs a new token, not the screen a literal.
//
// ── Why exactly nine ──────────────────────────────────────────────────────
// The app's older warm skin (`ink_palette.dart`) carries thirty-odd roles, and
// the cost of that is real: a role defined for one brightness and forgotten in
// the other is invisible until someone opens the app at night. Nine roles fit
// in your head, and `copyWith`/`lerp` below enumerate all nine explicitly so a
// forgotten field is a compile error rather than a colour that refuses to
// animate.
//
// ── The hierarchy, and the two things people "fix" ────────────────────────
// Three tiers: accent (brand, headings, active states), primary (row titles,
// content text), secondary (descriptions, meta).
//
//   * In LIGHT, `accent` and `textPrimary` are the SAME hex (#192841). This is
//     deliberate. Navy is dark enough to read as plain body text, so it carries
//     both jobs without anything looking emphasized. Do not invent a second
//     navy to make them differ.
//   * In DARK they MUST differ. Gold is saturated and warm, so every gold
//     element reads as emphasized; thirty gold row titles in a note list is a
//     wall of accent colour that signals nothing. Cream #E6E2DB carries the
//     repeated content text. Do not set `textPrimary` to the gold.
//
// `test/core/theme/app_colors_test.dart` pins both conditions.
//
// ── Reading these ─────────────────────────────────────────────────────────
//   context.colors.accent      — inside build(), follows the live theme
//
// `light` and `dark` are `const` because they are the *source* of the tokens,
// the same way `InkPalette.light` is. That is not the same thing as a widget
// capturing `AppColors.light.surface` into a `static final` — that would freeze
// a colour outside the theme and is exactly what breaks live switching. Read
// through `context.colors` at the point of use, always.

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
  });

  /// THEME_SPEC.md § Design tokens → Light.
  static const AppColors light = AppColors(
    bgPrimary: Color(0xFFF4F2EE),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF0EDE7),
    accent: Color(0xFF192841),
    onAccent: Color(0xFFFFFFFF),
    // Intentionally the same hex as `accent`. See the header.
    textPrimary: Color(0xFF192841),
    textSecondary: Color(0xFF6E6A64),
    border: Color(0xFFE6E2DA),
    // Spec: `accent @ 12%`. Written as a literal rather than
    // `accent.withValues(alpha: 0.12)` so this stays `const`; the alpha byte is
    // that expression's exact result — (0.12 * 255).round() == 31 == 0x1F.
    accentMuted: Color(0x1F192841),
  );

  /// THEME_SPEC.md § Design tokens → Dark.
  static const AppColors dark = AppColors(
    bgPrimary: Color(0xFF0D0D0F),
    surface: Color(0xFF1A1A1C),
    surfaceSubtle: Color(0xFF232326),
    accent: Color(0xFFDDAC5F),
    onAccent: Color(0xFF14140F),
    // NOT the gold. Cream carries repeated content text so gold keeps meaning
    // "emphasized". See the header.
    textPrimary: Color(0xFFE6E2DB),
    textSecondary: Color(0xFF8E8A84),
    border: Color(0xFF2A2A2D),
    // Spec: `accent @ 16%` — a wider alpha than light, because a 12% gold wash
    // on near-black is not visible. (0.16 * 255).round() == 41 == 0x29.
    accentMuted: Color(0x29DDAC5F),
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
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The nine navy/gold tokens for the current brightness.
  ///
  /// Falls back to the set matching the theme's own [Brightness] if the
  /// extension is absent, so a call site never crashes on a half-configured
  /// theme (a bare `MaterialApp` in a widget test, say) and never hands a dark
  /// screen the light tokens.
  AppColors get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light);
  }
}
