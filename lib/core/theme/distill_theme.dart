// The app's ThemeData pair: the navy/gold skin, built entirely from the nine
// [AppColors] tokens. One builder, two brightnesses, so a role can never be
// defined for one and forgotten in the other.
//
// Every component theme below reads the same tokens. A widget that has not been
// moved to `context.colors` yet still lands on the right brightness and palette
// rather than on Material's defaults.

import 'package:flutter/material.dart';

import 'app_colors.dart';

class DistillTheme {
  DistillTheme._();

  // The type pairing is unchanged from the shipped app. Re-picking the typeface
  // in the same pass as the colours would make a regression impossible to pin on
  // one or the other.
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
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
      colorScheme: _scheme(brightness, c),
      scaffoldBackgroundColor: c.bgPrimary,
      canvasColor: c.surface,
      primaryColor: c.accent,
      splashColor: c.accentMuted,
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: isDark ? 0 : 4,
        focusElevation: isDark ? 0 : 6,
        highlightElevation: isDark ? 0 : 2,
        shape: const StadiumBorder(),
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
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: isDark ? BorderSide(color: c.border) : BorderSide.none,
        ),
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont,
          color: c.textSecondary,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: _displayFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: _displayFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: _displayFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          side: BorderSide(color: c.border, width: 1.5),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: _displayFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSubtle,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: c.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        // Selected: an accent track with the on-accent thumb — white in light,
        // near-black in dark — as THEME_SPEC.md's asymmetry table asks.
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? c.onAccent
                : (isDark ? c.textSecondary : c.surface)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? c.accent : c.surfaceSubtle),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.transparent
                : c.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.border,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        // Inverted by design: a snack bar reads as an overlay, not a surface.
        backgroundColor: c.textPrimary,
        contentTextStyle: TextStyle(fontFamily: _bodyFont, color: c.surface),
        // Not the accent: in light the accent is the snack bar's own navy, so an
        // accent action would vanish into the background it sits on.
        actionTextColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accentMuted,
        checkmarkColor: c.accent,
        side: BorderSide(color: c.border),
        labelStyle: TextStyle(
          fontFamily: _displayFont,
          color: c.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(
          fontFamily: _bodyFont,
          color: c.textPrimary,
          fontSize: 14,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: _displayFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? c.accent : c.textSecondary),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? c.accentMuted
                  : Colors.transparent),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceSubtle,
        circularTrackColor: c.surfaceSubtle,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: _bodyFont,
          color: c.surface,
          fontSize: 12,
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
  /// or text role. Error red therefore comes from Material's own error values.
  /// If the spec later grows an error token, override it here.
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
      // M3's elevation tint would pull the surfaces towards the primary hue,
      // which reads as a gold haze on near-black.
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
