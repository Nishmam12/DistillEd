// Design token constants for DistillEd's warm & friendly note-taking aesthetic.
//
// Design language from the "Noted" landing (pill buttons, cream surfaces,
// doodle accents); color + type authority from the "Notely" mobile app
// (coral/terracotta primary on warm cream, periwinkle secondary).
//
// NOTE: the original semantic names (background/surface/accent/…) are kept so
// the whole app re-skins from this one file.
//
// ── Light / dark ──────────────────────────────────────────────────────────
// Every token is a *getter* that reads from the currently-installed
// [_AppPalette]. That keeps all ~380 `AppColors.x` call sites untouched while
// letting the whole app re-skin at runtime: `AppColors.install(...)` swaps the
// palette and `InkFlowApp` re-keys its subtree so every widget rebuilds with
// the new values (see `lib/app/app.dart`).
//
// Dark mode stays inside the warm design language — the ramp is warm charcoal,
// not neutral grey, and the accents are lifted (not desaturated) so coral and
// periwinkle keep enough contrast against a dark surface.

import 'package:flutter/material.dart';

/// One complete set of color values. Immutable; swapped wholesale.
class _AppPalette {
  const _AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceWarm,
    required this.surfaceAlt,
    required this.surfaceHighlight,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnAccent,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.accentWash,
    required this.accentPurple,
    required this.accentPurpleStrong,
    required this.accentPurpleWash,
    required this.sunny,
    required this.sunnyWash,
    required this.accentGreen,
    required this.accentGreenWash,
    required this.accentYellow,
    required this.accentYellowWash,
    required this.accentRed,
    required this.accentRedWash,
    required this.penPalette,
    required this.shadowTint,
    required this.shadowOpacityScale,
  });

  final Brightness brightness;

  final Color background;
  final Color surface;
  final Color surfaceWarm;
  final Color surfaceAlt;
  final Color surfaceHighlight;
  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnAccent;

  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color accentWash;

  final Color accentPurple;
  final Color accentPurpleStrong;
  final Color accentPurpleWash;

  final Color sunny;
  final Color sunnyWash;
  final Color accentGreen;
  final Color accentGreenWash;
  final Color accentYellow;
  final Color accentYellowWash;
  final Color accentRed;
  final Color accentRedWash;

  final List<Color> penPalette;

  final Color shadowTint;

  /// Soft warm shadows read as mud on a dark surface, so the dark palette
  /// deepens them instead of scaling them up.
  final double shadowOpacityScale;
}

const _lightPalette = _AppPalette(
  brightness: Brightness.light,

  // ── Warm surfaces (light, paper-like) ──────────────────────
  background: Color(0xFFF4ECE1), // app background — soft warm cream
  surface: Color(0xFFFFFFFF), // cards, sheets, app bar
  surfaceWarm: Color(0xFFFCF8F3), // subtly warm white for large fills
  surfaceAlt: Color(0xFFF8EFE6), // peach — alt section band
  surfaceHighlight: Color(0xFFEFE5D8), // sand — pressed / raised tint
  border: Color(0xFFEBE1D4), // hairline / card outline on cream
  borderStrong: Color(0xFFE0D5C5),

  // ── Text (warm charcoal ramp) ──────────────────────────────
  textPrimary: Color(0xFF33302E), // headings, primary text
  textSecondary: Color(0xFF6E6660), // secondary / body-supporting
  textMuted: Color(0xFFA89F95), // captions, placeholders, disabled
  textOnAccent: Color(0xFFFFFFFF), // white rides on the coral button

  // ── Primary: coral / terracotta ────────────────────────────
  accent: Color(0xFFD9654E), // primary — buttons, links, highlight
  accentStrong: Color(0xFFC5543D), // hover / pressed
  accentSoft: Color(0xFFF0C9BF), // tint borders, subtle fills
  accentWash: Color(0xFFFBEDE8), // selected/active background wash

  // ── Secondary: periwinkle (from the doodle illustrations) ──
  accentPurple: Color(0xFF8B8BD8),
  accentPurpleStrong: Color(0xFF6F6FC4),
  accentPurpleWash: Color(0xFFECECF8),

  // ── Supporting / status hues (warm) ────────────────────────
  sunny: Color(0xFFF2802E),
  sunnyWash: Color(0xFFFBE9D9),
  accentGreen: Color(0xFF5BA672), // leaf — success
  accentGreenWash: Color(0xFFE6F1E8),
  accentYellow: Color(0xFFE3A53D), // honey — warning
  accentYellowWash: Color(0xFFFBF0D9),
  accentRed: Color(0xFFCF4A36), // berry — danger
  accentRedWash: Color(0xFFFAE4DF),

  // ── Pen / ink palette (warm, friendly set) ─────────────────
  penPalette: <Color>[
    Color(0xFF33302E), // ink
    Color(0xFFD9654E), // coral
    Color(0xFFF2802E), // sunny
    Color(0xFFE3A53D), // honey
    Color(0xFF5BA672), // leaf
    Color(0xFF3FA6A0), // teal
    Color(0xFF8B8BD8), // periwinkle
    Color(0xFFC0497E), // berry
    Color(0xFF5B9BD5), // sky
    Color(0xFFFFFFFF), // white
  ],

  // ── Warm-tinted shadow (never harsh black) ─────────────────
  shadowTint: Color(0xFF4A3628),
  shadowOpacityScale: 1.0,
);

