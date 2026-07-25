// Pure conversion from the legacy split model (Stroke / ShapeElement /
// ImportedContent) to the unified [SceneElement] model.
//
// z-order fidelity (mirrors the 1.0.2 renderer so a migrated page looks
// identical):
//   * Imported content sits in its own layer *behind* everything, ordered by
//     ImportedContent.zOrder ascending (higher draws on top within that layer).
//   * Strokes and shapes interleave by the CombinedContentLayer order key:
//     stroke key = int.tryParse(id) ?? 0 (µs timestamp), shape key =
//     zOrder * 1000 (ms → µs); ties broken by insertion order (strokes first).
// The combined order is flattened to sequential zOrder values 0..N.

import '../../domain/model/scene_element.dart';
import 'legacy_models/imported_content.dart';
import 'legacy_models/shape_element.dart';
import 'legacy_models/stroke.dart';
import 'legacy_page_data.dart';

class LegacyAdapters {
  LegacyAdapters._();

  static FreehandElement freehandFromStroke(Stroke s, {required int zOrder}) {
    return FreehandElement(
      id: s.id,
      zOrder: zOrder,
      points: s.points, // legacy StrokePoint is the reused model type
      color: s.color,
      size: s.size,
      isEraser: s.isEraser,
      opacity: s.opacity,
    );
  }

  /// textBox → [TextElement]; svgImage → [ImageElement]; everything else →
  /// [SceneShapeElement].
  static SceneElement fromShapeElement(ShapeElement sh, {required int zOrder}) {
    switch (sh.type) {
      case ShapeType.textBox:
        return TextElement(
          id: sh.id,
          zOrder: zOrder,
          rotation: sh.rotation,
          opacity: sh.opacity,
          geometryData: List<double>.from(sh.geometryData),
          text: sh.text,
          color: sh.color,
          fontSize: sh.fontSize,
          fontFamily: sh.fontFamily,
          isBold: sh.isBold,
          isItalic: sh.isItalic,
        );
      case ShapeType.svgImage:
        return ImageElement(
          id: sh.id,
          zOrder: zOrder,
          rotation: sh.rotation,
          opacity: sh.opacity,
          geometryData: List<double>.from(sh.geometryData),
          relativeImagePath: sh.svgRelativePath,
        );
      case ShapeType.line:
      case ShapeType.arrow:
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        return SceneShapeElement(
          id: sh.id,
          zOrder: zOrder,
          rotation: sh.rotation,
          opacity: sh.opacity,
          shapeType: sh.type,
          geometryData: List<double>.from(sh.geometryData),
          color: sh.color,
          strokeWidth: sh.strokeWidth,
          hasFill: sh.hasFill,
          fillColor: sh.fillColor,
          seed: sh.seed,
          roughness: sh.roughness,
          startBindingId: sh.startBindingId,
          endBindingId: sh.endBindingId,
        );
    }
  }

  static ImageElement imageFromImportedContent(
    ImportedContent c, {
    required int zOrder,
  }) {
    final isPdfBackground = c.type == ImportedContentType.pdfBackground;
    return ImageElement(
      id: c.id,
      zOrder: zOrder,
      rotation: c.rotation,
      opacity: c.opacity,
      isLocked: isPdfBackground, // backgrounds are not freely editable
      geometryData: [c.x, c.y, c.x + c.width, c.y + c.height],
      relativeImagePath: c.relativeImagePath,
      sourceDescription: c.sourceDescription,
    );
  }

  /// Converts a whole legacy page to ordered unified elements (see file header
  /// for the z-order rules).
  static List<SceneElement> pageToSceneElements(LegacyPageData page) {
    // Band 0: imported content, ascending by its own zOrder, stable by index.
    final importedOrder =
        List<int>.generate(page.imported.length, (i) => i)
          ..sort((a, b) {
            final c = page.imported[a].zOrder.compareTo(page.imported[b].zOrder);
            return c != 0 ? c : a.compareTo(b);
          });

    // Band 1: strokes + shapes interleaved by renderer order key.
    final band1 = <_OrderedLegacy>[];
    int seq = 0;
    for (final s in page.strokes) {
      band1.add(_OrderedLegacy(int.tryParse(s.id) ?? 0, seq++, stroke: s));
    }
    for (final sh in page.shapes) {
      band1.add(_OrderedLegacy(sh.zOrder * 1000, seq++, shape: sh));
    }
    band1.sort((a, b) {
      final c = a.key.compareTo(b.key);
      return c != 0 ? c : a.seq.compareTo(b.seq);
    });

    final result = <SceneElement>[];
    int z = 0;
    for (final i in importedOrder) {
      result.add(imageFromImportedContent(page.imported[i], zOrder: z++));
    }
    for (final item in band1) {
      if (item.stroke != null) {
        result.add(freehandFromStroke(item.stroke!, zOrder: z++));
      } else {
        result.add(fromShapeElement(item.shape!, zOrder: z++));
      }
    }
    return result;
  }
}

class _OrderedLegacy {
  final int key;
  final int seq;
  final Stroke? stroke;
  final ShapeElement? shape;
  _OrderedLegacy(this.key, this.seq, {this.stroke, this.shape});
}
