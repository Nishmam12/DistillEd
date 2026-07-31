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

  /// Groups the pages that arrived together from ONE import (a PDF's pages,
  /// today). Null for a page the user created by hand.
  ///
  /// Exists because "the whole PDF" is a scope the AI features have to be able
  /// to name (see `features/ai/domain/ai_scope.dart`): a 40-page lecture PDF
  /// lands as 40 ordinary pages in a notebook that may also hold the student's
  /// own work, and neither "this page" nor "the whole notebook" is the right
  /// unit to summarize, search, or graph. Indexed so a scope resolves with one
  /// query rather than a full-notebook scan.
  ///
  /// The value is minted per import (`SceneImportService.newImportGroupId`) and
  /// is opaque — nothing parses it. [importSourceName] carries the human label.
  @Index()
  String? importGroupId;

  /// Display name of the file this page was imported from, e.g. `lecture.pdf`.
  /// Null for hand-made pages. Kept beside [importGroupId] so a scope menu can
  /// say "Whole PDF (lecture.pdf)" without re-reading the image metadata.
  String? importSourceName;

  late DateTime createdAt;

  // Phase 4: Imported PDF backgrounds and free images
  List<ImportedContent> importedContents = [];
  
  List<ShapeElement> shapes = [];

  late DateTime modifiedAt;
  
  // Cache buster
}
