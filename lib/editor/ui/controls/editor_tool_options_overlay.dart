// Floating, temporary options panel for whichever tool is active
// (pen/eraser/shape/text) — a squircle card that slides down and fades in
// the moment its tool is (re-)selected, then slides back up out of the way
// the instant the user starts actually using it on the page (see
// [EditorToolController.closePanel], called from the canvas on the first
// touch of a stroke/shape/erase gesture). Tools with no options of their own
// (select/laser/hand/frame) render nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/editor_constants.dart';
import '../../../domain/model/scene_element.dart';
import '../../state/editor_tool_controller.dart';

/// Deliberately *not* part of [EditorBottomBar]'s own layout: callers place it
/// as an overlay in a [Stack] above the canvas instead, so opening or closing
/// it never resizes — and so never visibly shifts — the canvas underneath a
/// page the user may be mid-stroke on.
class EditorToolOptionsOverlay extends ConsumerWidget {
  /// Which edge of the [Stack] the panel is anchored to, so it slides away
  /// *towards* its trigger rather than through the middle of the canvas: the
  /// real editor docks its toolbar above the canvas (anchor the panel to the
  /// top, slide up to hide — the default); the dev playground docks it below
  /// (anchor to the bottom, slide down to hide instead).
  final bool anchorBottom;

  const EditorToolOptionsOverlay({super.key, this.anchorBottom = false});

  /// Fixed rather than filling available width — a compact floating card
  /// (matching the platform's own dropdown menus), not an edge-to-edge bar.
  static const double _panelWidth = 340.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorToolProvider);
    final ctl = ref.read(editorToolProvider.notifier);

    final Widget? content = switch (state.tool) {
      EditorTool.pen => _PenPanel(state: state, ctl: ctl),
      EditorTool.eraser => _EraserPanel(state: state, ctl: ctl),
      EditorTool.shape => _ShapePanel(state: state, ctl: ctl),
      EditorTool.text => _TextPanel(state: state, ctl: ctl),
      _ => null,
    };
    if (content == null) return const SizedBox.shrink();

    final open = state.panelOpen;
    final closedOffset = Offset(0, anchorBottom ? 1.2 : -1.2);
    return IgnorePointer(
      key: const ValueKey('editorToolOptionsIgnorePointer'),
      // Hidden means visually gone *and* untouchable — otherwise a closed
      // panel would still steal the first tap meant for the canvas beneath it.
      ignoring: !open,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: open ? Curves.easeOutCubic : Curves.easeInCubic,
        offset: open ? Offset.zero : closedOffset,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: open ? 200 : 150),
          opacity: open ? 1 : 0,
          child: Container(
            key: const ValueKey('editorToolOptionsPanelSurface'),
            width: _panelWidth,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: ShapeDecoration(
              color: AppColors.surface,
              shadows: AppColors.shadowFloat,
              // A "squircle" (Apple's continuous-corner rectangle) rather
              // than an ordinary rounded rect, matching the platform's own
              // floating dropdown menus.
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A labelled slider row shared by every tool panel — an icon, the slider
/// itself, and a compact readout of the current value.
class _PanelSlider extends StatelessWidget {
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double) label;

  const _PanelSlider({
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 18),
        ),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 36, child: Text(label(value), textAlign: TextAlign.end)),
      ],
    );
  }
}

/// A leading-icon row whose control scrolls horizontally if it doesn't fit —
/// shared by the panel rows built from a [SegmentedButton].
Widget _panelRow(IconData icon, Widget control) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 18),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: control,
          ),
        ),
      ],
    ),
  );
}

String _percentLabel(double v) => '${(v * 100).round()}%';
String _roundedLabel(double v) => v.round().toString();

/// Pen options: a reserved slot for future brush types (only "Pen" exists
/// today), thickness and opacity.
class _PenPanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _PenPanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: ChoiceChip(
            showCheckmark: false,
            label: const Icon(Icons.brush, size: 18),
            tooltip: 'Pen',
            selected: true,
            onSelected: (_) {},
          ),
        ),
        _PanelSlider(
          icon: Icons.line_weight,
          value: state.size,
          min: 1,
          max: 24,
          onChanged: ctl.setSize,
          label: _roundedLabel,
        ),
        _PanelSlider(
          icon: Icons.opacity,
          value: state.opacity,
          min: 0.1,
          max: 1,
          onChanged: ctl.setOpacity,
          label: _percentLabel,
        ),
      ],
    );
  }
}

