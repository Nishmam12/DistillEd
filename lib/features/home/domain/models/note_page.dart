// Isar collection representing a single page within a notebook.

import 'package:isar/isar.dart';

import '../../../../data/migration/legacy_models/imported_content.dart';
import '../../../../data/migration/legacy_models/shape_element.dart';

part 'note_page.g.dart';

@collection
class NotePage {
  Id id = Isar.autoIncrement;

  @Index()
  late int notebookId;

  late int pageIndex;

  late DateTime createdAt;

  // Phase 4: Imported PDF backgrounds and free images
  List<ImportedContent> importedContents = [];
  
  List<ShapeElement> shapes = [];

  late DateTime modifiedAt;
  
  // Cache buster
}
