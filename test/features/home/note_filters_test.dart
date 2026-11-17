import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/presentation/models/note_card_data.dart';
import 'package:margo/features/home/presentation/note_cards_provider.dart';
import 'package:margo/features/home/presentation/saved_searches.dart';

NoteCardData _card(int id, DateTime created) => NoteCardData(
    id: id, title: 'n$id', createdAt: created, pages: 1, type: NoteType.text);

void main() {
  final now = DateTime(2026, 11, 17, 12);
  final facts = (withInk: {1}, withRecording: {2});

  test('date, handwriting and recording each narrow the list', () {
    final fresh = _card(1, now.subtract(const Duration(days: 2)));
    final old = _card(2, now.subtract(const Duration(days: 40)));

    const week = NotesMoreFilters(date: NotesDateFilter.week);
    expect(week.accepts(fresh, facts: facts, now: now), isTrue);
    expect(week.accepts(old, facts: facts, now: now), isFalse);

    const ink = NotesMoreFilters(inkOnly: true);
    expect(ink.accepts(fresh, facts: facts, now: now), isTrue);
    expect(ink.accepts(old, facts: facts, now: now), isFalse);

    const rec = NotesMoreFilters(recordingOnly: true);
    expect(rec.accepts(old, facts: facts, now: now), isTrue);
    expect(rec.accepts(fresh, facts: facts, now: now), isFalse);
  });

  test('before the facts load, a filter that needs them passes nothing', () {
    const ink = NotesMoreFilters(inkOnly: true);
    expect(ink.accepts(_card(1, now), facts: null, now: now), isFalse);
    expect(const NotesMoreFilters().isActive, isFalse);
    expect(ink.isActive, isTrue);
  });

  test('a saved search survives JSON, and bad entries are dropped', () {
    const search = SavedSearch(
      name: 'Exam pages',
      folderId: 4,
      tags: ['exam', 'physics'],
      favoritesOnly: true,
      more: NotesMoreFilters(date: NotesDateFilter.month, inkOnly: true),
      sort: NotesSort.title,
    );
    final back = SavedSearch.fromJson(search.toJson())!;
    expect(back.name, 'Exam pages');
    expect(back.folderId, 4);
    expect(back.tags, ['exam', 'physics']);
    expect(back.favoritesOnly, isTrue);
    expect(back.more.date, NotesDateFilter.month);
    expect(back.more.inkOnly, isTrue);
    expect(back.sort, NotesSort.title);

    expect(SavedSearch.fromJson({'folder': 1}), isNull);
    expect(SavedSearch.fromJson({'name': 'x', 'date': 'decade'})!.more.date,
        NotesDateFilter.any);
  });
}
