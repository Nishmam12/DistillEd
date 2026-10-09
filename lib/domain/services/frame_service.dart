// Frames are named rectangular containers. Membership is geometric (no stored
// frameId): an element belongs to a frame when its centre falls inside the
// frame's bounds. This keeps the element model unchanged — only [FrameElement]
// is new — while still giving the two behaviours that make frames useful:
//   * moving a frame moves the elements it contains, and
//   * a frame clips the elements it contains when rendered.
//
// All methods are pure; the caller persists results through the controller.

import 'dart:ui';

import '../geometry/scene_geometry.dart';
import '../model/scene_element.dart';

class FrameService {
  FrameService._();

  static List<FrameElement> framesIn(Iterable<SceneElement> els) =>
      els.whereType<FrameElement>().toList();

  /// Non-frame elements captured by [frame] (centre inside its bounds).
  static List<SceneElement> membersOf(
      FrameElement frame, Iterable<SceneElement> els) {
    final r = frame.boundsRect;
    return [
      for (final e in els)
        if (e is! FrameElement && r.contains(SceneGeometry.center(e))) e,
    ];
  }

  /// Maps each member element id → the bounds of the frame that contains it,
  /// used by the renderer to clip members. When an element falls inside several
  /// frames, the topmost (highest zOrder) frame wins.
  static Map<String, Rect> clipBoundsByElement(List<SceneElement> els) {
    final frames = framesIn(els)..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    final out = <String, Rect>{};
    for (final f in frames) {
      final r = f.boundsRect;
      for (final e in els) {
        if (e is FrameElement) continue;
        if (r.contains(SceneGeometry.center(e))) out[e.id] = r;
      }
    }
    return out;
  }

  /// Expands [ids] to also include the members of any frame in the set, so a
  /// drag that grabs a frame moves its contents with it.
  static Set<String> expandWithMembers(
      Set<String> ids, List<SceneElement> els) {
    final byId = {for (final e in els) e.id: e};
    final out = {...ids};
    for (final id in ids) {
      final f = byId[id];
      if (f is FrameElement) {
        out.addAll(membersOf(f, els).map((e) => e.id));
      }
    }
    return out;
  }
}
