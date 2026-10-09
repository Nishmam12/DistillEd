// Rendering configuration constants for each template type.

import 'package:flutter/material.dart';

import 'template_type.dart';

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
    }
  }

  /// Dark background template config — lower contrast to avoid eye strain.
  factory TemplateConfig.forDark(TemplateType type) {
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
    }
  }

  /// Returns the appropriate config based on whether the background is dark.
  factory TemplateConfig.forBackground(TemplateType type, Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark
        ? TemplateConfig.forDark(type)
        : TemplateConfig.forLight(type);
  }
}
