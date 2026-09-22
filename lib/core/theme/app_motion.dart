// Unified motion tokens and tactile feedback utilities for InkFlow.
//
// Follows the "warm & friendly" design language: springy, physical deceleration
// curves, consistent durations, and subtle haptic feedback on interactive surfaces.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppMotion {
  AppMotion._();

  // ── Animation Durations ────────────────────────────────────
  /// Micro-animations (button press bounce, color swatch selection, icon pops).
  static const Duration instant = Duration(milliseconds: 110);

  /// Quick feedback (chip toggles, small sliders, tool selection).
  static const Duration fast = Duration(milliseconds: 180);

  /// Standard transitions (dropdowns, tool options overlay, panel switching).
  static const Duration standard = Duration(milliseconds: 260);

  /// Smooth layout shifts (docked sidebar slide, bottom sheet size change).
  static const Duration smooth = Duration(milliseconds: 340);

  /// Route/page transitions and 3D card flips.
  static const Duration pageTransition = Duration(milliseconds: 380);

  /// Full 3D flashcard flip duration.
  static const Duration flip = Duration(milliseconds: 400);

  // ── Animation Curves ───────────────────────────────────────
  /// Snappy spring-like deceleration with subtle overshoot for press releases and pops.
  static const Curve spring = Curves.easeOutBack;

  /// Expressive cubic curve for natural material deceleration.
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Subtle ease-out for enter transitions (slide in, fade in).
  static const Curve enter = Curves.easeOutCubic;

  /// Crisp ease-in for exit transitions (slide out, fade out).
  static const Curve exit = Curves.easeInCubic;

  /// Smooth bidirectional transitions.
  static const Curve standardCurve = Curves.easeInOutCubic;

  // ── Tactile Haptic Feedback ────────────────────────────────
  /// Subtle tick on button press or icon tap.
  static void lightImpact() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      // Safe fallback on unsupported platforms (desktop/web)
    }
  }

  /// Click feel on toggles, segment changes, or swatch selection.
  static void selectionClick() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {
      // Safe fallback
    }
  }

  /// Medium tap on action confirmations or quiz check.
  static void mediumImpact() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {
      // Safe fallback
    }
  }
}
