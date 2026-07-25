// Plain (Isar-free) snapshot of one legacy page's content, used as the input to
// the v2 migrator. Kept dependency-free so adapter/migrator tests need no
// native Isar.

import 'legacy_models/imported_content.dart';
import 'legacy_models/shape_element.dart';
import 'legacy_models/stroke.dart';

class LegacyPageData {
  final int notebookId;
  final int pageId; // NotePage.id (the .ink file key)
  final List<Stroke> strokes;
  final List<ShapeElement> shapes;
  final List<ImportedContent> imported;

  const LegacyPageData({
    required this.notebookId,
    required this.pageId,
    this.strokes = const [],
    this.shapes = const [],
    this.imported = const [],
  });
}
