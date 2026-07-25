// Design tokens scoped to the Notes list screen (UI v3.0).
//
// AppColors stays the authority for the rest of the app (warm cream skin); the
// notes browser follows its own cool, paper-white spec: a near-white canvas,
// pure white cards, near-black type and a deep navy accent. Keeping the tokens
// here means the browser can be re-skinned without touching the editor.

import 'package:flutter/material.dart';

class NotesPalette {
  NotesPalette._();

  // ── Surfaces ───────────────────────────────────────────────
  static const background = Color(0xFFF7F8FA);
  static const card = Color(0xFFFFFFFF);

  /// Search field. A touch darker than the canvas — a white field on a
  /// near-white background has no edge to read.
  static const field = Color(0xFFECEDF1);

  // ── Text ───────────────────────────────────────────────────
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF7A7A7A);

  // ── Accent ─────────────────────────────────────────────────
  static const accent = Color(0xFF192841);

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
  /// distinct documents rather than a stack of identical white rows.
  static const previewTints = <Color>[
    Color(0xFFEDEAF6), // lavender
    Color(0xFFEDE3D2), // sand
    Color(0xFFE7D7DD), // mauve
    Color(0xFFF3E2DC), // blush
    Color(0xFFD8E7E7), // teal
    Color(0xFFE4EAF2), // slate blue
    Color(0xFFE8EEE2), // sage
  ];

  /// Stable tint for a note, so a card keeps its colour across rebuilds.
  static Color tintFor(int seed) =>
      previewTints[seed.abs() % previewTints.length];
}
