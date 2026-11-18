// Rendering configuration constants for each template type.

import 'package:flutter/material.dart';

import '../../domain/model/template_type.dart';

class TemplateConfig {
  final double lineSpacing;
  final double dotSpacing;
  final double dotRadius;
  final double lineWidth;
  final double majorLineWidth;
  final int majorLineInterval;
  final Color lineColor;
  final Color majorLineColor;
  final Color marginLineColor;
  final double marginOffset;

  const TemplateConfig({
    this.lineSpacing = 32.0,
    this.dotSpacing = 24.0,
    this.dotRadius = 1.5,
    this.lineWidth = 0.5,
    this.majorLineWidth = 0.8,
    this.majorLineInterval = 5,
    this.lineColor = const Color(0xFFD0D7DE),
    this.majorLineColor = const Color(0xFFB0B8C1),
    this.marginLineColor = const Color(0xFFCF6679),
    this.marginOffset = 80.0,
  });

  /// Light background template config.
  factory TemplateConfig.forLight(TemplateType type) {
    // Spacings use their pattern's look; [forBackground] scales them. A
    // planner is drawn with the Cornell page's lines.
    if (type.family != type) return TemplateConfig.forLight(type.family);
    if (type == TemplateType.weeklyPlanner ||
        type == TemplateType.monthlyPlanner) {
      return TemplateConfig.forLight(TemplateType.cornell);
    }
    switch (type) {
      case TemplateType.blank:
        return const TemplateConfig();
      case TemplateType.ruled:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFFD0D7DE),
          marginLineColor: Color(0xFFCF6679),
          marginOffset: 80.0,
        );
      case TemplateType.dotted:
        return const TemplateConfig(
          dotSpacing: 24.0,
          dotRadius: 1.5,
          lineColor: Color(0xFFC0C8D0),
        );
      case TemplateType.grid:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFFD0D7DE),
        );
      case TemplateType.engineeringGrid:
        return const TemplateConfig(
          lineSpacing: 16.0,
          lineWidth: 0.3,
          lineColor: Color(0xFFE0E4E8),
          majorLineWidth: 0.8,
          majorLineColor: Color(0xFFB0B8C1),
          majorLineInterval: 5,
        );
      case TemplateType.cornell:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFFD0D7DE),
          majorLineColor: Color(0xFF9AA4AF),
          majorLineWidth: 1.0,
        );
      case TemplateType.music:
        // lineSpacing is the gap between the five lines of a staff.
        return const TemplateConfig(
          lineSpacing: 10.0,
          lineWidth: 0.6,
          lineColor: Color(0xFFA9B2BC),
        );
      case TemplateType.isometric:
        return const TemplateConfig(
          dotSpacing: 24.0,
          dotRadius: 1.4,
          lineColor: Color(0xFFC0C8D0),
        );
      case TemplateType.checklist:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFFD0D7DE),
          majorLineColor: Color(0xFF9AA4AF),
          majorLineWidth: 0.8,
        );
      case TemplateType.ruledNarrow ||
            TemplateType.ruledWide ||
            TemplateType.gridSmall ||
            TemplateType.gridLarge ||
            TemplateType.dottedSmall ||
            TemplateType.dottedLarge ||
            TemplateType.weeklyPlanner ||
            TemplateType.monthlyPlanner:
        throw StateError('handled above');
    }
  }

  /// Dark background template config — lower contrast to avoid eye strain.
  factory TemplateConfig.forDark(TemplateType type) {
    // Spacings use their pattern's look; [forBackground] scales them. A
    // planner is drawn with the Cornell page's lines.
    if (type.family != type) return TemplateConfig.forDark(type.family);
    if (type == TemplateType.weeklyPlanner ||
        type == TemplateType.monthlyPlanner) {
      return TemplateConfig.forDark(TemplateType.cornell);
    }
    switch (type) {
      case TemplateType.blank:
        return const TemplateConfig();
      case TemplateType.ruled:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFF30363D),
          marginLineColor: Color(0xFF8B3A3A),
          marginOffset: 80.0,
        );
      case TemplateType.dotted:
        return const TemplateConfig(
          dotSpacing: 24.0,
          dotRadius: 1.5,
          lineColor: Color(0xFF3A424D),
        );
      case TemplateType.grid:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFF30363D),
        );
      case TemplateType.engineeringGrid:
        return const TemplateConfig(
          lineSpacing: 16.0,
          lineWidth: 0.3,
          lineColor: Color(0xFF262C33),
          majorLineWidth: 0.8,
          majorLineColor: Color(0xFF3A424D),
          majorLineInterval: 5,
        );
      case TemplateType.cornell:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFF30363D),
          majorLineColor: Color(0xFF4A535E),
          majorLineWidth: 1.0,
        );
      case TemplateType.music:
        return const TemplateConfig(
          lineSpacing: 10.0,
          lineWidth: 0.6,
          lineColor: Color(0xFF4A535E),
        );
      case TemplateType.isometric:
        return const TemplateConfig(
          dotSpacing: 24.0,
          dotRadius: 1.4,
          lineColor: Color(0xFF3A424D),
        );
      case TemplateType.checklist:
        return const TemplateConfig(
          lineSpacing: 32.0,
          lineWidth: 0.5,
          lineColor: Color(0xFF30363D),
          majorLineColor: Color(0xFF4A535E),
          majorLineWidth: 0.8,
        );
      case TemplateType.ruledNarrow ||
            TemplateType.ruledWide ||
            TemplateType.gridSmall ||
            TemplateType.gridLarge ||
            TemplateType.dottedSmall ||
            TemplateType.dottedLarge ||
            TemplateType.weeklyPlanner ||
            TemplateType.monthlyPlanner:
        throw StateError('handled above');
    }
  }

  /// Returns the appropriate config based on whether the background is dark.
  factory TemplateConfig.forBackground(TemplateType type, Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    final config = brightness == Brightness.dark
        ? TemplateConfig.forDark(type)
        : TemplateConfig.forLight(type);
    return config.scaled(type.spacing.scale);
  }

  /// The same look with lines and dots [factor] times as far apart.
  TemplateConfig scaled(double factor) => factor == 1
      ? this
      : TemplateConfig(
          lineSpacing: lineSpacing * factor,
          dotSpacing: dotSpacing * factor,
          dotRadius: dotRadius,
          lineWidth: lineWidth,
          majorLineWidth: majorLineWidth,
          majorLineInterval: majorLineInterval,
          lineColor: lineColor,
          majorLineColor: majorLineColor,
          marginLineColor: marginLineColor,
          marginOffset: marginOffset,
        );
}
