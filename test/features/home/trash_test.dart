// Tier 1.4: deleting a note must be reversible.
//
// [NoteRepository] is Isar-backed, so a fake `implements` it (Dart's implicit
// interface — the private `_isar` field is not part of it). The fake models the
// one behaviour under test: deletedAt gates which list a notebook appears in.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/home/data/repositories/note_repository.dart';
import 'package:inkflow/features/home/domain/models/folder.dart';
import 'package:inkflow/features/home/domain/models/notebook.dart';
import 'package:inkflow/features/home/presentation/home_notifier.dart';
import 'package:inkflow/features/home/presentation/trash_notifier.dart';

class FakeNoteRepository implements NoteRepository {
  final List<Notebook> notebooks = [];
  int _nextId = 1;

  /// Ids passed to the permanent delete, in order — lets a test prove that
  /// purging erases rather than just hiding.
  final List<int> permanentlyDeleted = [];

  Notebook _seed(String title, {DateTime? deletedAt}) {
    final n = Notebook()
      ..id = _nextId++
      ..title = title
      ..createdAt = DateTime.now()
      ..modifiedAt = DateTime.now()
      ..deletedAt = deletedAt;
    notebooks.add(n);
    return n;
  }

  @override
  Future<Notebook> createNotebook(String title, {int templateIndex = 0}) async =>
      _seed(title);

  @override
  Future<List<Notebook>> getAllNotebooks() async =>
      notebooks.where((n) => n.deletedAt == null).toList();

  @override
  Future<List<Notebook>> getTrashedNotebooks() async {
    final trashed = notebooks.where((n) => n.deletedAt != null).toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return trashed;
  }

  @override
  Future<void> moveToTrash(int id) async {
    notebooks.firstWhere((n) => n.id == id).deletedAt = DateTime.now();
  }

  @override
  Future<void> restoreFromTrash(int id) async {
    notebooks.firstWhere((n) => n.id == id).deletedAt = null;
  }

  @override
  Future<void> deleteNotebook(int id) async {
    permanentlyDeleted.add(id);
    notebooks.removeWhere((n) => n.id == id);
  }

  @override
  Future<int> purgeExpiredTrash({
    Duration retention = NoteRepository.trashRetention,
  }) async {
    final cutoff = DateTime.now().subtract(retention);
    final expired = notebooks
        .where((n) => n.deletedAt != null && n.deletedAt!.isBefore(cutoff))
        .toList();
    for (final n in expired) {
      await deleteNotebook(n.id);
    }
    return expired.length;
  }

  @override
  Future<int> emptyTrash() async {
    final trashed = await getTrashedNotebooks();
    for (final n in trashed) {
      await deleteNotebook(n.id);
    }
    return trashed.length;
  }

  @override
  Future<Notebook?> getNotebook(int id) async =>
      notebooks.where((n) => n.id == id).firstOrNull;

  @override
  Future<void> updateNotebook(Notebook notebook) async {}

  @override
  Future<void> updateTitle(int id, String title) async {}

  @override
  Future<void> updateBackgroundColor(int id, int color) async {}

  @override
  Future<void> updateTemplateIndex(int id, int templateIndex) async {}

  @override
  Future<void> updateLayoutMode(int id, int layoutMode) async {}

  // ---- organisation ---------------------------------------------------------

  @override
  Future<void> setPinned(int id, bool pinned) async {
    notebooks.firstWhere((n) => n.id == id).pinned = pinned;
  }

  @override
  Future<void> setFolder(int id, int? folderId) async {
    notebooks.firstWhere((n) => n.id == id).folderId = folderId;
  }

  @override
  Future<void> setTags(int id, List<String> tags) async {
    notebooks.firstWhere((n) => n.id == id).tags =
        NoteRepository.normalizeTags(tags);
  }