const _darkPalette = _AppPalette(
  brightness: Brightness.dark,

  // ── Warm dark surfaces (charcoal with a brown cast, not neutral grey) ──
  background: Color(0xFF1B1816), // app background — warm near-black
  surface: Color(0xFF262220), // cards, sheets, app bar
  surfaceWarm: Color(0xFF221F1C), // large fills, a touch below `surface`
  surfaceAlt: Color(0xFF2D2825), // alt section band
  surfaceHighlight: Color(0xFF383129), // pressed / raised tint
  border: Color(0xFF3A342E), // hairline / card outline
  borderStrong: Color(0xFF4C443C),

  // ── Text (inverted warm ramp) ──────────────────────────────
  textPrimary: Color(0xFFF3EDE6),
  textSecondary: Color(0xFFBCB2A8),
  textMuted: Color(0xFF8A8079),
  textOnAccent: Color(0xFF1B1816), // dark ink rides on the lifted coral

  // ── Primary: coral, lifted for contrast on dark ────────────
  accent: Color(0xFFE8826A),
  accentStrong: Color(0xFFF2977E), // hover / pressed reads *brighter* on dark
  accentSoft: Color(0xFF6E3C30), // tint borders, subtle fills
  accentWash: Color(0xFF39221C), // selected/active background wash

  // ── Secondary: periwinkle ──────────────────────────────────
  accentPurple: Color(0xFFA3A3E6),
  accentPurpleStrong: Color(0xFFBBBBF0),
  accentPurpleWash: Color(0xFF2A2A3C),

  // ── Supporting / status hues ───────────────────────────────
  sunny: Color(0xFFF59A4E),
  sunnyWash: Color(0xFF3A2A18),
  accentGreen: Color(0xFF76C08D), // leaf — success
  accentGreenWash: Color(0xFF1E2E23),
  accentYellow: Color(0xFFEDBA60), // honey — warning
  accentYellowWash: Color(0xFF362C18),
  accentRed: Color(0xFFE4614A), // berry — danger
  accentRedWash: Color(0xFF3B201B),

  // ── Pen / ink palette (ink and white swap ends; paper is dark now) ──
  penPalette: <Color>[
    Color(0xFFF3EDE6), // chalk — the default "ink" on a dark page
    Color(0xFFE8826A), // coral
    Color(0xFFF59A4E), // sunny
    Color(0xFFEDBA60), // honey
    Color(0xFF76C08D), // leaf
    Color(0xFF55BDB6), // teal
    Color(0xFFA3A3E6), // periwinkle
    Color(0xFFDB6A9D), // berry
    Color(0xFF7FB8E5), // sky
    Color(0xFF1B1816), // ink
  ],

  // ── Shadow: deep, not warm-brown, so it reads as depth ─────
  shadowTint: Color(0xFF000000),
  shadowOpacityScale: 2.2,
);

