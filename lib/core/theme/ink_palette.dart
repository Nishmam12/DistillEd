// Raw colour values — the only place in the app where a colour literal for
// *chrome* is allowed to live.
//
// Two brightness sets. Nothing outside this file should hardcode a chrome
// Color; widgets read semantic roles through `context.ink` / `context.notes`
// (see theme_context.dart), or from the M3 [ColorScheme].
//
// The light set is byte-for-byte the values that used to live in
// `core/constants/app_colors.dart` and `features/home/presentation/
// notes_palette.dart`, so light mode renders exactly as it did before the token
// layer existed. Only the dark set is new.
//
// Ink and paper are deliberately absent. A drawn stroke and a chosen paper are
// *content*, not chrome, and are never remapped by the app theme — they stay as
// plain constants on `AppColors`. See that file's header for why.

import 'package:flutter/material.dart';

/// Colour roles scoped to the notes browser, which follows its own cool,
/// paper-white direction (UI v3.0) rather than the warm skin the rest of the
/// app wears: near-white canvas, pure white cards, near-black type, deep navy
/// accent. Kept as a distinct group so the browser can still be re-skinned
/// without touching the editor.
@immutable
class NotesInk {
  final Color background;
  final Color card;

  /// Search field. A touch darker than the canvas — a white field on a
  /// near-white background has no edge to read.
  final Color field;

  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color shadowColor;

  /// Soft resting shadow under a note card.
  final List<BoxShadow> cardShadow;

  /// Slightly stronger lift used on hover / press.
  final List<BoxShadow> cardShadowRaised;

  /// Elevation-like shadow for elements floating above a card.
  final List<BoxShadow> floatShadow;

  /// The frosted overlay casts its own soft shadow onto the preview beside it.
  final List<BoxShadow> overlayShadow;

  /// Muted washes behind text previews, so a list of notes reads as a shelf of
  /// distinct documents rather than a stack of identical rows.
  final List<Color> previewTints;

  const NotesInk({
    required this.background,
    required this.card,
    required this.field,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.shadowColor,
    required this.cardShadow,
    required this.cardShadowRaised,
    required this.floatShadow,
    required this.overlayShadow,
    required this.previewTints,
  });

  /// Stable tint for a note, so a card keeps its colour across rebuilds.
  Color tintFor(int seed) => previewTints[seed.abs() % previewTints.length];

  static NotesInk lerp(NotesInk a, NotesInk b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    List<BoxShadow> s(List<BoxShadow> x, List<BoxShadow> y) =>
        BoxShadow.lerpList(x, y, t) ?? x;
    return NotesInk(
      background: c(a.background, b.background),
      card: c(a.card, b.card),
      field: c(a.field, b.field),
      textPrimary: c(a.textPrimary, b.textPrimary),
      textSecondary: c(a.textSecondary, b.textSecondary),
      accent: c(a.accent, b.accent),
      shadowColor: c(a.shadowColor, b.shadowColor),
      cardShadow: s(a.cardShadow, b.cardShadow),
      cardShadowRaised: s(a.cardShadowRaised, b.cardShadowRaised),
      floatShadow: s(a.floatShadow, b.floatShadow),
      overlayShadow: s(a.overlayShadow, b.overlayShadow),
      previewTints: [
        for (var i = 0; i < a.previewTints.length; i++)
          c(a.previewTints[i], b.previewTints[i]),
      ],
    );
  }
}

/// One brightness's worth of raw values, assembled into the [InkColors] theme
/// extension and an M3 [ColorScheme] by app_theme.dart.
///
/// Role *names* are inherited from the pre-token `AppColors` / `NotesPalette`,
/// so the vocabulary the rest of the app already speaks survives the move.
@immutable
class InkPalette {
  // ── Warm surfaces ──────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color surfaceWarm;
  final Color surfaceAlt;
  final Color surfaceHighlight;
  final Color border;
  final Color borderStrong;

  // ── Text ramp ──────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnAccent;

  // ── Primary: coral / terracotta ────────────────────────────
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color accentWash;

  // ── Secondary: periwinkle ──────────────────────────────────
  final Color accentPurple;
  final Color accentPurpleStrong;
  final Color accentPurpleWash;

  // ── Supporting / status hues ───────────────────────────────
  final Color sunny;
  final Color sunnyWash;
  final Color accentGreen;
  final Color accentGreenWash;
  final Color accentYellow;
  final Color accentYellowWash;
  final Color accentRed;
  final Color accentRedWash;

  // ── Elevation shadows ──────────────────────────────────────
  // Stored as built lists rather than a tint plus an alpha, because the two
  // brightnesses do not share a recipe: a warm brown shadow is invisible on a
  // warm-dark surface, so dark uses black at a higher alpha instead.
  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowFloat;
  final List<BoxShadow> shadowCta;

  /// The notes browser's own colour group.
  final NotesInk notes;

  const InkPalette({
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
    required this.shadowCard,
    required this.shadowFloat,
    required this.shadowCta,
    required this.notes,
  });

