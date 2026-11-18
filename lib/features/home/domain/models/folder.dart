// A folder of notebooks — the course/subject container students organise by.
//
// Folders nest (a course, then its units), up to [kMaxFolderDepth] levels, as
// Samsung Notes caps them; the tree rules are in `folder_tree.dart`.
// Notebooks point at a folder by nullable id (see [Notebook.folderId]) rather
// than the folder holding a list, so deleting a folder leaves its notes intact
// and simply unfiled.

import 'package:isar_community/isar.dart';

part 'folder.g.dart';

@collection
class Folder {
  Id id = Isar.autoIncrement;

  late String name;

  late DateTime createdAt;

  /// Manual ordering on the home screen; ties fall back to name.
  int sortIndex = 0;

  /// The folder this one sits in; null at the top level. Additive (Phase 6).
  int? parentId;

  /// An ARGB colour for the folder's glyph; null for the plain one.
  int? color;
}