class AppColors {
  AppColors._();

  static _AppPalette _palette = _lightPalette;

  /// Installs the light or dark palette. Returns true when the value actually
  /// changed, so callers can skip a pointless rebuild.
  static bool install(Brightness brightness) {
    if (_palette.brightness == brightness) return false;
    _palette = brightness == Brightness.dark ? _darkPalette : _lightPalette;
    return true;
  }

  static Brightness get brightness => _palette.brightness;
  static bool get isDark => _palette.brightness == Brightness.dark;

  // ── Surfaces ───────────────────────────────────────────────
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceWarm => _palette.surfaceWarm;
  static Color get surfaceAlt => _palette.surfaceAlt;
  static Color get surfaceHighlight => _palette.surfaceHighlight;
  static Color get border => _palette.border;
  static Color get borderStrong => _palette.borderStrong;

  // ── Text ───────────────────────────────────────────────────
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textMuted => _palette.textMuted;
  static Color get textOnAccent => _palette.textOnAccent;

  // ── Primary: coral / terracotta ────────────────────────────
  static Color get accent => _palette.accent;
  static Color get accentStrong => _palette.accentStrong;
  static Color get accentSoft => _palette.accentSoft;
  static Color get accentWash => _palette.accentWash;

  // ── Secondary: periwinkle ──────────────────────────────────
  static Color get accentPurple => _palette.accentPurple;
  static Color get accentPurpleStrong => _palette.accentPurpleStrong;
  static Color get accentPurpleWash => _palette.accentPurpleWash;

  // ── Supporting / status hues ───────────────────────────────
  static Color get sunny => _palette.sunny;
  static Color get sunnyWash => _palette.sunnyWash;
  static Color get accentGreen => _palette.accentGreen;
  static Color get accentGreenWash => _palette.accentGreenWash;
  static Color get accentYellow => _palette.accentYellow;
  static Color get accentYellowWash => _palette.accentYellowWash;
  static Color get accentRed => _palette.accentRed;
  static Color get accentRedWash => _palette.accentRedWash;

  // ── Tool hues (the editor keeps per-tool color) ────────────
  static Color get toolPen => accent; // coral
  static Color get toolPenWash => accentWash;
  static Color get toolEraser => accentYellow; // honey
  static Color get toolEraserWash => accentYellowWash;
  static Color get toolShape => accentGreen; // leaf
  static Color get toolShapeWash => accentGreenWash;
  static Color get toolLasso => accentPurple; // periwinkle
  static Color get toolLassoWash => accentPurpleWash;

  // ── Pen / ink palette ──────────────────────────────────────
  static List<Color> get penPalette => _palette.penPalette;

  // ── Paper colors (canvas backgrounds) ──────────────────────
  //
  // Deliberately *not* themed: a page's background is persisted note data, so
  // re-skinning these would silently change the meaning of colors already
  // stored on existing pages (and of PNG/PDF exports). Dark-mode users pick a
  // dark page from the background sheet instead.
  static const paperWhite = Color(0xFFFFFFFF);
  static const paperCream = Color(0xFFFAF4EA);
  static const paperBlush = Color(0xFFFBEFEA);
  static const paperSlate = Color(0xFF262220);

  // ── Shadow ─────────────────────────────────────────────────
  static Color get shadowTint => _palette.shadowTint;

  static double _shadow(double alpha) =>
      (alpha * _palette.shadowOpacityScale).clamp(0.0, 1.0);

  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: shadowTint.withValues(alpha: _shadow(0.08)),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: shadowTint.withValues(alpha: _shadow(0.05)),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowFloat => [
        BoxShadow(
          color: shadowTint.withValues(alpha: _shadow(0.12)),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: shadowTint.withValues(alpha: _shadow(0.06)),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowCta => [
        BoxShadow(
          color: accent.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
