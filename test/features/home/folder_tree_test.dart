import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/domain/folder_tree.dart';
import 'package:margo/features/home/domain/models/folder.dart';

Folder _f(int id, [int? parent]) => Folder()
  ..id = id
  ..name = 'f$id'
  ..createdAt = DateTime(2026)
  ..parentId = parent;

void main() {
  // 1 > 2 > 3, and 4 at the top.
  final folders = [_f(1), _f(2, 1), _f(3, 2), _f(4)];

  test('tree puts each parent straight before its children', () {
    expect([for (final n in folderTree(folders)) (n.folder.id, n.depth)],
        [(1, 0), (2, 1), (3, 2), (4, 0)]);
  });

  test('a missing parent is treated as top level; a cycle does not hang', () {
    final odd = [_f(1, 99), _f(2, 3), _f(3, 2)];
    expect(folderTree(odd).map((n) => n.folder.id), [1]);
    expect(folderLevel(odd, 2), 2);
    expect(folderWithin(odd, 2), {2, 3});
  });

  test('within takes in every folder under', () {
    expect(folderWithin(folders, 1), {1, 2, 3});
    expect(folderWithin(folders, 3), {3});
  });

  test('no move into itself or below itself', () {
    expect(canMoveFolder(folders, 1, 1), isFalse);
    expect(canMoveFolder(folders, 1, 3), isFalse);
    expect(canMoveFolder(folders, 3, null), isTrue);
    expect(canMoveFolder(folders, 1, 4), isTrue);
  });

  test('nesting stops at five levels', () {
    final chain = [_f(1), _f(2, 1), _f(3, 2), _f(4, 3), _f(5, 4), _f(6)];
    expect(canAddFolderIn(chain, 4), isTrue);
    expect(canAddFolderIn(chain, 5), isFalse);
    expect(canMoveFolder(chain, 6, 4), isTrue);
    expect(canMoveFolder(chain, 6, 5), isFalse);
    // A two-level branch under level 4 would reach level 6.
    final withChild = [...chain, _f(7, 6)];
    expect(canMoveFolder(withChild, 6, 4), isFalse);
    expect(canMoveFolder(withChild, 6, 3), isTrue);
  });
}
