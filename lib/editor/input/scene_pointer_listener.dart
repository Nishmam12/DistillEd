// Raw pointer pipeline for the unified canvas — a faithful port of the proven
// 1.0.2 `raw_pointer_listener.dart` palm rejection. Behaviour is identical and
// covered by parity tests; do not change the timing/ordering without updating
// those tests.
//
// Palm rejection is order-independent. A touch is treated as palm and ignored
// when a stylus is on screen OR was active within the last [_palmRejectionGrace].
// When the pen lands after the palm, any touch pointers already down are dropped
// retroactively and their stray stroke is discarded. A hovering stylus pre-arms
// the grace window. Two-finger gestures and the hand tool emit viewport updates
// instead of drawing.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../features/editor/domain/models/stroke_point.dart';

typedef PointerEventCallback = void Function(
    PointerEvent event, StrokePoint point);

/// panDelta — screen-space translation; focalPoint — midpoint of active
/// pointers (screen); scaleDelta — multiplicative zoom (1.0 = no change).
typedef ViewportUpdateCallback = void Function(
  Offset panDelta,
  Offset focalPoint,
  double scaleDelta,
);

class ScenePointerListener extends StatefulWidget {
  final Widget child;
  final bool enablePalmRejection;

  final PointerEventCallback onPointerDown;
  final PointerEventCallback onPointerMove;
  final PointerEventCallback onPointerUp;

  /// Fired when a second pointer arrives mid-stroke; host discards the in-flight
  /// stroke.
  final VoidCallback? onStrokeCancel;

  /// Two-finger pinch/pan and single-finger hand-tool pan.
  final ViewportUpdateCallback? onViewportUpdate;

  /// When true, single-pointer moves pan instead of draw.
  final bool isHandTool;

  const ScenePointerListener({
    super.key,
    required this.child,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    this.enablePalmRejection = true,
    this.onStrokeCancel,
    this.onViewportUpdate,
    this.isHandTool = false,
  });

  @override
  State<ScenePointerListener> createState() => _ScenePointerListenerState();
}

class _ScenePointerListenerState extends State<ScenePointerListener> {
  static const Duration _palmRejectionGrace = Duration(milliseconds: 500);

  final Set<int> _activeStylusPointers = {};
  final Set<int> _rejectedPointers = {};
  final Map<int, Offset> _activePointers = {};
  bool _isMultiTouch = false;
  Duration? _lastStylusActivity;

  bool _shouldRejectTouch(PointerEvent event) {
    if (!widget.enablePalmRejection) return false;
    if (event.kind != PointerDeviceKind.touch) return false;
    if (_activeStylusPointers.isNotEmpty) return true;
    final lastStylus = _lastStylusActivity;
    if (lastStylus != null &&
        event.timeStamp - lastStylus < _palmRejectionGrace) {
      return true;
    }
    return false;
  }

  void _rejectActiveTouchPointers() {
    final touchIds = _activePointers.keys
        .where((id) => !_activeStylusPointers.contains(id))
        .toList();
    if (touchIds.isEmpty) return;

    for (final id in touchIds) {
      _activePointers.remove(id);
      _rejectedPointers.add(id);
    }
    widget.onStrokeCancel?.call();
    if (_activePointers.isEmpty) _isMultiTouch = false;
  }

  StrokePoint _extractPoint(PointerEvent event) {
    final bool simulate = event.pressure == 0.0 || event.pressure == 0.5;
    final double pressure = simulate ? 0.5 : event.pressure.clamp(0.01, 1.0);
    return StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: pressure,
      simulatePressure: simulate,
      // Monotonic engine timestamp (same clock as palm rejection above) — used
      // by handwriting recognition, which only needs deltas between points.
      t: event.timeStamp.inMilliseconds,
    );
  }

  void _emitViewportUpdate(int pointerId, Offset oldPos, Offset newPos) {
    if (widget.onViewportUpdate == null) return;

    final otherIds =
        _activePointers.keys.where((id) => id != pointerId).toList();

    if (otherIds.isNotEmpty) {
      final otherPos = _activePointers[otherIds.first]!;
      final oldDist = (oldPos - otherPos).distance;
      final newDist = (newPos - otherPos).distance;
      final scaleDelta = oldDist > 1.0 ? newDist / oldDist : 1.0;
      final oldFocal = (oldPos + otherPos) / 2;
      final newFocal = (newPos + otherPos) / 2;
      widget.onViewportUpdate!(newFocal - oldFocal, newFocal, scaleDelta);
    } else {
      widget.onViewportUpdate!(newPos - oldPos, newPos, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.stylus) {
          _activeStylusPointers.add(event.pointer);
          _lastStylusActivity = event.timeStamp;
          _rejectActiveTouchPointers();
        }

        if (_shouldRejectTouch(event)) {
          _rejectedPointers.add(event.pointer);
          return;
        }

        final prevCount = _activePointers.length;
        _activePointers[event.pointer] = event.localPosition;

        if (_activePointers.length >= 2 && !_isMultiTouch) {
          _isMultiTouch = true;
          widget.onStrokeCancel?.call();
          return;
        }

        if (_isMultiTouch) return;
        if (widget.isHandTool) return;

        if (prevCount == 0) {
          widget.onPointerDown(event, _extractPoint(event));
        }
      },
      onPointerMove: (event) {
        if (event.kind == PointerDeviceKind.stylus) {
          _lastStylusActivity = event.timeStamp;
        }
        if (_rejectedPointers.contains(event.pointer)) return;

        final oldPos = _activePointers[event.pointer];
        if (oldPos == null) return;

        final newPos = event.localPosition;

        if (_isMultiTouch || widget.isHandTool) {
          _emitViewportUpdate(event.pointer, oldPos, newPos);
          _activePointers[event.pointer] = newPos;
          return;
        }

        _activePointers[event.pointer] = newPos;
        widget.onPointerMove(event, _extractPoint(event));
      },
      onPointerUp: (event) {
        if (event.kind == PointerDeviceKind.stylus) {
          _lastStylusActivity = event.timeStamp;
        }
        _activeStylusPointers.remove(event.pointer);

        if (_rejectedPointers.remove(event.pointer)) return;

        _activePointers.remove(event.pointer);
        if (_activePointers.isEmpty) _isMultiTouch = false;

        if (_isMultiTouch) return;
        if (widget.isHandTool) return;

        widget.onPointerUp(event, _extractPoint(event));
      },
      onPointerCancel: (event) {
        if (event.kind == PointerDeviceKind.stylus) {
          _lastStylusActivity = event.timeStamp;
        }
        _activeStylusPointers.remove(event.pointer);
        _rejectedPointers.remove(event.pointer);
        _activePointers.remove(event.pointer);
        if (_activePointers.isEmpty) _isMultiTouch = false;

        if (_isMultiTouch) return;
        if (widget.isHandTool) return;

        widget.onPointerUp(event, _extractPoint(event));
      },
      onPointerHover: (event) {
        if (event.kind == PointerDeviceKind.stylus) {
          _lastStylusActivity = event.timeStamp;
        }
      },
      child: widget.child,
    );
  }
}
