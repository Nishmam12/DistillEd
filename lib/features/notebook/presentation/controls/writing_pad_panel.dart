// The easy writing pad's two halves on screen: the lined pad under the page,
// where ink is written large, and the box on the page it lands in. See
// `editor/state/writing_pad.dart`.

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/commands/scene_command.dart';
import '../../../../domain/model/scene_element.dart';
import '../../../../editor/input/scene_pointer_listener.dart' show reportsPressure;
import '../../../../editor/render/freehand_path.dart';
import '../../../../editor/state/editor_tool_controller.dart';
import '../../../../editor/state/history_controller.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../../../editor/state/viewport_controller.dart';
import '../../../../editor/state/writing_pad.dart';
import '../../../../editor/ui/controls/editor_controls_shared.dart';

/// Opens the pad with its box near the top-left of what is on screen, or
/// closes it.
void toggleWritingPad(WidgetRef ref) {
  final pad = ref.read(writingPadProvider.notifier);
  if (pad.state != null) {
    pad.state = null;
    return;
  }
  final at = ref.read(viewportProvider).toScene(const Offset(48, 48));
  pad.state = WritingPad(target: at, lineStartX: at.dx);
}

class WritingPadPanel extends ConsumerStatefulWidget {
  const WritingPadPanel(
      {super.key, required this.pageKey, required this.paper});

  final ScenePageKey pageKey;

  /// The page's paper colour: the pad looks like the page the ink goes on.
  final Color paper;

  /// How tall the pad is: one line of writing, drawn large.
  static const double height = 180;

  @override
  ConsumerState<WritingPadPanel> createState() => _WritingPadPanelState();
}

class _WritingPadPanelState extends ConsumerState<WritingPadPanel> {
  /// Strokes written in the pad since the box last moved, in pad pixels.
  final List<List<StrokePoint>> _strokes = [];
  List<StrokePoint>? _current;

  double get _inkRight => _strokes.isEmpty
      ? 0
      : _strokes.expand((s) => s).map((p) => p.x).reduce(math.max);

  void _down(PointerDownEvent e) => setState(() => _current = [_point(e)]);

  void _move(PointerMoveEvent e) {
    final current = _current;
    if (current == null) return;
    setState(() => current.add(_point(e)));
  }

  StrokePoint _point(PointerEvent e) {
    final pressure = reportsPressure(e);
    return StrokePoint(
      x: e.localPosition.dx,
      y: e.localPosition.dy,
      pressure: pressure ? e.pressure.clamp(0.01, 1.0) : 0.5,
      simulatePressure: !pressure,
      t: e.timeStamp.inMilliseconds,
      tilt: e.kind == PointerDeviceKind.stylus ||
              e.kind == PointerDeviceKind.invertedStylus
          ? e.tilt
          : 0,
    );
  }

  void _up(double width) {
    final stroke = _current;
    _current = null;
    final pad = ref.read(writingPadProvider);
    if (stroke == null || stroke.length < 2 || pad == null) {
      setState(() {});
      return;
    }
    final tool = ref.read(editorToolProvider);
    final scene = ref.read(sceneControllerProvider(widget.pageKey).notifier);
    ref.read(historyProvider(widget.pageKey).notifier).push(AddElementsCommand([
      FreehandElement(
        id: editorNewId(),
        zOrder: scene.nextZOrder(),
        points: pad.strokeToPage(stroke, WritingPadPanel.height),
        color: tool.color,
        size: tool.size,
        opacity: tool.opacity,
        penKind: tool.penKind,
      ),
    ]));
    setState(() => _strokes.add(stroke));
    // Nearly out of room: carry on further along the line.
    if (_inkRight > width * 0.8) _space();
  }

  void _space() {
    final pad = ref.read(writingPadProvider);
    if (pad == null || _strokes.isEmpty) return;
    ref.read(writingPadProvider.notifier).state =
        pad.advancedPast(_inkRight, WritingPadPanel.height);
    setState(_strokes.clear);
  }

  void _newLine() {
    final pad = ref.read(writingPadProvider);
    if (pad == null) return;
    ref.read(writingPadProvider.notifier).state = pad.newLine();
    setState(_strokes.clear);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tool = ref.watch(editorToolProvider);
    final scale = WritingPadPanel.height /
        (ref.watch(writingPadProvider)?.lineHeight ?? 36);
    return Material(
      color: c.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Write here; tap the page to move the box.',
                      style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ),
                TextButton.icon(
                  key: const ValueKey('padSpace'),
                  onPressed: _space,
                  icon: const Icon(Icons.space_bar, size: 18),
                  label: const Text('Space'),
                ),
                TextButton.icon(
                  key: const ValueKey('padNewLine'),
                  onPressed: _newLine,
                  icon: const Icon(Icons.keyboard_return, size: 18),
                  label: const Text('New line'),
                ),
                IconButton(
                  tooltip: 'Close the writing pad',
                  icon: const Icon(Icons.close),
                  onPressed: () => toggleWritingPad(ref),
                ),
              ],
            ),
            Container(
              height: WritingPadPanel.height,
              color: widget.paper,
              child: LayoutBuilder(builder: (context, box) {
                return Listener(
                  key: const ValueKey('writingPad'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: (_) => _up(box.maxWidth),
                  onPointerCancel: (_) => setState(() => _current = null),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _PadPainter(
                      strokes: [..._strokes, if (_current != null) _current!],
                      size: tool.size * scale,
                      color: tool.color,
                      opacity: tool.opacity,
                      kind: tool.penKind,
                      // A ruled line that shows on light or dark paper.
                      line: (widget.paper.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white)
                          .withValues(alpha: 0.25),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter({
    required this.strokes,
    required this.size,
    required this.color,
    required this.opacity,
    required this.kind,
    required this.line,
  });

  final List<List<StrokePoint>> strokes;
  final double size;
  final int color;
  final double opacity;
  final PenKind kind;
  final Color line;

  @override
  void paint(Canvas canvas, Size area) {
    // The baseline the writing sits on, as on lined paper.
    canvas.drawLine(Offset(0, area.height * 0.78),
        Offset(area.width, area.height * 0.78), Paint()..color = line);
    final paint = FreehandPath.paintFor(kind, color, opacity);
    for (final s in strokes) {
      final path = FreehandPath.build(s, size, isComplete: true, kind: kind);
      if (path != null) canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}

/// The box on the page that the pad's ink lands in.
class WritingPadTargetLayer extends ConsumerWidget {
  const WritingPadTargetLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = ref.watch(writingPadProvider);
    if (pad == null) return const SizedBox.shrink();
    final viewport = ref.watch(viewportProvider);
    final box = viewport.toViewportRect(Rect.fromLTWH(pad.target.dx,
        pad.target.dy, pad.lineHeight * 8, pad.lineHeight));
    return IgnorePointer(
      child: CustomPaint(
        key: const ValueKey('writingPadTarget'),
        size: Size.infinite,
        painter: _TargetPainter(box, context.colors.accent),
      ),
    );
  }
}

class _TargetPainter extends CustomPainter {
  _TargetPainter(this.box, this.color);
  final Rect box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_TargetPainter old) => old.box != box || old.color != color;
}