  @override
  Future<Map<String, int>> tagCounts() async {
    final counts = <String, int>{};
    for (final n in await getAllNotebooks()) {
      for (final tag in n.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ---- folders --------------------------------------------------------------

  final List<Folder> folders = [];
  int _nextFolderId = 1;

  @override
  Future<List<Folder>> getFolders() async => List.of(folders);

  @override
  Future<Folder> createFolder(String name) async {
    final folder = Folder()
      ..id = _nextFolderId++
      ..name = name.trim()
      ..createdAt = DateTime.now()
      ..sortIndex = folders.length;
    folders.add(folder);
    return folder;
  }

  @override
  Future<void> renameFolder(int id, String name) async {
    folders.firstWhere((f) => f.id == id).name = name.trim();
  }

  @override
  Future<void> deleteFolder(int id) async {
    for (final n in notebooks.where((n) => n.folderId == id)) {
      n.folderId = null;
    }
    folders.removeWhere((f) => f.id == id);
  }
}

void main() {
  late FakeNoteRepository repo;
  late HomeNotifier home;
  late TrashNotifier trash;

  setUp(() {
    repo = FakeNoteRepository();
    home = HomeNotifier(repo);
    trash = TrashNotifier(repo);
  });

  group('soft delete', () {
    test('removes the note from the home list', () async {
      final n = await repo.createNotebook('Physics');
      await home.loadNotebooks();
      expect(home.state, hasLength(1));

      await home.deleteNotebook(n.id);

      expect(home.state, isEmpty);
    });

    test('does not erase the notebook', () async {
      final n = await repo.createNotebook('Physics');

      await home.deleteNotebook(n.id);

      expect(repo.permanentlyDeleted, isEmpty);
      expect(repo.notebooks, hasLength(1));
    });

    test('puts the note in the trash list', () async {
      final n = await repo.createNotebook('Physics');

      await home.deleteNotebook(n.id);
      await trash.load();

      expect(trash.state.single.id, n.id);
      expect(trash.state.single.title, 'Physics');
    });

    test('stamps deletedAt', () async {
      final n = await repo.createNotebook('Physics');

      await home.deleteNotebook(n.id);

      expect(repo.notebooks.single.deletedAt, isNotNull);
      expect(repo.notebooks.single.isInTrash, isTrue);
    });
  });

  group('restore', () {
    test('brings the note back to the home list', () async {
      final n = await repo.createNotebook('Physics');
      await home.deleteNotebook(n.id);

      await home.restoreNotebook(n.id);

      expect(home.state.single.id, n.id);
    });

    test('takes it out of the trash list', () async {
      final n = await repo.createNotebook('Physics');
      await home.deleteNotebook(n.id);
      await trash.load();

      await trash.restore(n.id);

      expect(trash.state, isEmpty);
    });

    test('clears deletedAt', () async {
      final n = await repo.createNotebook('Physics');
      await home.deleteNotebook(n.id);

      await home.restoreNotebook(n.id);

      expect(repo.notebooks.single.deletedAt, isNull);
    });
  });

  group('permanent delete', () {
    test('deleteForever erases the notebook', () async {
      final n = await repo.createNotebook('Physics');
      await home.deleteNotebook(n.id);
      await trash.load();

      await trash.deleteForever(n.id);

      expect(repo.permanentlyDeleted, [n.id]);
      expect(repo.notebooks, isEmpty);
      expect(trash.state, isEmpty);
    });

    test('emptyTrash erases everything trashed but nothing live', () async {
      final live = await repo.createNotebook('Live');
      final a = await repo.createNotebook('A');
      final b = await repo.createNotebook('B');
      await home.deleteNotebook(a.id);
      await home.deleteNotebook(b.id);
      await trash.load();

      final count = await trash.emptyTrash();

      expect(count, 2);
      expect(repo.notebooks.single.id, live.id);
    });
  });

  group('retention purge', () {
    test('erases notebooks past the retention window', () async {
      final old = repo._seed(
        'Old',
        deletedAt: DateTime.now()
            .subtract(NoteRepository.trashRetention)
            .subtract(const Duration(days: 1)),
      );

      final purged = await home.purgeExpiredTrash();

      expect(purged, 1);
      expect(repo.permanentlyDeleted, [old.id]);
    });

    test('keeps notebooks still inside the window', () async {
      repo._seed(
        'Recent',
        deletedAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      final purged = await home.purgeExpiredTrash();

      expect(purged, 0);
      expect(repo.notebooks, hasLength(1));
    });

    test('never touches live notebooks', () async {
      await repo.createNotebook('Live');

      await home.purgeExpiredTrash();

      expect(repo.permanentlyDeleted, isEmpty);
    });

    test('initialize purges then loads the live list', () async {
      repo._seed(
        'Old',
        deletedAt: DateTime.now()
            .subtract(NoteRepository.trashRetention)
            .subtract(const Duration(days: 1)),
      );
      await repo.createNotebook('Live');

      await home.initialize();

      expect(home.state.single.title, 'Live');
      expect(repo.notebooks, hasLength(1));
    });
  });

  group('daysUntilPurge', () {
    test('counts down from the retention window', () {
      final n = Notebook()
        ..deletedAt = DateTime.now().subtract(const Duration(days: 10));

      expect(
        TrashNotifier.daysUntilPurge(n),
        NoteRepository.trashRetention.inDays - 10,
      );
    });

    test('never goes negative', () {
      final n = Notebook()
        ..deletedAt = DateTime.now()
            .subtract(NoteRepository.trashRetention)
            .subtract(const Duration(days: 5));

      expect(TrashNotifier.daysUntilPurge(n), 0);
    });
  });
}
