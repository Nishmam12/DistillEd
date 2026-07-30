// The circular knowledge-graph shortcut that floats over a note card's
// preview. Deliberately its own layer: a strong, elevation-like shadow is what
// makes it read as hovering above the card rather than printed on it.

import 'package:flutter/material.dart';

import '../../../../core/theme/ink_colors.dart';
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
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: context.notes.card,
                shape: BoxShape.circle,
                boxShadow: context.notes.floatShadow,
              ),
              child: Icon(
                Icons.hub_rounded,
                size: widget.radius * 0.85,
                color: context.notes.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
