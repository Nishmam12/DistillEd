// Links of an imported PDF page, and of elements linked to another page,
// notebook or web address (`SceneElement.link`), tappable while the hand tool,
// or the select tool's Text mode, is in use.
//
// A layer over the page, not part of the pointer pipeline: one translucent
// listener sees every touch and still lets it through, so the pen, panning and
// the pipeline's palm rejection underneath see exactly what they did before.
// Because a contents page is wall-to-wall links, this layer also guards its own
// taps: a touch is ignored while a stylus is down or just lifted, when it
// moves, when it lasts, or when it is one of several fingers. The pen never
// follows a link: nothing is shown or tappable in any drawing tool.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/geometry/element_bounds.dart';
import '../../domain/geometry/word_geometry.dart';
import '../../domain/model/page_links.dart';
import '../../domain/model/scene_element.dart';
import '../../features/import/page_links_service.dart';
import '../state/editor_tool_controller.dart';
import '../state/scene_controller.dart';
import '../state/viewport_controller.dart';

/// How far outside a link a tap still counts as on it, on screen.
const double kLinkTapSlop = 14;

/// Longest a contact may last and still be a tap.
const Duration kLinkTapMaxDuration = Duration(milliseconds: 300);

/// How long after a stylus a touch is taken for a resting palm.
const Duration kLinkPalmGrace = Duration(milliseconds: 600);

/// How far a finger may drift and still be tapping.
const double kLinkTapDrift = 12;

/// Which of [boxes] a tap at [at] is for: the smallest box that contains it, or
/// failing that the nearest one within [slop]. Null when none is close.
int? resolveLinkTap(List<Rect> boxes, Offset at, {double slop = kLinkTapSlop}) {
  int? best;
  var bestArea = double.infinity;
  for (var i = 0; i < boxes.length; i++) {
    if (boxes[i].contains(at) && boxes[i].width * boxes[i].height < bestArea) {
      best = i;
      bestArea = boxes[i].width * boxes[i].height;
    }
  }
  if (best != null) return best;
  var nearest = slop;
  for (var i = 0; i < boxes.length; i++) {
    final b = boxes[i];
    final dx = at.dx < b.left ? b.left - at.dx : at.dx > b.right ? at.dx - b.right : 0.0;
    final dy = at.dy < b.top ? b.top - at.dy : at.dy > b.bottom ? at.dy - b.bottom : 0.0;
    final d = Offset(dx, dy).distance;
    if (d <= nearest) {
      nearest = d;
      best = i;
    }
  }
  return best;
}

class PdfLinkLayer extends ConsumerStatefulWidget {
  final ScenePageKey pageKey;

  /// Called with the link tapped and the picture it is on.
  final void Function(PageLink link, String imagePath) onFollow;

  /// Called with the stored link of a linked element that was tapped.
  final void Function(String link)? onFollowElement;

  const PdfLinkLayer({
    super.key,
    required this.pageKey,
    required this.onFollow,
    this.onFollowElement,
  });

  /// Whether the tool in use is one that follows links.
  static bool followsLinks(EditorToolState tool) =>
      tool.tool == EditorTool.hand ||
      (tool.tool == EditorTool.select && tool.selectText);

  @override
  ConsumerState<PdfLinkLayer> createState() => _PdfLinkLayerState();
}

typedef _Target = ({Rect box, VoidCallback follow});

class _PdfLinkLayerState extends ConsumerState<PdfLinkLayer> {
  List<_Target> _targets = const [];

  // Contacts in progress, for telling a tap from the rest.
  final Map<int, ({Offset at, Duration time, PointerDeviceKind kind})> _down = {};
  final Set<int> _spoiled = {};
  int _stylusDown = 0;
  Duration? _stylusSeen;

