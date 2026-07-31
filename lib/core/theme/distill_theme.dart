// The navy/gold ThemeData pair, built entirely from the nine [AppColors]
// tokens. One builder, two brightnesses — a role can never be defined for one
// and forgotten in the other.
//
// ── Not yet wired ─────────────────────────────────────────────────────────
// `MaterialApp` in `app/app.dart` still points at [AppTheme] (the warm coral
// skin). This file is complete and unit-tested but deliberately unreferenced by
// the running app, because flipping it on today would re-skin all thirty-two
// screens to navy/gold while ~53 hardcoded colours and 428 `context.ink` reads
// stayed coral — a visibly mixed app for the duration of the screen migration.
// `app/app.dart` switches over at the start of the settings-screen pass, once
// there is a migrated screen to look at.
//
// ── Why the base theme is derived at all ──────────────────────────────────
// Every widget that has not been migrated to `context.colors` yet still reads
// `ThemeData` somewhere — a `Card`, a `Divider`, an unstyled `Text`. Deriving
// `colorScheme`, `scaffoldBackgroundColor`, `cardTheme`, `dividerColor`,
// `iconTheme`, `textTheme` and `appBarTheme` from the same nine tokens means
// those widgets degrade to the right brightness instead of sitting light on a
// near-black scaffold.
//
// For the same reason this registers BOTH theme extensions: [AppColors] for
// migrated code, and [InkColors] carrying the matching-brightness [InkPalette]
// so the 428 surviving `context.ink` call sites at least follow the brightness
// while they wait their turn.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'ink_colors.dart'; // re-exports ink_palette.dart

class DistillTheme {
  DistillTheme._();

  // The type pairing is inherited from the warm theme unchanged. This stage is
  // a colour change; re-picking the typeface at the same time would make it
  // impossible to tell which of the two caused a regression.
  static const String _displayFont = 'Poppins';
  static const String _bodyFont = 'Nunito';

  /// Light: navy accent on warm off-white.
  static ThemeData get light => _build(Brightness.light, AppColors.light);

  /// Dark: gold accent and cream text on near-black.
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: _bodyFont,
      extensions: [c, isDark ? InkColors.dark : InkColors.light],
      colorScheme: _scheme(brightness, c),
      scaffoldBackgroundColor: c.bgPrimary,
      canvasColor: c.surface,
      primaryColor: c.accent,
      dividerColor: c.border,
      // Default glyph colour is `textPrimary`, not `accent`. The single-instance
      // chrome glyphs the spec keeps gold (back arrow, overflow, search leading
      // icon, meta-row icons) opt in at the call site; the repeated ones — the
      // twelve editor tools especially — must not.
      iconTheme: IconThemeData(color: c.textPrimary),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgPrimary,
        foregroundColor: c.accent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          color: c.accent,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      // The spec's one global asymmetry: "shadows generally present and soft in
      // light, replaced by hairline borders in dark. Do not carry BoxShadow into
      // dark mode." Encoded here so a plain `Card` obeys it without the screen
      // having to branch.
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: isDark ? Colors.transparent : null,
        elevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark ? BorderSide(color: c.border) : BorderSide.none,
        ),
      ),
      textTheme: _textTheme(c),
    );
  }

  /// M3 roles mapped onto the nine tokens.
  ///
  /// Seeded rather than hand-listed for one reason: [ColorScheme] requires
  /// `error`, `onError`, the tertiary family, the inverse family, `scrim` and
  /// `shadow`, and THEME_SPEC.md defines no token for any of them. Seeding from
  /// `accent` lets Flutter's own algorithm supply those instead of this file
  /// inventing hexes the spec never approved; every role the nine tokens DO
  /// cover is then overridden below, so nothing generated leaks into a surface
  /// or text role. If the spec later grows an error token, override it here.
  static ColorScheme _scheme(Brightness brightness, AppColors c) {
    return ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentMuted,
      onPrimaryContainer: c.accent,
      // No second brand hue exists in this palette; secondary aliases the
      // accent rather than letting the seed algorithm introduce one.
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentMuted,
      onSecondaryContainer: c.accent,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerLowest: c.bgPrimary,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceSubtle,
      surfaceContainerHigh: c.surfaceSubtle,
      surfaceContainerHighest: c.surfaceSubtle,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.border,
      // M3's elevation tint would pull the warm surfaces towards the primary
      // hue, which reads as dirty on paper and as a gold haze on near-black.
      surfaceTint: Colors.transparent,
    );
  }

  /// Type ramp.
  ///
  /// The split follows the spec's three tiers rather than Material's size
  /// ladder: display/headline/titleLarge are screen and section HEADINGS, which
  /// the spec keeps on `accent`; titleMedium/titleSmall are ROW titles, which
  /// the spec explicitly moves off accent onto `textPrimary`. Every body style
  /// is `textPrimary` — an unstyled `Text` resolves through `bodyMedium`, and
  /// content text must never come out accent-coloured.
  static TextTheme _textTheme(AppColors c) {
    TextStyle heading(double size, FontWeight w, {double tracking = -0.5}) =>
        TextStyle(
          fontFamily: _displayFont,
          color: c.accent,
          fontSize: size,
          fontWeight: w,
          letterSpacing: tracking,
        );

    TextStyle title(double size, FontWeight w) => TextStyle(
          fontFamily: _displayFont,
          color: c.textPrimary,
          fontSize: size,
          fontWeight: w,
        );

    TextStyle body(double size, {double height = 1.5}) => TextStyle(
          fontFamily: _bodyFont,
          color: c.textPrimary,
          fontSize: size,
          height: height,
        );

    return TextTheme(
      // Headings → accent
      displayLarge: heading(40, FontWeight.w700),
      displayMedium: heading(34, FontWeight.w700),
      displaySmall: heading(30, FontWeight.w600),
      headlineLarge: heading(28, FontWeight.w700),
      headlineMedium: heading(24, FontWeight.w600, tracking: -0.3),
      headlineSmall: heading(20, FontWeight.w600, tracking: -0.2),
      titleLarge: heading(20, FontWeight.w600, tracking: -0.2),
      // Row titles → textPrimary
      titleMedium: title(16, FontWeight.w600),
      titleSmall: title(14, FontWeight.w600),
      // Body → textPrimary
      bodyLarge: body(15, height: 1.55),
      bodyMedium: body(14),
      bodySmall: body(13, height: 1.45),
      // Labels: the large one is a button face (content weight), the smaller
      // two are meta chrome.
      labelLarge: TextStyle(
        fontFamily: _displayFont,
        color: c.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelMedium: TextStyle(
        fontFamily: _displayFont,
        color: c.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: _displayFont,
        color: c.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.4,
      ),
    );
  }
}
