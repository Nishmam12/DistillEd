// Nested folders: each [Folder] names its parent by id. These rules are kept
// apart from Isar so they can be tested on plain lists. A folder whose parent
// is missing (deleted elsewhere, a bad restore) is treated as top level, and
// every walk up the tree stops at a repeat, so a cycle can never hang the app.

import 'models/folder.dart';

/// The deepest a folder can sit: a top-level folder is level 1. Samsung Notes
/// caps nesting at 5 as well (`HOLDER_MAX_DEPTH`).
const kMaxFolderDepth = 5;

/// One row of the folder tree; [depth] is 0 at the top level.
typedef FolderNode = ({Folder folder, int depth});

/// [folders] as a tree, each parent straight before its children, siblings
/// in the order given (callers pass them sorted).
List<FolderNode> folderTree(List<Folder> folders) {
  final ids = {for (final f in folders) f.id};
  final children = <int?, List<Folder>>{};
  for (final f in folders) {
    final parent = ids.contains(f.parentId) ? f.parentId : null;
    (children[parent] ??= []).add(f);
  }
  final out = <FolderNode>[];
  final seen = <int>{};
  void walk(int? parent, int depth) {
    for (final f in children[parent] ?? const <Folder>[]) {
      if (!seen.add(f.id)) continue;
      out.add((folder: f, depth: depth));
      walk(f.id, depth + 1);
    }
  }

  walk(null, 0);
  return out;
}

/// [id] and every folder under it.
Set<int> folderWithin(List<Folder> folders, int id) {
  final within = {id};
  var grew = true;
  while (grew) {
    grew = false;
    for (final f in folders) {
      if (f.parentId != null &&
          within.contains(f.parentId) &&
          within.add(f.id)) {
        grew = true;
      }
    }
  }
  return within;
}

/// The level [id] sits at: 1 at the top.
int folderLevel(List<Folder> folders, int id) {
  final byId = {for (final f in folders) f.id: f};
  final seen = <int>{};
  var level = 0;
  int? at = id;
  while (at != null && byId.containsKey(at) && seen.add(at)) {
    level++;
    at = byId[at]!.parentId;
  }
  return level;
}

/// How many levels [id] and the folders under it take up: 1 with none.
int _height(List<Folder> folders, int id) {
  final within = folderWithin(folders, id);
  final base = folderLevel(folders, id);
  var deepest = base;
  for (final f in within) {
    final l = folderLevel(folders, f);
    if (l > deepest) deepest = l;
  }
  return deepest - base + 1;
}

/// Whether folder [id] may move into [parentId] (null: the top level): not
/// into itself or anything under it, and no deeper than [kMaxFolderDepth].
bool canMoveFolder(List<Folder> folders, int id, int? parentId) {
  if (parentId == null) return true;
  if (folderWithin(folders, id).contains(parentId)) return false;
  return folderLevel(folders, parentId) + _height(folders, id) <=
      kMaxFolderDepth;
}

/// Whether a new folder can go inside [parentId] (null: the top level).
bool canAddFolderIn(List<Folder> folders, int? parentId) =>
    parentId == null || folderLevel(folders, parentId) < kMaxFolderDepth;
