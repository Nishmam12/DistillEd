import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Smallest the floating AI panel can be resized to. Narrower than this and
/// its action buttons wrap; shorter and the Ask field leaves no room for an
/// answer.
const Size kFloatingAiPanelMinSize = Size(280, 320);

/// Share of the page area the floating panel may grow to, each way.
const double kFloatingAiPanelMaxShare = 0.9;

/// Gap kept between the panel and the edges of the page area.
const double kFloatingAiPanelMargin = 8;

/// Where the panel first appears: near the top right, clear of the zoom pill
/// and colour swatch that sit in that corner.
Rect defaultFloatingAiPanelRect(Size area) {
  final width = math.min(360.0, area.width * kFloatingAiPanelMaxShare);
  final height = area.height * 0.7;
  return Rect.fromLTWH(
      area.width - width - 72, 16, width, height);
}

/// [rect] made to fit inside [area]: no smaller than the minimum size, no
/// larger than [kFloatingAiPanelMaxShare] of the area, and wholly inside it.
///
/// [keyboard] is how much of the bottom of the area the on-screen keyboard
/// covers. The panel is lifted (and if need be shortened) to stay above it,
/// so the Ask field stays in sight. That only changes where it is SHOWN: the
/// remembered rect is untouched, so the panel goes back when the keyboard
/// closes.
Rect fitFloatingAiPanel(Rect rect, Size area, {double keyboard = 0}) {
  const m = kFloatingAiPanelMargin;
  final usableHeight = math.max(0.0, area.height - math.max(0.0, keyboard));

  double clampSize(double v, double min, double max) =>
      v.clamp(math.min(min, max), max).toDouble();

  final maxW = math.max(0.0, area.width * kFloatingAiPanelMaxShare);
  final maxH = math.max(0.0, area.height * kFloatingAiPanelMaxShare);
  final width = clampSize(rect.width, kFloatingAiPanelMinSize.width, maxW);
  var height = clampSize(rect.height, kFloatingAiPanelMinSize.height, maxH);
  // Above the keyboard it may have to be shorter than its minimum.
  height = math.min(height, math.max(0.0, usableHeight - 2 * m));

  double clampPos(double v, double size, double extent) =>
      v.clamp(m, math.max(m, extent - size - m)).toDouble();

  return Rect.fromLTWH(
    clampPos(rect.left, width, area.width),
    clampPos(rect.top, height, usableHeight),
    width,
    height,
  );
}

/// What the floating panel hands its content: drag the header to move it.
typedef FloatingPanelBuilder = Widget Function(
    BuildContext context, ValueChanged<Offset> onMove, VoidCallback onMoveEnd);

/// The AI panel as a card floating over the page, which can be dragged by its
/// header and resized from its bottom-right corner (finding 10 of the first
/// device test: the docked panel narrowed the page and the tool row).
///
/// Fills the page area it is put in (a [Positioned.fill] in the editor's canvas
/// stack) but only the card takes touches: everywhere else goes through to the
/// page, so writing beside the panel works as usual. The page is never resized
/// for it.
class FloatingAiPanel extends StatefulWidget {
  /// Where the panel was last left, or null for [defaultFloatingAiPanelRect].
  final Rect? rect;

  /// Called once a move or resize ends, with the rect to remember.
  final ValueChanged<Rect> onRectChanged;

  final FloatingPanelBuilder builder;

  const FloatingAiPanel({
    super.key,
    required this.rect,
    required this.onRectChanged,
    required this.builder,
  });

  @override
  State<FloatingAiPanel> createState() => _FloatingAiPanelState();
}

class _FloatingAiPanelState extends State<FloatingAiPanel> {
  /// Where the card was last moved or resized to here. Kept until the
  /// remembered [FloatingAiPanel.rect] changes, so the card never jumps back
  /// while the new rect is being saved.
  Rect? _dragging;

  @override
  void didUpdateWidget(FloatingAiPanel old) {
    super.didUpdateWidget(old);
    if (widget.rect != old.rect) _dragging = null;
  }

  /// How far the page area's bottom sits above the bottom of the screen (the
  /// page bar is below it), so only the part of the keyboard that really
  /// covers the area lifts the panel.
  double _gapBelow = 0;

  final GlobalKey _areaKey = GlobalKey();

  void _measureGap() {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final gap = math.max(0.0, MediaQuery.sizeOf(context).height - bottom);
    if ((gap - _gapBelow).abs() > 0.5) setState(() => _gapBelow = gap);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureGap());
    final keyboard =
        math.max(0.0, MediaQuery.viewInsetsOf(context).bottom - _gapBelow);
    return LayoutBuilder(
      key: _areaKey,
      builder: (context, box) {
        final area = box.biggest;
        // The rect as remembered (fitted to the area, but not to the keyboard)
        // is what a drag starts from and what is saved.
        final base = fitFloatingAiPanel(
            _dragging ?? widget.rect ?? defaultFloatingAiPanelRect(area), area);
        final shown = fitFloatingAiPanel(base, area, keyboard: keyboard);

        // Several moves can arrive before the next build: each builds on the
        // latest rect, not on the one this build started from.
        void move(Offset delta) => setState(() => _dragging =
            fitFloatingAiPanel((_dragging ?? base).shift(delta), area));
        void resize(Offset delta) => setState(() {
              final from = _dragging ?? base;
              _dragging = fitFloatingAiPanel(
                  Rect.fromLTWH(from.left, from.top, from.width + delta.dx,
                      from.height + delta.dy),
                  area);
            });
        void end() {
          final done = _dragging;
          if (done != null) widget.onRectChanged(done);
        }

        return Stack(
          children: [
            Positioned.fromRect(
              key: const ValueKey('floatingAiPanel'),
              rect: shown,
              child: Material(
                color: context.colors.surface,
                elevation: 8,
                shadowColor: Colors.black38,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.colors.border),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.builder(context, move, end)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _ResizeCorner(onDrag: resize, onDragEnd: end),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The grip in the floating panel's bottom-right corner.
class _ResizeCorner extends StatelessWidget {
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  const _ResizeCorner({required this.onDrag, required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Resize AI panel',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          key: const ValueKey('floatingAiPanelResize'),
          // Follow the finger from where it went down, not from past the slop.
          dragStartBehavior: DragStartBehavior.down,
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => onDrag(d.delta),
          onPanEnd: (_) => onDragEnd(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.south_east,
                    size: 16, color: context.colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
