// Nested tags: a tag `physics/optics` sits under `physics`. The tree is built
// from the tags notes carry; a parent no note carries itself still shows, as
// the place its children hang from.

/// Whether a note tagged [noteTags] is in [tag] — carrying it, or a tag under
/// it (`physics` takes in `physics/optics`).
bool hasTagOrChild(List<String> noteTags, String tag) =>
    noteTags.any((t) => t == tag || t.startsWith('$tag/'));

/// One row of the tag tree.
typedef TagNode = ({String path, String label, int depth, int notes});

/// The tag tree of [tagsPerNote] (each note's tags), parents before their
/// children, siblings alphabetical. [TagNode.notes] counts each note once,
/// however many tags it has in that branch.
List<TagNode> tagTree(Iterable<List<String>> tagsPerNote) {
  final notesIn = <String, int>{};
  for (final tags in tagsPerNote) {
    final branches = <String>{
      for (final tag in tags)
        for (var i = 0; i < tag.split('/').length; i++)
          tag.split('/').sublist(0, i + 1).join('/'),
    };
    for (final b in branches) {
      notesIn[b] = (notesIn[b] ?? 0) + 1;
    }
  }
  // Sorting by the steps puts each parent straight before its children.
  final paths = notesIn.keys.toList()
    ..sort((a, b) {
      final x = a.split('/'), y = b.split('/');
      for (var i = 0; i < x.length && i < y.length; i++) {
        final c = x[i].compareTo(y[i]);
        if (c != 0) return c;
      }
      return x.length.compareTo(y.length);
    });
  return [
    for (final p in paths)
      (
        path: p,
        label: p.split('/').last,
        depth: p.split('/').length - 1,
        notes: notesIn[p]!,
      ),
  ];
}
