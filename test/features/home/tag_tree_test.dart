import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/data/repositories/note_repository.dart';
import 'package:margo/features/home/domain/tag_tree.dart';

void main() {
  test('a slash nests a tag; steps are trimmed and empty ones dropped', () {
    expect(NoteRepository.normalizeTags([' Physics / Optics ', 'a//b', '/', 'x/']),
        ['a/b', 'physics/optics', 'x']);
  });

  test('a parent tag takes in its children, and only them', () {
    expect(hasTagOrChild(['physics/optics'], 'physics'), isTrue);
    expect(hasTagOrChild(['physics'], 'physics'), isTrue);
    expect(hasTagOrChild(['physicsx'], 'physics'), isFalse);
    expect(hasTagOrChild(['physics'], 'physics/optics'), isFalse);
  });

  test('the tree: parents first, implied parents shown, notes counted once', () {
    final tree = tagTree([
      ['physics/optics', 'physics/waves'],
      ['physics/optics'],
      ['biology'],
    ]);
    expect([for (final n in tree) (n.path, n.depth, n.notes)], [
      ('biology', 0, 1),
      ('physics', 0, 2),
      ('physics/optics', 1, 2),
      ('physics/waves', 1, 1),
    ]);
    expect(tree[2].label, 'optics');
  });
}
