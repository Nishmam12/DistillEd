// Design tokens scoped to the Notes list screen (UI v3.0).
//
// AppColors stays the authority for the rest of the app (warm cream skin); the
// notes browser follows its own cool, paper-white spec: a near-white canvas,
// pure white cards, near-black type and a deep navy accent. Keeping the tokens
// here means the browser can be re-skinned without touching the editor.
//
// ── Light / dark ──────────────────────────────────────────────────────────
// The browser follows the app's dark-mode setting, but stays *cool* where
// AppColors goes warm, so dark mode keeps the two skins as distinct as they
// are in light. Only the *mode* is read from `AppColors`; the values live
// here, so the browser is still re-skinned from this one file.
//
// The color tokens are getters, so nothing embedding one can be `const`. The
// metrics further down still are.

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// One complete set of browser color values.
class _NotesTokens {
  const _NotesTokens({
    required this.background,
    required this.card,
    required this.field,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.textOnAccent,
    required this.scrim,
    required this.previewTints,
  });

  final Color background;
  final Color card;
  final Color field;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color textOnAccent;
  final Color scrim;
  final List<Color> previewTints;
}

const _lightTokens = _NotesTokens(
  background: Color(0xFFF7F8FA),
  card: Color(0xFFFFFFFF),
  field: Color(0xFFECEDF1),
  textPrimary: Color(0xFF111111),
  textSecondary: Color(0xFF7A7A7A),
  accent: Color(0xFF192841), // deep navy
  textOnAccent: Color(0xFFFFFFFF),
  scrim: Color(0xFFFFFFFF),
  previewTints: <Color>[
    Color(0xFFEDEAF6), // lavender
    Color(0xFFEDE3D2), // sand
    Color(0xFFE7D7DD), // mauve
    Color(0xFFF3E2DC), // blush
    Color(0xFFD8E7E7), // teal
    Color(0xFFE4EAF2), // slate blue
    Color(0xFFE8EEE2), // sage
  ],
);

const _darkTokens = _NotesTokens(
  background: Color(0xFF0F1114), // cool near-black, not AppColors' charcoal
  card: Color(0xFF191C21),
  field: Color(0xFF23272E), // still a step off the canvas, as in light
  textPrimary: Color(0xFFF1F2F4),
  textSecondary: Color(0xFF979BA3),
  // The deep navy accent has nowhere to go on a dark canvas, so it inverts to
  // the light end of the same hue and carries dark type instead of white.
  accent: Color(0xFFA6C0E6),
  textOnAccent: Color(0xFF10161F),
  scrim: Color(0xFF14171B),
  previewTints: <Color>[
    Color(0xFF2A2740), // lavender
    Color(0xFF332C22), // sand
    Color(0xFF33242A), // mauve
    Color(0xFF3A2B25), // blush
    Color(0xFF1D2F2F), // teal
    Color(0xFF232C38), // slate blue
    Color(0xFF262E22), // sage
  ],
);

class NotesPalette {
  NotesPalette._();

  static _NotesTokens get _t => AppColors.isDark ? _darkTokens : _lightTokens;

  // ── Surfaces ───────────────────────────────────────────────
  static Color get background => _t.background;
  static Color get card => _t.card;

  /// Search field. A touch off the canvas — a white field on a near-white
  /// background has no edge to read, and the same holds inverted.
  static Color get field => _t.field;

  // ── Text ───────────────────────────────────────────────────
  static Color get textPrimary => _t.textPrimary;
  static Color get textSecondary => _t.textSecondary;

  // ── Accent ─────────────────────────────────────────────────
  static Color get accent => _t.accent;

  /// Type and icons sitting *on* [accent]: white on the light navy,
  /// near-black on the dark palette's lifted blue.
  static Color get textOnAccent => _t.textOnAccent;

  /// Base color of the washes laid over a card's preview — the frosted
  /// overlay panel and the readability gradient beside it. Both exist to put
  /// a legible ground under the note's title, so it follows the mode: a white
  /// veil in light, a near-black one in dark.
  static Color get scrim => _t.scrim;

  // ── Metrics ────────────────────────────────────────────────
  /// Outer radius of a note card.
  static const cardRadius = 22.0;

  /// Resting card height. Responsive callers clamp within 150–170.
  static const cardHeight = 160.0;
  static const cardHeightMin = 150.0;
  static const cardHeightMax = 170.0;

  /// Share of the card width taken by the frosted overlay (spec: 30–35%).
  static const overlayWidthFactor = 0.34;

  /// Blur applied by the overlay's BackdropFilter.
  static const overlayBlurSigma = 8.0;

  /// Radius of the floating knowledge-graph button.
  static const graphButtonRadius = 26.0;

  static const listPadding = EdgeInsets.fromLTRB(18, 20, 18, 120);
  static const cardGap = 16.0;
  static const searchBarHeight = 52.0;

  // ── Shadows ────────────────────────────────────────────────
  static const shadowColor = Colors.black;

  /// Soft resting shadow: blur ~20, opacity ~10%.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// Slightly stronger lift used on hover / press.
  static List<BoxShadow> get cardShadowRaised => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.13),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  /// Elevation-like shadow for elements floating above a card.
  static List<BoxShadow> get floatShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.16),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// The overlay casts its own soft shadow onto the preview beside it.
  static List<BoxShadow> get overlayShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.07),
          blurRadius: 16,
          offset: const Offset(4, 0),
        ),
      ];

  // ── Preview tints ──────────────────────────────────────────
  /// Muted washes behind text previews, so a list of notes reads as a shelf of
  /// distinct documents rather than a stack of identical rows.
  static List<Color> get previewTints => _t.previewTints;

  /// Stable tint for a note, so a card keeps its colour across rebuilds.
  static Color tintFor(int seed) =>
      previewTints[seed.abs() % previewTints.length];
}
