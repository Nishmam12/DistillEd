// The circular knowledge-graph shortcut that floats over a note card's
// preview. Deliberately its own layer: a strong, elevation-like shadow is what
// makes it read as hovering above the card rather than printed on it.

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../notes_palette.dart';

class KnowledgeGraphButton extends StatefulWidget {
  const KnowledgeGraphButton({
    super.key,
    required this.onTap,
    this.radius = NotesPalette.graphButtonRadius,
    this.tooltip = 'Knowledge graph',
  });

  final VoidCallback onTap;
  final double radius;
  final String tooltip;

  @override
  State<KnowledgeGraphButton> createState() => _KnowledgeGraphButtonState();
}

class _KnowledgeGraphButtonState extends State<KnowledgeGraphButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            // HOME-10. The asymmetry that makes this button read as floating in
            // both modes. In LIGHT a soft shadow lifts it off the thumbnail. In
            // DARK a shadow is invisible against near-black, so the lift is
            // carried by a 1px `accent` ring instead — the button is sitting on
            // an image, so it needs an edge of its own either way.
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: isDark ? Border.all(color: c.accent) : null,
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Icon(
                PhosphorIconsRegular.asterisk,
                size: widget.radius * 0.85,
                color: c.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
