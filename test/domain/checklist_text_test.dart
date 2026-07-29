// Tier 4.14: checklists as a text convention (`[ ]` / `[x]` line markers),
// which is the same syntax NoteCardData already detects for previews.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/checklist_text.dart';

void main() {
  group('detection', () {
    test('recognises a list where every line is an item', () {
      expect(ChecklistText.isChecklist('[ ] milk\n[x] eggs'), isTrue);
    });

    test('accepts an uppercase X', () {
      expect(ChecklistText.isChecklist('[X] done'), isTrue);
    });

    test('ignores blank lines between items', () {
      expect(ChecklistText.isChecklist('[ ] a\n\n[x] b'), isTrue);
    });

    test('one stray marker in prose is not a checklist', () {
      // Otherwise ordinary notes would sprout checkboxes.
      expect(
        ChecklistText.isChecklist('Some notes\n[ ] a stray line'),
        isFalse,
      );
    });

    test('plain text is not a checklist', () {
      expect(ChecklistText.isChecklist('just words'), isFalse);
    });

    test('empty text is not a checklist', () {
      expect(ChecklistText.isChecklist(''), isFalse);
      expect(ChecklistText.isChecklist('   \n  '), isFalse);
    });

    test('a bullet list is not yet a checklist', () {
      expect(ChecklistText.isChecklist('- milk\n- eggs'), isFalse);
    });
  });

  group('items', () {
    test('reads label and state, keeping the line index', () {
      final items = ChecklistText.items('[ ] milk\n[x] eggs');

      expect(items.map((i) => i.label), ['milk', 'eggs']);
      expect(items.map((i) => i.done), [false, true]);
      expect(items.map((i) => i.lineIndex), [0, 1]);
    });

    test('line index accounts for blank lines', () {
      final items = ChecklistText.items('[ ] a\n\n[x] b');

      expect(items.last.lineIndex, 2);
    });

    test('non-checklist text has no items', () {
      expect(ChecklistText.items('just words'), isEmpty);
    });
  });

  group('converting to a checklist', () {
    test('prefixes each line', () {
      expect(ChecklistText.toChecklist('milk\neggs'), '[ ] milk\n[ ] eggs');
    });

    test('consumes an existing bullet rather than stacking markers', () {
      expect(ChecklistText.toChecklist('- milk'), '[ ] milk');
      expect(ChecklistText.toChecklist('1. milk'), '[ ] milk');
      expect(ChecklistText.toChecklist('• milk'), '[ ] milk');
    });

    test('leaves existing items and their tick state alone', () {
      expect(ChecklistText.toChecklist('[x] done\nnew'), '[x] done\n[ ] new');
    });

    test('preserves blank lines', () {
      expect(ChecklistText.toChecklist('a\n\nb'), '[ ] a\n\n[ ] b');
    });

    test('preserves indentation', () {
      expect(ChecklistText.toChecklist('  nested'), '  [ ] nested');
    });

    test('round-trips back to plain text', () {
      const plain = 'milk\neggs';

      expect(
        ChecklistText.fromChecklist(ChecklistText.toChecklist(plain)),
        plain,
      );
    });

    test('removing markers keeps the labels', () {
      expect(ChecklistText.fromChecklist('[x] milk\n[ ] eggs'), 'milk\neggs');
    });
  });

  group('toggling', () {
    test('ticks an unticked item', () {
      expect(ChecklistText.toggleItem('[ ] milk', 0), '[x] milk');
    });

    test('unticks a ticked item', () {
      expect(ChecklistText.toggleItem('[x] milk', 0), '[ ] milk');
    });

    test('touches only the named line', () {
      expect(
        ChecklistText.toggleItem('[ ] a\n[ ] b', 1),
        '[ ] a\n[x] b',
      );
    });

    test('an out-of-range line is a no-op', () {
      expect(ChecklistText.toggleItem('[ ] a', 9), '[ ] a');
      expect(ChecklistText.toggleItem('[ ] a', -1), '[ ] a');
    });

    test('a non-item line is a no-op', () {
      expect(ChecklistText.toggleItem('plain\n[ ] a', 0), 'plain\n[ ] a');
    });

    test('preserves indentation', () {
      expect(ChecklistText.toggleItem('  [ ] a', 0), '  [x] a');
    });

    test('setAll ticks everything', () {
      expect(
        ChecklistText.setAll('[ ] a\n[x] b', done: true),
        '[x] a\n[x] b',
      );
    });

    test('setAll unticks everything', () {
      expect(
        ChecklistText.setAll('[x] a\n[x] b', done: false),
        '[ ] a\n[ ] b',
      );
    });
  });

  group('progress', () {
    test('counts ticked out of total', () {
      final p = ChecklistText.progress('[x] a\n[ ] b\n[x] c');

      expect(p.done, 2);
      expect(p.total, 3);
    });

    test('is zero for plain text', () {
      final p = ChecklistText.progress('just words');

      expect(p.done, 0);
      expect(p.total, 0);
    });
  });
}
