// App-wide ThemeData built from AppColors design tokens.
//
// Warm & friendly direction: cream surfaces, white cards that lift on soft
// warm-tinted shadows, fully-rounded coral pill buttons, and a Poppins
// (display/labels) + Nunito (body) type pairing.
//
// Light and dark share this one builder: it reads `AppColors`, which resolves
// to whichever palette is installed, so dark mode is the same theme in warm
// charcoal rather than a second hand-maintained copy. Nothing here can be
// `const` for that reason — the token values are only known at call time.

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String _displayFont = 'Poppins';
  static const String _bodyFont = 'Nunito';

  /// The warm, paper-light theme.
  static ThemeData get warmTheme => themeFor(Brightness.light);

  /// The warm *dark* theme — same design language, charcoal surfaces.
  static ThemeData get darkTheme => themeFor(Brightness.dark);

  /// Builds the theme for [brightness], installing the matching palette first
  /// so every `AppColors` token below resolves to the right value.
  static ThemeData themeFor(Brightness brightness) {
    AppColors.install(brightness);
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      primaryColor: AppColors.accent,
      fontFamily: _bodyFont,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: AppColors.textOnAccent,
        secondary: AppColors.accentPurple,
        onSecondary: AppColors.textOnAccent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.accentRed,
        onError: AppColors.textOnAccent,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnAccent,
        elevation: 4,
        focusElevation: 6,
        highlightElevation: 2,
        shape: const StadiumBorder(),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: AppColors.textSecondary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont,
          color: AppColors.textSecondary,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textOnAccent,
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
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
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accentSoft, width: 1.5),
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
        fillColor: AppColors.surfaceWarm,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.surface;
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.surfaceHighlight;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return AppColors.borderStrong;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont,
          color: AppColors.surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    TextStyle display(double size, FontWeight w, {double tracking = -0.5}) =>
        TextStyle(
          fontFamily: _displayFont,
          color: AppColors.textPrimary,
          fontSize: size,
          fontWeight: w,
          letterSpacing: tracking,
        );

    return base.copyWith(
      // Display / headings → Poppins
      displayLarge: display(40, FontWeight.w700),
      displayMedium: display(34, FontWeight.w700),
      displaySmall: display(30, FontWeight.w600),
      headlineLarge: display(28, FontWeight.w700),
      headlineMedium: display(24, FontWeight.w600, tracking: -0.3),
      headlineSmall: display(20, FontWeight.w600, tracking: -0.2),
      titleLarge: display(20, FontWeight.w600, tracking: -0.2),
      titleMedium: TextStyle(
        fontFamily: _displayFont,
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: _displayFont,
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      // Body / long-form → Nunito
      bodyLarge: TextStyle(
        fontFamily: _bodyFont,
        color: AppColors.textPrimary,
        fontSize: 15,
        height: 1.55,
      ),
      bodyMedium: TextStyle(
        fontFamily: _bodyFont,
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: _bodyFont,
        color: AppColors.textMuted,
        fontSize: 13,
      ),
      // Labels / CTAs → Poppins
      labelLarge: TextStyle(
        fontFamily: _displayFont,
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelMedium: TextStyle(
        fontFamily: _displayFont,
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: _displayFont,
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.4,
      ),
    );
  }
}
