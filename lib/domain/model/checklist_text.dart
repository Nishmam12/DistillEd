// Checklists as a convention over ordinary text, not a new element kind.
//
// A checklist is a [TextElement] whose lines begin with `[ ]` or `[x]`. Keeping
// it text means it inherits everything text already has — rendering, selection,
// rotation, SVG/PDF export, handwriting extraction, RAG indexing, and the home
// screen's existing checklist preview detection (NoteCardData._markerPattern
// already recognises exactly this syntax). A dedicated element kind would have
// meant re-teaching every one of those.

/// Marker at the start of a checklist line, capturing whether it is ticked.
final _itemPattern = RegExp(r'^(\s*)\[([ xX])\]\s?(.*)$');

/// A leading bullet of any supported style, for converting a bullet list.
final _bulletPattern = RegExp(r'^(\s*)(?:[-*•·]|\d+[.)])\s+(.*)$');

/// One line of a checklist.
class ChecklistItem {
  /// Position of the line within the element's text.
  final int lineIndex;
  final bool done;
  final String label;

  const ChecklistItem({
    required this.lineIndex,
    required this.done,
    required this.label,
  });
}

class ChecklistText {
  ChecklistText._();

  /// Whether [text] should be treated as a checklist.
  ///
  /// Requires every non-blank line to be an item: one stray `[ ]` inside a
  /// paragraph is not a checklist, and treating it as one would put checkboxes
  /// on prose.
  static bool isChecklist(String text) {
    final lines = _contentLines(text);
    if (lines.isEmpty) return false;
    return lines.every((line) => _itemPattern.hasMatch(line));
  }

  /// The items in [text]. Empty when it is not a checklist.
  static List<ChecklistItem> items(String text) {
    if (!isChecklist(text)) return const [];
    final result = <ChecklistItem>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match = _itemPattern.firstMatch(lines[i]);
      if (match == null) continue;
      result.add(ChecklistItem(
        lineIndex: i,
        done: match.group(2)!.toLowerCase() == 'x',
        label: match.group(3)!.trim(),
      ));
    }
    return result;
  }

  /// Turns [text] into a checklist, one unticked item per non-blank line.
  ///
  /// Existing bullet markers are consumed rather than kept, so converting a
  /// bullet list does not produce `[ ] - item`.
  static String toChecklist(String text) {
    final out = <String>[];
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) {
        out.add(line);
        continue;
      }
      if (_itemPattern.hasMatch(line)) {
        out.add(line); // already an item — leave its state alone
        continue;
      }
      final bullet = _bulletPattern.firstMatch(line);
      if (bullet != null) {
        out.add('${bullet.group(1)}[ ] ${bullet.group(2)}');
      } else {
        final indent = line.length - line.trimLeft().length;
        out.add('${line.substring(0, indent)}[ ] ${line.trim()}');
      }
    }
    return out.join('\n');
  }

  /// Strips checklist markers, leaving plain lines. Tick state is discarded —
  /// there is nowhere to keep it once the markers are gone.
  static String fromChecklist(String text) {
    return text.split('\n').map((line) {
      final match = _itemPattern.firstMatch(line);
      return match == null ? line : '${match.group(1)}${match.group(3)}';
    }).join('\n');
  }

  /// Flips the item on [lineIndex]. Returns [text] unchanged when that line is
  /// not an item.
  static String toggleItem(String text, int lineIndex) {
    final lines = text.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return text;
    final match = _itemPattern.firstMatch(lines[lineIndex]);
    if (match == null) return text;
    final nowDone = match.group(2)!.toLowerCase() != 'x';
    lines[lineIndex] =
        '${match.group(1)}[${nowDone ? 'x' : ' '}] ${match.group(3)}';
    return lines.join('\n');
  }

  /// Sets every item's state at once — drives "check all" / "uncheck all".
  static String setAll(String text, {required bool done}) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match = _itemPattern.firstMatch(lines[i]);
      if (match == null) continue;
      lines[i] = '${match.group(1)}[${done ? 'x' : ' '}] ${match.group(3)}';
    }
    return lines.join('\n');
  }

  /// How many items are ticked, out of how many.
  static ({int done, int total}) progress(String text) {
    final all = items(text);
    return (done: all.where((i) => i.done).length, total: all.length);
  }

  static List<String> _contentLines(String text) => [
        for (final line in text.split('\n'))
          if (line.trim().isNotEmpty) line,
      ];
}
