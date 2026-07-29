// Tier 3: pinning, folders and tags — the organisation layer over a flat list.
//
// Reuses the fake repository from trash_test.dart, which implements the whole
// NoteRepository interface.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/home/data/repositories/note_repository.dart';
import 'package:inkflow/features/home/domain/models/notebook.dart';
import 'package:inkflow/features/home/presentation/home_notifier.dart';
import 'package:inkflow/features/home/presentation/models/note_card_data.dart';
import 'package:inkflow/features/home/presentation/note_cards_provider.dart';

import 'trash_test.dart' show FakeNoteRepository;

NoteCardData _card(
  int id, {
  bool pinned = false,
  int? folderId,
  List<String> tags = const [],
  String title = 'Note',
  DateTime? createdAt,
}) {
  final notebook = Notebook()
    ..id = id
    ..title = title
    ..createdAt = createdAt ?? DateTime(2026, 1, 1)
    ..modifiedAt = DateTime(2026, 1, 1)
    ..pinned = pinned
    ..folderId = folderId
    ..tags = tags;
  return NoteCardData.fromNotebook(notebook);
}

void main() {
  late FakeNoteRepository repo;
  late HomeNotifier home;

  setUp(() {
    repo = FakeNoteRepository();
    home = HomeNotifier(repo);
  });

  group('pinning', () {
    test('setPinned marks the notebook', () async {
      final n = await repo.createNotebook('Physics');

      await home.setPinned(n.id, true);

      expect(repo.notebooks.single.pinned, isTrue);
    });

    test('carries through to the card', () {
      expect(_card(1, pinned: true).pinned, isTrue);
      expect(_card(1).pinned, isFalse);
    });

    test('pinned notes lead under every sort', () {
      final cards = [
        _card(1, title: 'Alpha'),
        _card(2, title: 'Zulu', pinned: true),
      ];

      for (final sort in NotesSort.values) {
        expect(sortCards(cards, sort).first.id, 2, reason: '$sort');
      }
    });

    test('the chosen sort still holds within each group', () {
      final cards = [
        _card(1, title: 'Beta', pinned: true),
        _card(2, title: 'Alpha', pinned: true),
        _card(3, title: 'Delta'),
        _card(4, title: 'Charlie'),
      ];

      final sorted = sortCards(cards, NotesSort.title);

      expect(sorted.map((c) => c.title), ['Alpha', 'Beta', 'Charlie', 'Delta']);
    });

    test('unpinning puts the note back in the flow', () async {
      final n = await repo.createNotebook('Physics');
      await home.setPinned(n.id, true);

      await home.setPinned(n.id, false);

      expect(repo.notebooks.single.pinned, isFalse);
    });
  });

  group('folders', () {
    test('a new folder starts empty', () async {
      final folder = await repo.createFolder('Biology');

      expect(folder.name, 'Biology');
      expect(await repo.getFolders(), hasLength(1));
    });

    test('filing a note sets its folder', () async {
      final n = await repo.createNotebook('Cells');
      final folder = await repo.createFolder('Biology');

      await home.setFolder(n.id, folder.id);

      expect(repo.notebooks.single.folderId, folder.id);
    });

    test('unfiling clears it', () async {
      final n = await repo.createNotebook('Cells');
      final folder = await repo.createFolder('Biology');
      await home.setFolder(n.id, folder.id);

      await home.setFolder(n.id, null);

      expect(repo.notebooks.single.folderId, isNull);
    });

    test('deleting a folder keeps the notes and unfiles them', () async {
      final n = await repo.createNotebook('Cells');
      final folder = await repo.createFolder('Biology');
      await home.setFolder(n.id, folder.id);

      await repo.deleteFolder(folder.id);

      expect(repo.notebooks, hasLength(1), reason: 'notes survive');
      expect(repo.notebooks.single.folderId, isNull);
      expect(await repo.getFolders(), isEmpty);
    });

    test('renaming a folder does not move its notes', () async {
      final n = await repo.createNotebook('Cells');
      final folder = await repo.createFolder('Biology');
      await home.setFolder(n.id, folder.id);

      await repo.renameFolder(folder.id, 'Life Sciences');

      expect((await repo.getFolders()).single.name, 'Life Sciences');
      expect(repo.notebooks.single.folderId, folder.id);
    });

    group('FolderFilter', () {
      test('all accepts everything', () {
        expect(FolderFilter.all.accepts(_card(1)), isTrue);
        expect(FolderFilter.all.accepts(_card(2, folderId: 5)), isTrue);
      });

      test('unfiled accepts only notes with no folder', () {
        expect(FolderFilter.unfiled.accepts(_card(1)), isTrue);
        expect(FolderFilter.unfiled.accepts(_card(2, folderId: 5)), isFalse);
      });

      test('only accepts just that folder', () {
        const filter = FolderFilter.only(5);

        expect(filter.accepts(_card(1, folderId: 5)), isTrue);
        expect(filter.accepts(_card(2, folderId: 6)), isFalse);
        expect(filter.accepts(_card(3)), isFalse);
      });

      test('two filters for the same folder compare equal', () {
        // The chip's selected state depends on this.
        expect(const FolderFilter.only(5), const FolderFilter.only(5));
        expect(const FolderFilter.only(5), isNot(const FolderFilter.only(6)));
      });
    });
  });

  group('tags', () {
    test('are normalised on write', () async {
      final n = await repo.createNotebook('Cells');

      await home.setTags(n.id, ['  Physics ', 'EXAM', 'physics', '']);

      expect(repo.notebooks.single.tags, ['exam', 'physics']);
    });

    test('normalizeTags trims, lowercases, dedupes and sorts', () {
      expect(
        NoteRepository.normalizeTags(['Zed', 'alpha', 'ALPHA', '  ', ' beta ']),
        ['alpha', 'beta', 'zed'],
      );
    });

    test('replacing tags removes the old ones', () async {
      final n = await repo.createNotebook('Cells');
      await home.setTags(n.id, ['physics']);

      await home.setTags(n.id, ['biology']);

      expect(repo.notebooks.single.tags, ['biology']);
    });

    test('can be cleared', () async {
      final n = await repo.createNotebook('Cells');
      await home.setTags(n.id, ['physics']);

      await home.setTags(n.id, []);

      expect(repo.notebooks.single.tags, isEmpty);
    });

    test('tagCounts counts live notes per tag', () async {
      final a = await repo.createNotebook('A');
      final b = await repo.createNotebook('B');
      await home.setTags(a.id, ['physics', 'exam']);
      await home.setTags(b.id, ['physics']);

      expect(await repo.tagCounts(), {'physics': 2, 'exam': 1});
    });

    test('trashed notes drop out of tagCounts', () async {
      final a = await repo.createNotebook('A');
      await home.setTags(a.id, ['physics']);

      await home.deleteNotebook(a.id);

      expect(await repo.tagCounts(), isEmpty);
    });

    test('are applied retroactively without moving the note', () async {
      // The capture-first-organise-later workflow: tagging must not disturb
      // where the note already sits.
      final n = await repo.createNotebook('Cells');
      final folder = await repo.createFolder('Biology');
      await home.setFolder(n.id, folder.id);

      await home.setTags(n.id, ['exam']);

      expect(repo.notebooks.single.folderId, folder.id);
      expect(repo.notebooks.single.tags, ['exam']);
    });
  });
}
