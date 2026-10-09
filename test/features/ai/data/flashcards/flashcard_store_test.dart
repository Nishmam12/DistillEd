// The flashcard store on a real database: regenerating a deck keeps the review
// history of the cards that survive it, and only those.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:distill_ed/features/ai/data/flashcards/flashcard_record.dart';
import 'package:distill_ed/features/ai/data/flashcards/flashcard_store.dart';
import 'package:distill_ed/features/ai/domain/flashcards/spaced_repetition.dart';
import 'package:distill_ed/features/ai/domain/models/flashcard.dart';

import '../../../../support/isar_native_library.dart';

final _now = DateTime(2026, 10, 9, 9);

Flashcard _card(String front, {int pageId = 7}) => Flashcard(
      front: front,
      back: 'answer to $front',
      notebookId: 1,
      pageId: pageId,
      createdAt: _now,
    );

Future<void> main() async {
  final library = await isarNativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  group('IsarFlashcardStore', () {
    late Directory dir;
    late Isar isar;
    late IsarFlashcardStore store;

    setUpAll(() async {
      if (library != null) await initIsarForTests(library);
    });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('flashcard_store_test_');
      isar = await Isar.open(
        [FlashcardRecordSchema],
        directory: dir.path,
        name: 'flashcards',
      );
      store = IsarFlashcardStore(isar: () => isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    test('a deck saved for a page is what the page returns', () async {
      await store.replaceForPage(1, 7, [_card('Mitosis'), _card('Meiosis')]);

      final fronts = (await store.forPage(7)).map((c) => c.front).toList();
      expect(fronts, unorderedEquals(['Mitosis', 'Meiosis']));
    }, skip: skip);

    test('regenerating a deck keeps the review history of cards that survive',
        () async {
      await store.replaceForPage(1, 7, [_card('Mitosis')]);
      final graded = (await store.forPage(7)).single.graded(
            ReviewGrade.values.last,
            now: _now,
          );
      await store.updateSchedule(graded);

      await store.replaceForPage(1, 7, [_card('Mitosis'), _card('Meiosis')]);

      final mitosis =
          (await store.forPage(7)).firstWhere((c) => c.front == 'Mitosis');
      expect(mitosis.schedule.dueAt, graded.schedule.dueAt,
          reason: 'regenerating must not reset what the learner has done');
    }, skip: skip);

    test('a card no longer in the generated deck is dropped from the page',
        () async {
      await store.replaceForPage(1, 7, [_card('Old'), _card('Also old')]);

      await store.replaceForPage(1, 7, [_card('New')]);

      expect((await store.forPage(7)).map((c) => c.front), ['New']);
    }, skip: skip);

    test('a graded card is found by its page and front when its schedule is saved',
        () async {
      await store.replaceForPage(1, 7, [_card('Osmosis'), _card('Diffusion')]);
      final osmosis =
          (await store.forPage(7)).firstWhere((c) => c.front == 'Osmosis');

      await store.updateSchedule(
          osmosis.graded(ReviewGrade.values.last, now: _now));

      final after = await store.forPage(7);
      expect(after, hasLength(2));
      expect(
        after.firstWhere((c) => c.front == 'Osmosis').schedule.dueAt,
        isNotNull,
      );
      expect(
        after.firstWhere((c) => c.front == 'Diffusion').schedule.dueAt,
        isNull,
        reason: 'only the graded card changes',
      );
    }, skip: skip);

    test('due-now returns the cards that are due, not the ones just scheduled',
        () async {
      await store.replaceForPage(1, 7, [_card('Due'), _card('Later')]);
      final later =
          (await store.forPage(7)).firstWhere((c) => c.front == 'Later');
      await store.updateSchedule(
          later.graded(ReviewGrade.values.last, now: _now));

      final due = await store.dueForNotebook(1, _now);

      expect(due.map((c) => c.front), ['Due']);
    }, skip: skip);
  });
}