  @override
  Widget build(BuildContext context) {
    if (!PdfLinkLayer.followsLinks(ref.watch(editorToolProvider))) {
      _targets = const [];
      return const SizedBox.shrink();
    }
    final viewport = ref.watch(viewportProvider);
    final targets = <_Target>[];
    final elements = ref.watch(sceneControllerProvider(widget.pageKey));
    final followElement = widget.onFollowElement;
    if (followElement != null) {
      for (final e in elements) {
        if (e.link.isEmpty) continue;
        final box = viewport.toViewportRect(ElementBounds.of(e));
        if (box.width == 0 && box.height == 0) continue; // a dot-sized nothing
        targets.add((box: box, follow: () => followElement(e.link)));
      }
    }
    for (final image in elements.whereType<ImageElement>()) {
      // Only pictures of PDF pages can have links.
      if (siblingPdfPagePath(image.relativeImagePath, 1) == null) continue;
      final links = ref.watch(pageLinksProvider(image.relativeImagePath)).value;
      for (final link in links?.links ?? const <PageLink>[]) {
        Rect? box;
        for (final c in cornersOnPage(link.rect, image)) {
          final p = viewport.toViewport(c);
          box = box == null
              ? Rect.fromPoints(p, p)
              : box.expandToInclude(Rect.fromPoints(p, p));
        }
        if (box == null) continue;
        final imagePath = image.relativeImagePath;
        targets.add((box: box, follow: () => widget.onFollow(link, imagePath)));
      }
    }
    _targets = targets;
    if (targets.isEmpty) return const SizedBox.shrink();

    return Listener(
      key: const Key('pdfLinkLayer'),
      // Translucent: the canvas underneath still gets every touch.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (e) {
        _down.remove(e.pointer);
        _spoiled.remove(e.pointer);
        if (e.kind == PointerDeviceKind.stylus) _stylusDown = 0;
      },
      child: IgnorePointer(
        child: CustomPaint(
          painter: _UnderlinePainter(
              [for (final t in targets) t.box], context.colors.accent),
          size: Size.infinite,
        ),
      ),
    );
  }

  void _onDown(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.stylus) {
      _stylusDown++;
      _stylusSeen = e.timeStamp;
    }
    // A second finger is a pinch or a palm, never a tap: none of them count.
    if (_down.isNotEmpty) _spoiled.addAll([..._down.keys, e.pointer]);
    _down[e.pointer] =
        (at: e.localPosition, time: e.timeStamp, kind: e.kind);
  }

  void _onMove(PointerMoveEvent e) {
    final d = _down[e.pointer];
    if (d == null) return;
    if (e.kind == PointerDeviceKind.stylus) _stylusSeen = e.timeStamp;
    if ((e.localPosition - d.at).distance > kLinkTapDrift) {
      _spoiled.add(e.pointer);
    }
  }

  void _onUp(PointerUpEvent e) {
    final d = _down.remove(e.pointer);
    final spoiled = _spoiled.remove(e.pointer);
    if (e.kind == PointerDeviceKind.stylus) {
      _stylusDown = _stylusDown > 0 ? _stylusDown - 1 : 0;
      _stylusSeen = e.timeStamp;
    }
    if (d == null || spoiled) return;
    if (e.timeStamp - d.time > kLinkTapMaxDuration) return;
    // A touch while a stylus is down, or just after one lifted: a resting palm.
    if (d.kind == PointerDeviceKind.touch) {
      final seen = _stylusSeen;
      if (_stylusDown > 0 ||
          (seen != null && e.timeStamp - seen < kLinkPalmGrace)) {
        return;
      }
    }
    final hit = resolveLinkTap([for (final t in _targets) t.box], e.localPosition);
    if (hit == null) return;
    _targets[hit].follow();
  }
}

class _UnderlinePainter extends CustomPainter {
  final List<Rect> boxes;
  final Color color;
  _UnderlinePainter(this.boxes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    for (final b in boxes) {
      canvas.drawLine(b.bottomLeft, b.bottomRight, paint);
    }
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) =>
      old.color != color || old.boxes.length != boxes.length ||
      !identical(old.boxes, boxes);
}
