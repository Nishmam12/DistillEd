// Pure editing helpers for a selection: duplicate, group/ungroup, lock. They
// return new/updated immutable elements; the caller persists via the controller.

import 'dart:ui';

import '../geometry/element_transformer.dart';
import '../model/scene_element.dart';

class SelectionEditing {
  SelectionEditing._();

  /// Duplicates [selected], offsetting each copy by [offset] and giving each a
  /// fresh id. Elements that shared a group get a new shared group, so the
  /// duplicates stay grouped without merging with the originals.
  static List<SceneElement> duplicate(
    Iterable<SceneElement> selected, {
    required Offset offset,
    required String Function() nextId,
  }) {
    final groupRemap = <String, String>{};
    final copies = <SceneElement>[];
    for (final e in selected) {
      final newGroup = e.groupId.isEmpty
          ? ''
          : groupRemap.putIfAbsent(e.groupId, nextId);
      final copy = withGroup(withId(e, nextId()), newGroup);
      copies.add(SceneTransformer.translate(copy, offset));
    }
    return copies;
  }

  static SceneElement withId(SceneElement e, String id) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(id: id);
      case SceneShapeElement():
        return e.copyWith(id: id);
      case TextElement():
        return e.copyWith(id: id);
      case ImageElement():
        return e.copyWith(id: id);
      case FrameElement():
        return e.copyWith(id: id);
      case TapeElement():
        return e.copyWith(id: id);
    }
  }

  /// [e] linking to [link] (`element_link.dart`; '' for none).
  static SceneElement withLink(SceneElement e, String link) => switch (e) {
        FreehandElement() => e.copyWith(link: link),
        SceneShapeElement() => e.copyWith(link: link),
        TextElement() => e.copyWith(link: link),
        ImageElement() => e.copyWith(link: link),
        FrameElement() => e.copyWith(link: link),
        TapeElement() => e.copyWith(link: link),
      };

  static SceneElement withGroup(SceneElement e, String groupId) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(groupId: groupId);
      case SceneShapeElement():
        return e.copyWith(groupId: groupId);
      case TextElement():
        return e.copyWith(groupId: groupId);
      case ImageElement():
        return e.copyWith(groupId: groupId);
      case FrameElement():
        return e.copyWith(groupId: groupId);
      case TapeElement():
        return e.copyWith(groupId: groupId);
    }
  }

  /// Whether [e] has a stroke or text colour to change (not an image or frame).
  static bool hasColor(SceneElement e) =>
      e is FreehandElement ||
      e is SceneShapeElement ||
      e is TextElement ||
      e is TapeElement;

  /// Whether [e] has a line thickness to change (ink and shapes).
  static bool hasThickness(SceneElement e) =>
      e is FreehandElement || e is SceneShapeElement;

  /// [e] in [argb]: the ink, line or text colour. Others are returned as is.
  static SceneElement withColor(SceneElement e, int argb) => switch (e) {
        FreehandElement() => e.copyWith(color: argb),
        SceneShapeElement() => e.copyWith(color: argb),
        TextElement() => e.copyWith(color: argb),
        TapeElement() => e.copyWith(color: argb),
        _ => e,
      };

  /// [e] with its line [width]: a stroke's size or a shape's line width.
  static SceneElement withThickness(SceneElement e, double width) => switch (e) {
        FreehandElement() => e.copyWith(size: width),
        SceneShapeElement() => e.copyWith(strokeWidth: width),
        _ => e,
      };

  /// The line thickness of [e], or null when it has none.
  static double? thicknessOf(SceneElement e) => switch (e) {
        FreehandElement() => e.size,
        SceneShapeElement() => e.strokeWidth,
        _ => null,
      };

  static SceneElement withLocked(SceneElement e, bool locked) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(isLocked: locked);
      case SceneShapeElement():
        return e.copyWith(isLocked: locked);
      case TextElement():
        return e.copyWith(isLocked: locked);
      case ImageElement():
        return e.copyWith(isLocked: locked);
      case FrameElement():
        return e.copyWith(isLocked: locked);
      case TapeElement():
        return e.copyWith(isLocked: locked);
    }
  }
}
