// Tier 2.7: notes must be findable by what is written inside them, not just by
// title — and findable WITHOUT the embedding model, which is the whole reason
// this text lives in its own table rather than on NoteChunkRecord.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/persistence/page_text_store.dart';
import 'package:inkflow/features/home/domain/models/notebook.dart';
import 'package:inkflow/features/home/presentation/models/note_card_data.dart';

Notebook _notebook(int id, String title) => Notebook()
  ..id = id
  ..title = title
  ..createdAt = DateTime(2026, 1, 1)
  ..modifiedAt = DateTime(2026, 1, 1);

void main() {
  group('PageTextStore', () {
    late InMemoryPageTextStore store;

    setUp(() => store = InMemoryPageTextStore());

    test('stores and reads a page\'s text', () async {
      await store.save(notebookId: 1, pageId: 10, text: 'mitochondria');

      expect(await store.forPage(10), 'mitochondria');
    });

    test('one row per page — re-saving replaces', () async {
      await store.save(notebookId: 1, pageId: 10, text: 'first');
      await store.save(notebookId: 1, pageId: 10, text: 'second');

      expect(await store.forPage(10), 'second');
      expect(await store.forNotebook(1), hasLength(1));
    });

    test('blank text removes the row so an erased page stops matching',
        () async {
      await store.save(notebookId: 1, pageId: 10, text: 'gone soon');

      await store.save(notebookId: 1, pageId: 10, text: '   ');

      expect(await store.forPage(10), '');
      expect(await store.forNotebook(1), isEmpty);
    });

    test('collects every page of a notebook', () async {
      await store.save(notebookId: 1, pageId: 10, text: 'page one');
      await store.save(notebookId: 1, pageId: 11, text: 'page two');
      await store.save(notebookId: 2, pageId: 20, text: 'other notebook');

      final texts = await store.forNotebook(1);

      expect(texts.map((t) => t.text).toSet(), {'page one', 'page two'});
    });

    test('deleting a page drops only its text', () async {
      await store.save(notebookId: 1, pageId: 10, text: 'keep');
      await store.save(notebookId: 1, pageId: 11, text: 'drop');

      await store.deleteForPage(11);

      expect(await store.forNotebook(1), hasLength(1));
      expect(await store.forPage(10), 'keep');
    });

    test('deleting a notebook drops all of its text', () async {
      await store.save(notebookId: 1, pageId: 10, text: 'a');
      await store.save(notebookId: 1, pageId: 11, text: 'b');
      await store.save(notebookId: 2, pageId: 20, text: 'other');

      await store.deleteForNotebook(1);

      expect(await store.forNotebook(1), isEmpty);
      expect(await store.forNotebook(2), hasLength(1));
    });

    test('does not depend on an embedder — no model, still stored', () async {
      // The store has no embedder seam at all; this test exists to pin that
      // fact, since the previous design would have silently stored nothing.
      await store.save(notebookId: 1, pageId: 10, text: 'photosynthesis');

      expect(await store.forPage(10), 'photosynthesis');
    });
  });

  group('card search', () {
    test('matches a word written on the page, not just the title', () {
      final card = NoteCardData.fromNotebook(
        _notebook(1, 'Biology'),
        previewText: 'the mitochondria is the powerhouse of the cell',
      );

      expect(card.matches('mitochondria'), isTrue);
    });

    test('matches text from a later page', () {
      // The provider joins every page's text, so page 7's words are in here.
      final card = NoteCardData.fromNotebook(
        _notebook(1, 'Biology'),
        previewText: 'page one text\npage two text\nkrebs cycle',
      );

      expect(card.matches('krebs'), isTrue);
    });

    test('is case-insensitive', () {
      final card = NoteCardData.fromNotebook(
        _notebook(1, 'Biology'),
        previewText: 'Photosynthesis',
      );

      expect(card.matches('PHOTOSYNTHESIS'), isTrue);
      expect(card.matches('photo'), isTrue);
    });

    test('still matches on title', () {
      final card = NoteCardData.fromNotebook(_notebook(1, 'Biology'));

      expect(card.matches('biol'), isTrue);
    });

    test('rejects a word in neither title nor content', () {
      final card = NoteCardData.fromNotebook(
        _notebook(1, 'Biology'),
        previewText: 'mitochondria',
      );

      expect(card.matches('calculus'), isFalse);
    });

    test('an empty query keeps everything', () {
      final card = NoteCardData.fromNotebook(_notebook(1, 'Biology'));

      expect(card.matches(''), isTrue);
      expect(card.matches('   '), isTrue);
    });

    test('a note with no extracted text still matches its title', () {
      // The pre-existing bug: previewText was never populated, so this was the
      // ONLY thing search could ever hit.
      final card = NoteCardData.fromNotebook(_notebook(1, 'Chemistry'));

      expect(card.previewText, isEmpty);
      expect(card.matches('chem'), isTrue);
      expect(card.matches('anything else'), isFalse);
    });
  });
}
