// Tactile bouncy tap wrapper that scales down on press and springs back on release.
//
// Gives buttons, chips, and swatches a physical, responsive feel without altering
// their styling or layout geometry.

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final Duration duration;
  final bool enableHaptic;
  final String? tooltip;
  final HitTestBehavior behavior;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.94,
    this.duration = AppMotion.fast,
    this.enableHaptic = true,
    this.tooltip,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.enableHaptic) {
      AppMotion.lightImpact();
    }
    widget.onTap!();
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    if (widget.enableHaptic) {
      AppMotion.mediumImpact();
    }
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = MouseRegion(
      cursor: widget.onTap != null || widget.onLongPress != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: Listener(
        behavior: widget.behavior,
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: GestureDetector(
          behavior: widget.behavior,
          onTap: widget.onTap != null ? _handleTap : null,
          onLongPress: widget.onLongPress != null ? _handleLongPress : null,
          child: AnimatedScale(
            scale: _pressed ? widget.scaleDown : 1.0,
            duration: widget.duration,
            curve: _pressed ? Curves.easeOutCubic : AppMotion.spring,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      result = Tooltip(
        message: widget.tooltip!,
        child: result,
      );
    }

    return result;
  }
}
