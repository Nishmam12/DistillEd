// Represents one piece of imported content on a note page (PDF background or free image).
import 'package:isar/isar.dart';

part 'imported_content.g.dart';

enum ImportedContentType { pdfBackground, freeImage }

@embedded
class ImportedContent {
  // Identity
  String id = '';           // UUID
  
  int typeId = 0;
  
  @ignore
  ImportedContentType get type => ImportedContentType.values[typeId];
  
  set type(ImportedContentType value) => typeId = value.index;

  // Cache path (relative to docsDir — never store absolute paths, they change between installs)
  String relativeImagePath = '';

  // Source reference (for display only, not required for rendering)
  String sourceDescription = ''; // e.g. "document.pdf — Page 3"

  // Position and transform (only used when type == freeImage)
  double x = 0.0;
  double y = 0.0;
  double width = 0.0;
  double height = 0.0;
  double rotation = 0.0; // radians, clockwise
  double opacity = 1.0;  // 0.0 to 1.0

  // Ordering
  int zOrder = 0; // within ImportedContentLayer, higher = drawn on top

  ImportedContent();

  factory ImportedContent.pdfBackground({
    required String id,
    required String relativeImagePath,
    required String sourceDescription,
  }) => ImportedContent()
      ..id = id
      ..type = ImportedContentType.pdfBackground
      ..relativeImagePath = relativeImagePath
      ..sourceDescription = sourceDescription
      ..x = 0 ..y = 0 ..width = 0 ..height = 0
      ..rotation = 0 ..opacity = 1.0 ..zOrder = 0;

  factory ImportedContent.freeImage({
    required String id,
    required String relativeImagePath,
    required String sourceDescription,
    required double x,
    required double y,
    required double width,
    required double height,
  }) => ImportedContent()
      ..id = id
      ..type = ImportedContentType.freeImage
      ..relativeImagePath = relativeImagePath
      ..sourceDescription = sourceDescription
      ..x = x ..y = y ..width = width ..height = height
      ..rotation = 0 ..opacity = 1.0 ..zOrder = 1;
}
