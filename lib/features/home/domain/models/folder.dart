// A folder of notebooks — the course/subject container students organise by.
//
// Flat, not nested: one level maps to how notes are actually filed (a subject),
// and nesting would need a tree UI and cycle handling for no demonstrated gain.
// Notebooks point at a folder by nullable id (see [Notebook.folderId]) rather
// than the folder holding a list, so deleting a folder leaves its notes intact
// and simply unfiled.

import 'package:isar/isar.dart';

part 'folder.g.dart';

@collection
class Folder {
  Id id = Isar.autoIncrement;

  late String name;

  late DateTime createdAt;

  /// Manual ordering on the home screen; ties fall back to name.
  int sortIndex = 0;
}
