// App-wide ThemeData, built for both brightnesses from one shared builder.
//
// Warm & friendly direction: cream (light) / warm-charcoal (dark) surfaces,
// white or near-black cards that lift on soft shadows, fully-rounded coral pill
// buttons, and a Poppins (display/labels) + Nunito (body) type pairing.
//
// Every colour comes from an [InkPalette]; the palette also rides along on the
// [InkColors] extension so widgets can reach brand roles M3's ColorScheme has
// no slot for. One builder, two palettes — a role can never be defined for one
// brightness and forgotten in the other.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'ink_colors.dart'; // re-exports ink_palette.dart

class AppTheme {
  AppTheme._();

  static const String _displayFont = 'Poppins';
  static const String _bodyFont = 'Nunito';

  /// The warm, paper-light theme — the app's original skin, unchanged.
  static ThemeData light() => _build(Brightness.light, InkPalette.light);

  /// The warm-charcoal dark theme.
  static ThemeData dark() => _build(Brightness.dark, InkPalette.dark);

  /// Back-compat alias — call sites historically referenced `warmTheme`.
  static ThemeData get warmTheme => light();

  static ThemeData _build(Brightness brightness, InkPalette p) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.surface,
      primaryColor: p.accent,
      fontFamily: _bodyFont,
      splashFactory: InkSparkle.splashFactory,
      // The palette itself travels on the theme, so `context.ink` can reach any
      // role without the widget knowing which brightness is active.
      //
      // [AppColors] rides along beside it so `context.colors` already resolves
      // while screens are migrated to the navy/gold spec one at a time. It is
      // additive and changes nothing on its own: an extension nobody reads
      // paints no pixels, and every colour this theme actually applies still
      // comes from the coral [InkPalette] above. The switch to the navy/gold
      // base theme happens in `distill_theme.dart`, wired from `app/app.dart`
      // once there is a migrated screen to look at.
      extensions: [
        InkColors(p),
        brightness == Brightness.dark ? AppColors.dark : AppColors.light,
      ],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: p.textOnAccent,
        primaryContainer: p.accentWash,
        onPrimaryContainer: p.textPrimary,
        secondary: p.accentPurple,
        onSecondary: p.textOnAccent,
        secondaryContainer: p.accentPurpleWash,
        onSecondaryContainer: p.textPrimary,
        surface: p.surface,
        onSurface: p.textPrimary,
        surfaceContainerLowest: p.background,
        surfaceContainerLow: p.surfaceWarm,
        surfaceContainer: p.surfaceWarm,
        surfaceContainerHigh: p.surfaceAlt,
        surfaceContainerHighest: p.surfaceHighlight,
        onSurfaceVariant: p.textSecondary,
        outline: p.borderStrong,
        outlineVariant: p.border,
        error: p.accentRed,
        onError: p.textOnAccent,
        errorContainer: p.accentRedWash,
        onErrorContainer: p.textPrimary,
        // Transparent: M3's elevation tint would wash the warm surfaces
        // towards the primary hue, which reads as dirty on paper.
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.textOnAccent,
        elevation: 4,
        focusElevation: 6,
        highlightElevation: 2,
        shape: const StadiumBorder(),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont,
          color: p.textSecondary,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.textOnAccent,
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
          backgroundColor: p.accent,
          foregroundColor: p.textOnAccent,
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
          foregroundColor: p.accent,
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
          foregroundColor: p.accent,
          side: BorderSide(color: p.accentSoft, width: 1.5),
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
        fillColor: p.surfaceWarm,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: p.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(p.surface),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? p.accent
                : p.surfaceHighlight),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.transparent
                : p.borderStrong),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        // Inverted by design: a snack bar reads as an overlay, not a surface.
        backgroundColor: p.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: _bodyFont,
          color: p.surface,
        ),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      // The component themes below carry no light-mode visual change — they
      // restate the defaults the app was already getting. They exist because
      // Material's *dark* defaults are neutral grey, which would put cold grey
      // chips and menus on warm charcoal surfaces.
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceWarm,
        selectedColor: p.accentWash,
        checkmarkColor: p.accent,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(
          fontFamily: _displayFont,
          color: p.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(
          fontFamily: _bodyFont,
          color: p.textPrimary,
          fontSize: 14,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: _displayFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? p.accent
                  : p.textSecondary),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? p.accentWash
                  : Colors.transparent),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceHighlight,
        circularTrackColor: p.surfaceHighlight,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: _bodyFont,
          color: p.surface,
          fontSize: 12,
        ),
      ),
      splashColor: p.accentWash,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, p),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, InkPalette p) {
    TextStyle display(double size, FontWeight w, {double tracking = -0.5}) =>
        TextStyle(
          fontFamily: _displayFont,
          color: p.textPrimary,
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
        color: p.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: _displayFont,
        color: p.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      // Body / long-form → Nunito
      bodyLarge: TextStyle(
        fontFamily: _bodyFont,
        color: p.textPrimary,
        fontSize: 15,
        height: 1.55,
      ),
      bodyMedium: TextStyle(
        fontFamily: _bodyFont,
        color: p.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: _bodyFont,
        color: p.textMuted,
        fontSize: 13,
      ),
      // Labels / CTAs → Poppins
      labelLarge: TextStyle(
        fontFamily: _displayFont,
        color: p.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelMedium: TextStyle(
        fontFamily: _displayFont,
        color: p.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: _displayFont,
        color: p.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.4,
      ),
    );
  }
}