  // ── Tool hues ──────────────────────────────────────────────
  // The editor keeps a colour per tool; each is an alias of a status hue rather
  // than a value of its own, so a palette change carries automatically.
  Color get toolPen => accent;
  Color get toolPenWash => accentWash;
  Color get toolEraser => accentYellow;
  Color get toolEraserWash => accentYellowWash;
  Color get toolShape => accentGreen;
  Color get toolShapeWash => accentGreenWash;
  Color get toolLasso => accentPurple;
  Color get toolLassoWash => accentPurpleWash;

  /// The warm, paper-like light set — the app's original skin, unchanged.
  static const InkPalette light = InkPalette(
    background: Color(0xFFF4ECE1), // soft warm cream
    surface: Color(0xFFFFFFFF), // cards, sheets, app bar
    surfaceWarm: Color(0xFFFCF8F3), // subtly warm white for large fills
    surfaceAlt: Color(0xFFF8EFE6), // peach — alt section band
    surfaceHighlight: Color(0xFFEFE5D8), // sand — pressed / raised tint
    border: Color(0xFFEBE1D4),
    borderStrong: Color(0xFFE0D5C5),
    textPrimary: Color(0xFF33302E),
    textSecondary: Color(0xFF6E6660),
    textMuted: Color(0xFFA89F95),
    textOnAccent: Color(0xFFFFFFFF),
    accent: Color(0xFFD9654E),
    accentStrong: Color(0xFFC5543D),
    accentSoft: Color(0xFFF0C9BF),
    accentWash: Color(0xFFFBEDE8),
    accentPurple: Color(0xFF8B8BD8),
    accentPurpleStrong: Color(0xFF6F6FC4),
    accentPurpleWash: Color(0xFFECECF8),
    sunny: Color(0xFFF2802E),
    sunnyWash: Color(0xFFFBE9D9),
    accentGreen: Color(0xFF5BA672), // leaf
    accentGreenWash: Color(0xFFE6F1E8),
    accentYellow: Color(0xFFE3A53D), // honey
    accentYellowWash: Color(0xFFFBF0D9),
    accentRed: Color(0xFFCF4A36), // berry
    accentRedWash: Color(0xFFFAE4DF),
    // Warm charcoal (#4A3628) at the alphas the old AppColors getters used.
    shadowCard: [
      BoxShadow(color: Color(0x144A3628), blurRadius: 18, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x0D4A3628), blurRadius: 3, offset: Offset(0, 1)),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x1F4A3628), blurRadius: 32, offset: Offset(0, 12)),
      BoxShadow(color: Color(0x0F4A3628), blurRadius: 8, offset: Offset(0, 2)),
    ],
    shadowCta: [
      BoxShadow(color: Color(0x47D9654E), blurRadius: 20, offset: Offset(0, 8)),
    ],
    notes: NotesInk(
      background: Color(0xFFF7F8FA),
      card: Color(0xFFFFFFFF),
      field: Color(0xFFECEDF1),
      textPrimary: Color(0xFF111111),
      // Darkened from the original #7A7A7A, which sat at 4.29:1 on a white
      // card — just under the 4.5:1 WCAG AA bar for body text. This is the one
      // light-mode value the dark-mode work changed, and it is a legibility
      // fix rather than a design change: 5.1:1, and near-indistinguishable
      // from its predecessor side by side.
      textSecondary: Color(0xFF6E6E6E),
      accent: Color(0xFF192841), // deep navy
      shadowColor: Color(0xFF000000),
      cardShadow: [
        BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
      ],
      cardShadowRaised: [
        BoxShadow(color: Color(0x21000000), blurRadius: 28, offset: Offset(0, 12)),
      ],
      floatShadow: [
        BoxShadow(color: Color(0x29000000), blurRadius: 18, offset: Offset(0, 6)),
        BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
      ],
      overlayShadow: [
        BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(4, 0)),
      ],
      previewTints: [
        Color(0xFFEDEAF6), // lavender
        Color(0xFFEDE3D2), // sand
        Color(0xFFE7D7DD), // mauve
        Color(0xFFF3E2DC), // blush
        Color(0xFFD8E7E7), // teal
        Color(0xFFE4EAF2), // slate blue
        Color(0xFFE8EEE2), // sage
      ],
    ),
  );

  /// The dark set — warm charcoal rather than neutral grey, so the app reads as
  /// the same product with the lights off rather than a different one.
  ///
  /// Two roles invert rather than darken: the coral accent *lightens* (a mid
  /// coral on near-black fails contrast), and `textOnAccent` becomes a deep
  /// brown, because white on light coral does not carry.
  static const InkPalette dark = InkPalette(
    background: Color(0xFF1A1714),
    surface: Color(0xFF221E1A),
    surfaceWarm: Color(0xFF26221D),
    surfaceAlt: Color(0xFF2C2721),
    surfaceHighlight: Color(0xFF332D26),
    border: Color(0xFF38312A),
    borderStrong: Color(0xFF4A4239),
    textPrimary: Color(0xFFF2EAE0),
    textSecondary: Color(0xFFBFB4A8),
    textMuted: Color(0xFF8F857A),
    textOnAccent: Color(0xFF3A1A0E),
    accent: Color(0xFFF08C6E),
    accentStrong: Color(0xFFF5A78D),
    accentSoft: Color(0xFF6B3527),
    accentWash: Color(0xFF33211B),
    accentPurple: Color(0xFFA9A9E8),
    accentPurpleStrong: Color(0xFFC3C3F2),
    accentPurpleWash: Color(0xFF26243A),
    sunny: Color(0xFFF2A05C),
    sunnyWash: Color(0xFF33241A),
    accentGreen: Color(0xFF7BC48F),
    accentGreenWash: Color(0xFF1D2A21),
    accentYellow: Color(0xFFE0B15C),
    accentYellowWash: Color(0xFF2E2617),
    accentRed: Color(0xFFF08472),
    accentRedWash: Color(0xFF301E1A),
    // Black, not warm brown: a brown shadow on a brown-black surface is
    // invisible, so depth in dark comes from a harder, higher-alpha shadow.
    shadowCard: [
      BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x59000000), blurRadius: 32, offset: Offset(0, 12)),
      BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    shadowCta: [
      BoxShadow(color: Color(0x66F08C6E), blurRadius: 20, offset: Offset(0, 8)),
    ],
    // The browser stays cooler than the rest of the app here too, preserving
    // the deliberate contrast between library and editor.
    notes: NotesInk(
      background: Color(0xFF15171A),
      card: Color(0xFF1E2126),
      field: Color(0xFF272B31),
      textPrimary: Color(0xFFECEEF2),
      textSecondary: Color(0xFF9BA1AA),
      // The light spec's deep navy would vanish here, so the accent inverts to
      // a pale slate blue that keeps the same cool cast.
      accent: Color(0xFFA8C0E0),
      shadowColor: Color(0xFF000000),
      cardShadow: [
        BoxShadow(color: Color(0x73000000), blurRadius: 20, offset: Offset(0, 8)),
      ],
      cardShadowRaised: [
        BoxShadow(color: Color(0x8C000000), blurRadius: 28, offset: Offset(0, 12)),
      ],
      floatShadow: [
        BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 6)),
        BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
      ],
      overlayShadow: [
        BoxShadow(color: Color(0x4D000000), blurRadius: 16, offset: Offset(4, 0)),
      ],
      previewTints: [
        Color(0xFF2A2740), // lavender
        Color(0xFF332C22), // sand
        Color(0xFF33262B), // mauve
        Color(0xFF362824), // blush
        Color(0xFF1F2E2E), // teal
        Color(0xFF232A33), // slate blue
        Color(0xFF262D24), // sage
      ],
    ),
  );

  /// Blends two palettes, so a theme switch crossfades instead of snapping.
  static InkPalette lerp(InkPalette a, InkPalette b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    List<BoxShadow> s(List<BoxShadow> x, List<BoxShadow> y) =>
        BoxShadow.lerpList(x, y, t) ?? x;
    return InkPalette(
      background: c(a.background, b.background),
      surface: c(a.surface, b.surface),
      surfaceWarm: c(a.surfaceWarm, b.surfaceWarm),
      surfaceAlt: c(a.surfaceAlt, b.surfaceAlt),
      surfaceHighlight: c(a.surfaceHighlight, b.surfaceHighlight),
      border: c(a.border, b.border),
      borderStrong: c(a.borderStrong, b.borderStrong),
      textPrimary: c(a.textPrimary, b.textPrimary),
      textSecondary: c(a.textSecondary, b.textSecondary),
      textMuted: c(a.textMuted, b.textMuted),
      textOnAccent: c(a.textOnAccent, b.textOnAccent),
      accent: c(a.accent, b.accent),
      accentStrong: c(a.accentStrong, b.accentStrong),
      accentSoft: c(a.accentSoft, b.accentSoft),
      accentWash: c(a.accentWash, b.accentWash),
      accentPurple: c(a.accentPurple, b.accentPurple),
      accentPurpleStrong: c(a.accentPurpleStrong, b.accentPurpleStrong),
      accentPurpleWash: c(a.accentPurpleWash, b.accentPurpleWash),
      sunny: c(a.sunny, b.sunny),
      sunnyWash: c(a.sunnyWash, b.sunnyWash),
      accentGreen: c(a.accentGreen, b.accentGreen),
      accentGreenWash: c(a.accentGreenWash, b.accentGreenWash),
      accentYellow: c(a.accentYellow, b.accentYellow),
      accentYellowWash: c(a.accentYellowWash, b.accentYellowWash),
      accentRed: c(a.accentRed, b.accentRed),
      accentRedWash: c(a.accentRedWash, b.accentRedWash),
      shadowCard: s(a.shadowCard, b.shadowCard),
      shadowFloat: s(a.shadowFloat, b.shadowFloat),
      shadowCta: s(a.shadowCta, b.shadowCta),
      notes: NotesInk.lerp(a.notes, b.notes, t),
    );
  }
}
