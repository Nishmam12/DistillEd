import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/study_planner/note_deadlines.dart';

/// A finder that "reads" dates out of a table of exact sentences, and records
/// what it was asked — so a test says exactly which text reached the model.
class _FakeFinder implements DateFinder {
  final Map<String, List<DateTime>> byText;
  final Set<String> failOn;
  final bool unavailable;
  final asked = <String>[];

  _FakeFinder(this.byText, {this.failOn = const {}, this.unavailable = false});

  @override
  Future<List<DateTime>> find(String text, {required DateTime now}) async {
    asked.add(text);
    if (unavailable) throw const DateFinderUnavailable();
    if (failOn.contains(text)) throw StateError('could not read this line');
    return byText[text] ?? const [];
  }
}

void main() {
  // A Friday.
  final now = DateTime(2026, 10, 2, 9, 30);
  final oct14 = DateTime(2026, 10, 14);

  Future<List<NoteDeadline>> find(
    Map<int, String> pages,
    _FakeFinder finder, {
    int limit = 5,
  }) =>
      findNoteDeadlines(pageTexts: pages, finder: finder, now: now, limit: limit);

  test('a dated line that names a quiz or exam is a deadline', () async {
    final finder = _FakeFinder({
      'Quiz 2 on Oct 14': [oct14],
    });

    final found = await find({7: 'Cell biology\nQuiz 2 on Oct 14\nmitosis'}, finder);

    expect(found, hasLength(1));
    expect(found.single.date, oct14);
    expect(found.single.label, 'Quiz 2 on Oct 14');
    expect(found.single.pageId, 7);
  });

  test('only lines that name something to prepare for reach the model',
      () async {
    final finder = _FakeFinder({});

    await find({
      1: 'Mitochondria were described on Oct 14\nFinal exam next Thursday\nlunch',
    }, finder);

    expect(finder.asked, ['Final exam next Thursday']);
  });

  test('a date with no deadline word is not offered', () async {
    final finder = _FakeFinder({
      'The treaty was signed on Oct 14': [oct14],
    });

    expect(await find({1: 'The treaty was signed on Oct 14'}, finder), isEmpty);
  });

  test('deadline words are whole words — "finally" is not "final"', () async {
    final finder = _FakeFinder({
      'We finally covered it on Oct 14': [oct14],
      'Contest on Oct 14': [oct14],
    });

    await find({1: 'We finally covered it on Oct 14\nContest on Oct 14'}, finder);

    expect(finder.asked, isEmpty);
  });

  test('every word that names a deadline is recognised, in any case',
      () async {
    const lines = [
      'EXAM Oct 14',
      'quizzes Oct 14',
      'Midterm Oct 14',
      'assignment due Oct 14',
      'Submission Oct 14',
      'Viva Oct 14',
      'presentation Oct 14',
      'test Oct 14',
      'deadline Oct 14',
    ];
    final finder = _FakeFinder({for (final l in lines) l: [oct14]});

    final found = await find({1: lines.join('\n')}, finder, limit: 20);

    // All nine are the same date; the label differs, so none is dropped.
    expect(found, hasLength(lines.length));
  });

  group('which dates count', () {
    test('today still counts', () async {
      final finder = _FakeFinder({
        'Exam today': [DateTime(2026, 10, 2)],
      });

      final found = await find({1: 'Exam today'}, finder);

      expect(found.single.date, DateTime(2026, 10, 2));
    });

    test('a date that has already passed does not', () async {
      final finder = _FakeFinder({
        'Quiz 1 was on Sep 30': [DateTime(2026, 9, 30)],
      });

      expect(await find({1: 'Quiz 1 was on Sep 30'}, finder), isEmpty);
    });

    test('a time later today is today, not the past', () async {
      final finder = _FakeFinder({
        'Quiz at 9am': [DateTime(2026, 10, 2, 9, 0)],
      });

      final found = await find({1: 'Quiz at 9am'}, finder);

      expect(found.single.date, DateTime(2026, 10, 2));
    });

    test('a date more than a year away does not — the planner stops there',
        () async {
      final finder = _FakeFinder({
        'Final exam Dec 1': [DateTime(2027, 12, 1)],
      });

      expect(await find({1: 'Final exam Dec 1'}, finder), isEmpty);
    });
  });

  group('the result list', () {
    test('is soonest first', () async {
      final finder = _FakeFinder({
        'Final exam Nov 20': [DateTime(2026, 11, 20)],
        'Quiz Oct 14': [oct14],
        'Midterm Oct 30': [DateTime(2026, 10, 30)],
      });

      final found = await find({
        1: 'Final exam Nov 20\nQuiz Oct 14',
        2: 'Midterm Oct 30',
      }, finder);

      expect(found.map((d) => d.date), [
        oct14,
        DateTime(2026, 10, 30),
        DateTime(2026, 11, 20),
      ]);
    });

    test('says a line once even when two pages repeat it', () async {
      // Both spellings are READ as the same date, so only the dedupe can make
      // this one result.
      final finder = _FakeFinder({
        'Quiz Oct 14': [oct14],
        'quiz  oct 14': [oct14],
      });

      final found = await find({1: 'Quiz Oct 14', 2: 'quiz  oct 14'}, finder);

      expect(finder.asked, hasLength(2), reason: 'both lines were read');
      expect(found, hasLength(1));
      expect(found.single.pageId, 1, reason: 'the first sighting is kept');
    });

    test('is capped at the limit, keeping the soonest', () async {
      final finder = _FakeFinder({
        for (var d = 10; d <= 20; d++) 'Quiz Oct $d': [DateTime(2026, 10, d)],
      });

      final found = await find({
        1: [for (var d = 20; d >= 10; d--) 'Quiz Oct $d'].join('\n'),
      }, finder, limit: 3);

      expect(found.map((f) => f.date.day), [10, 11, 12]);
    });

    test('a line with two dates gives both', () async {
      final finder = _FakeFinder({
        'Midterm Oct 14, final Nov 20': [oct14, DateTime(2026, 11, 20)],
      });

      final found = await find({1: 'Midterm Oct 14, final Nov 20'}, finder);

      expect(found.map((d) => d.date), [oct14, DateTime(2026, 11, 20)]);
    });
  });

  group('the label', () {
    test('collapses the whitespace handwriting recognition leaves', () async {
      final finder = _FakeFinder({
        'Quiz   2\ton   Oct 14': [oct14],
      });

      final found = await find({1: 'Quiz   2\ton   Oct 14'}, finder);

      expect(found.single.label, 'Quiz 2 on Oct 14');
    });

    test('is cut short with an ellipsis when the line is long', () async {
      final long = 'Quiz on Oct 14 covering ${'chapter material ' * 10}';
      final finder = _FakeFinder({long.trim(): [oct14]});

      final found = await find({1: long}, finder);

      expect(found.single.label.length, lessThanOrEqualTo(kDeadlineLabelMax));
      expect(found.single.label, endsWith('…'));
      expect(found.single.label, startsWith('Quiz on Oct 14'));
    });

    test('an abbreviated month is not the end of a sentence', () async {
      final finder = _FakeFinder({
        'Quiz on Oct. 14': [oct14],
      });

      final found = await find({1: 'Quiz on Oct. 14'}, finder);

      expect(finder.asked, ['Quiz on Oct. 14']);
      expect(found.single.date, oct14);
    });

    test('a paragraph is read a sentence at a time', () async {
      final finder = _FakeFinder({
        'Quiz 2 is on Oct 14.': [oct14],
      });

      final found = await find({
        1: 'We covered cells today. Quiz 2 is on Oct 14. Bring a pencil.',
      }, finder);

      expect(finder.asked, ['Quiz 2 is on Oct 14.']);
      expect(found.single.label, 'Quiz 2 is on Oct 14.');
    });
  });

  group('when the model misbehaves', () {
    test('one line it cannot read does not lose the others', () async {
      final finder = _FakeFinder({
        'Quiz Oct 14': [oct14],
      }, failOn: {
        'Exam tomorrow',
      });

      final found = await find({1: 'Exam tomorrow\nQuiz Oct 14'}, finder);

      expect(found.map((d) => d.label), ['Quiz Oct 14']);
    });

    test('a finder that cannot run at all fails the whole lookup', () async {
      // "No dates found" would be a lie: the model never looked. One line is
      // enough to know, so the rest are not tried either.
      final finder = _FakeFinder({}, unavailable: true);

      await expectLater(
        find({1: 'Quiz Oct 14\nExam Nov 3'}, finder),
        throwsA(isA<DateFinderUnavailable>()),
      );
      expect(finder.asked, ['Quiz Oct 14']);
    });

    test('no pages is no deadlines', () async {
      expect(await find({}, _FakeFinder({})), isEmpty);
    });
  });
}
