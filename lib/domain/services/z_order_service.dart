// Z-order operations on the unified scene. Each returns a NEW element list with
// contiguous zOrder values (0..n-1) reflecting the new stacking.

import '../model/scene_element.dart';

class ZOrderService {
  ZOrderService._();

  static List<SceneElement> bringToFront(List<SceneElement> els, Set<String> ids) {
    final ordered = _sorted(els);
    final sel = ordered.where((e) => ids.contains(e.id));
    final rest = ordered.where((e) => !ids.contains(e.id));
    return _reindex([...rest, ...sel]);
  }

  static List<SceneElement> sendToBack(List<SceneElement> els, Set<String> ids) {
    final ordered = _sorted(els);
    final sel = ordered.where((e) => ids.contains(e.id));
    final rest = ordered.where((e) => !ids.contains(e.id));
    return _reindex([...sel, ...rest]);
  }

  static List<SceneElement> _sorted(List<SceneElement> els) =>
      [...els]..sort((a, b) => a.zOrder.compareTo(b.zOrder));

  static List<SceneElement> _reindex(List<SceneElement> ordered) => [
        for (int i = 0; i < ordered.length; i++) withZOrder(ordered[i], i),
      ];

  static SceneElement withZOrder(SceneElement e, int z) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(zOrder: z);
      case SceneShapeElement():
        return e.copyWith(zOrder: z);
      case TextElement():
        return e.copyWith(zOrder: z);
      case ImageElement():
        return e.copyWith(zOrder: z);
      case FrameElement():
        return e.copyWith(zOrder: z);
    }
  }
}