/// Eraser options: explicit pixel/stroke mode chips and thickness. Mode used
/// to also be toggled by re-tapping the active eraser icon; that shortcut is
/// gone now that this panel gives it an explicit control.
class _EraserPanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _EraserPanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        // Wraps rather than a fixed Row: the panel is now a compact
        // fixed-width floating card, narrower than the old full-width inline
        // bar these chips were sized for, so a two-line wrap on narrow
        // widths beats either overflowing or hiding a chip off-screen.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              showCheckmark: false,
              label: const Text('Pixel eraser'),
              selected: state.eraserPixel,
              onSelected: (_) => ctl.setEraserPixel(true),
            ),
            ChoiceChip(
              showCheckmark: false,
              label: const Text('Stroke eraser'),
              selected: !state.eraserPixel,
              onSelected: (_) => ctl.setEraserPixel(false),
            ),
          ],
        ),
        _PanelSlider(
          icon: Icons.line_weight,
          value: state.size,
          min: 1,
          max: 24,
          onChanged: ctl.setSize,
          label: _roundedLabel,
        ),
      ],
    );
  }
}

/// Shape options: the shape-type picker (moved in from its old standalone
/// row), thickness, opacity, and the stroke/edge/fill styling (moved in from
/// the pen panel — dashed/dotted strokes and rounded corners are a shapes
/// concept, not something a freehand pen stroke renders). Colour lives in the
/// one universal palette (top-right of the canvas) rather than a swatch row
/// of its own.
class _ShapePanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _ShapePanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          children: [
            for (final (type, icon) in kEditorShapes)
              ChoiceChip(
                showCheckmark: false,
                label: Icon(icon, size: 18),
                selected: state.shapeType == type,
                onSelected: (_) => ctl.setShapeType(type),
              ),
          ],
        ),
        _PanelSlider(
          icon: Icons.line_weight,
          value: state.size,
          min: 1,
          max: 24,
          onChanged: ctl.setSize,
          label: _roundedLabel,
        ),
        _PanelSlider(
          icon: Icons.opacity,
          value: state.opacity,
          min: 0.1,
          max: 1,
          onChanged: ctl.setOpacity,
          label: _percentLabel,
        ),
        _panelRow(
          Icons.line_style,
          SegmentedButton<StrokeStyle>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: StrokeStyle.solid, label: Text('Solid')),
              ButtonSegment(value: StrokeStyle.dashed, label: Text('Dashed')),
              ButtonSegment(value: StrokeStyle.dotted, label: Text('Dotted')),
            ],
            selected: {state.strokeStyle},
            onSelectionChanged: (s) => ctl.setStrokeStyle(s.first),
          ),
        ),
        _panelRow(
          Icons.rounded_corner,
          SegmentedButton<EdgeStyle>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: EdgeStyle.sharp, label: Text('Sharp')),
              ButtonSegment(value: EdgeStyle.round, label: Text('Round')),
            ],
            selected: {state.edges},
            onSelectionChanged: (s) => ctl.setEdges(s.first),
          ),
        ),
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.format_color_fill, size: 18),
            ),
            const Spacer(),
            Switch(value: state.hasFill, onChanged: ctl.setHasFill),
          ],
        ),
        if (state.hasFill)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            // Compact style (shrunk padding/font/tap target) rather than the
            // default segmented-button size — at default size "Hachure" /
            // "Cross" / "Solid" together ran past the edge of this (now
            // fixed-width) floating panel; shrinking the pill itself, not
            // just giving it its own row, is what actually keeps it inside
            // the panel's own rounded boundary instead of overflowing or
            // relying on a hidden horizontal scroll. The scroll view is a
            // safety net only — under normal text scaling it never needs to
            // scroll.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<FillStyle>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(fontSize: 11),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                      value: FillStyle.hachure, label: Text('Hachure')),
                  ButtonSegment(
                      value: FillStyle.crossHatch, label: Text('Cross')),
                  ButtonSegment(value: FillStyle.solid, label: Text('Solid')),
                ],
                selected: {state.fillStyle},
                onSelectionChanged: (s) => ctl.setFillStyle(s.first),
              ),
            ),
          ),
      ],
    );
  }
}

/// Text options: font family and font size, replacing the old sheet's single
/// shared font-size slider with a panel of its own.
class _TextPanel extends StatelessWidget {
  final EditorToolState state;
  final EditorToolController ctl;
  const _TextPanel({required this.state, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.font_download_outlined, size: 18),
            ),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: state.fontFamily,
                items: [
                  for (final f in kFontFamilies)
                    DropdownMenuItem(
                      value: f,
                      child: Text(f, style: TextStyle(fontFamily: f)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) ctl.setFontFamily(v);
                },
              ),
            ),
          ],
        ),
        _PanelSlider(
          icon: Icons.format_size,
          value: state.fontSize,
          min: 10,
          max: 72,
          onChanged: ctl.setFontSize,
          label: _roundedLabel,
        ),
      ],
    );
  }
}
