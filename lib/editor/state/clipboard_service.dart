// Copy/paste of scene elements through the system clipboard, so elements can
// travel between pages (and app instances). This delivers the cross-page
// clipboard deferred from Phase 4 (where duplicate was in-page only).
//
// Elements are stored as JSON text tagged with a type marker, so pasting only
// accepts clipboard text we wrote. The encode/decode and paste-transform are
// pure (and unit-tested); only [copy]/[paste] touch the platform clipboard.

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/persistence/scene_element_codec.dart';
import '../../domain/model/scene_element.dart';
import '../../domain/services/selection_editing.dart';

class ClipboardService {
  ClipboardService._();

  static const String _type = 'margo/scene-elements';

  static String encode(Iterable<SceneElement> elements) => jsonEncode({
        'type': _type,
        'version': 1,
        'elements': SceneElementCodec.encodeList(elements),
      });

  /// Returns the elements encoded in [text], or null if it is not our format.
  static List<SceneElement>? tryDecode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final root = jsonDecode(text);
      if (root is! Map || root['type'] != _type) return null;
      return SceneElementCodec.decodeList((root['elements'] as List?) ?? const []);
    } catch (_) {
      return null;
    }
  }

  /// Re-ids and offsets pasted elements so they don't collide with the originals
  /// (groups are remapped, staying grouped). Caller assigns final z-order.
  static List<SceneElement> pasteTransform(
    List<SceneElement> elements, {
    required Offset offset,
    required String Function() nextId,
  }) =>
      SelectionEditing.duplicate(elements, offset: offset, nextId: nextId);

  // ---- platform clipboard ---------------------------------------------------

  static Future<void> copy(Iterable<SceneElement> elements) =>
      Clipboard.setData(ClipboardData(text: encode(elements)));

  /// Reads the clipboard and returns re-id'd, offset elements ready to add, or
  /// null if the clipboard holds no scene elements.
  static Future<List<SceneElement>?> paste({
    required String Function() nextId,
    Offset offset = const Offset(16, 16),
  }) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final els = tryDecode(data?.text);
    if (els == null || els.isEmpty) return null;
    return pasteTransform(els, offset: offset, nextId: nextId);
  }
}
