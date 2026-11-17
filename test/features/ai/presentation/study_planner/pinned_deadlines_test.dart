import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/domain/study_planner/note_deadlines.dart';
import 'package:margo/features/ai/presentation/study_planner/pinned_deadlines.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  NoteDeadline d(int day, String label, {bool pinned = false}) => NoteDeadline(
      date: DateTime(2026, 12, day), label: label, pageId: 1, pinned: pinned);

  test('pinned dates are kept per notebook, replaced on a repeat, removable',
      () async {
    await PinnedDeadlines.add(7, d(3, 'Exam Dec 3', pinned: true));
    await PinnedDeadlines.add(7, d(3, 'exam dec 3', pinned: true));
    await PinnedDeadlines.add(7, d(9, 'Lab due', pinned: true));
    expect((await PinnedDeadlines.load(7)).map((x) => x.label),
        ['exam dec 3', 'Lab due']);
    expect(await PinnedDeadlines.load(8), isEmpty);
    expect((await PinnedDeadlines.load(7)).every((x) => x.pinned), isTrue);

    await PinnedDeadlines.remove(7, d(9, 'Lab due'));
    expect((await PinnedDeadlines.load(7)).single.label, 'exam dec 3');
  });

  test('merged soonest first; a found date also pinned shows once, pinned; '
      'past pinned dates are left out', () {
    final merged = mergeDeadlines(
      [d(5, 'Quiz'), d(3, 'Exam Dec 3')],
      [d(3, 'exam dec 3', pinned: true), d(1, 'Old', pinned: true)],
      now: DateTime(2026, 12, 2),
    );
    expect(merged.map((x) => (x.label, x.pinned)),
        [('exam dec 3', true), ('Quiz', false)]);
  });
}
