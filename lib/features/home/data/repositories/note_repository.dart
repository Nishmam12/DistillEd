// Repository providing CRUD operations for Notebook and NotePage collections.

import 'package:isar/isar.dart';

import '../../../../data/persistence/page_text_record.dart';
import '../../../../data/persistence/scene_element_record.dart';
import '../../domain/models/folder.dart';
import '../../domain/models/notebook.dart';
import '../../domain/models/note_page.dart';

class NoteRepository {
  final Isar _isar;

  NoteRepository(this._isar);

  /// Creates a new notebook with the given title and returns it.
  Future<Notebook> createNotebook(String title, {int templateIndex = 0}) async {
    final notebook = Notebook()
      ..title = title
      ..createdAt = DateTime.now()
      ..modifiedAt = DateTime.now()
      ..pageCount = 1
      ..templateIndex = templateIndex;

    await _isar.writeTxn(() async {
      await _isar.notebooks.put(notebook);
    });

    // Create the first page for this notebook.
    final firstPage = NotePage()
      ..notebookId = notebook.id
      ..pageIndex = 0
      ..createdAt = DateTime.now()
      ..modifiedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.notePages.put(firstPage);
    });

    return notebook;
  }

  /// How long a trashed notebook is kept before it is purged automatically.
  static const trashRetention = Duration(days: 30);

  /// Returns the live notebooks, ordered by most recently modified first.
  /// Trashed notebooks are excluded — [getTrashedNotebooks] returns those.
  Future<List<Notebook>> getAllNotebooks() async {
    return _isar.notebooks
        .filter()
        .deletedAtIsNull()
        .sortByModifiedAtDesc()
        .findAll();
  }

  /// Returns the trashed notebooks, most recently deleted first.
  Future<List<Notebook>> getTrashedNotebooks() async {
    return _isar.notebooks
        .filter()
        .deletedAtIsNotNull()
        .sortByDeletedAtDesc()
        .findAll();
  }

  /// Moves a notebook to the trash. Nothing is erased: the notebook, its pages
  /// and its scene elements all stay on disk until it is purged or deleted for
  /// good, so [restoreFromTrash] brings the note back intact.
  Future<void> moveToTrash(int id) async {
    await _isar.writeTxn(() async {
      final notebook = await _isar.notebooks.get(id);
      if (notebook == null) return;
      notebook.deletedAt = DateTime.now();
      await _isar.notebooks.put(notebook);
    });
  }

  /// Brings a trashed notebook back to the home list.
  ///
  /// [modifiedAt] is deliberately left alone so a restored note returns to its
  /// original place in the recency order rather than jumping to the top.
  Future<void> restoreFromTrash(int id) async {
    await _isar.writeTxn(() async {
      final notebook = await _isar.notebooks.get(id);
      if (notebook == null) return;
      notebook.deletedAt = null;
      await _isar.notebooks.put(notebook);
    });
  }

  /// Permanently deletes a notebook, its pages, and its scene elements.
  ///
  /// The scene elements must go too: they are keyed by notebookId in their own
  /// collection, so deleting only the notebook and pages would leave every
  /// stroke on disk forever with nothing pointing at it.
  Future<void> deleteNotebook(int id) async {
    await _isar.writeTxn(() async {
      await _isar.notePages.filter().notebookIdEqualTo(id).deleteAll();
      await _isar.sceneElementRecords
          .filter()
          .notebookIdEqualTo(id)
          .deleteAll();
      // Searchable text goes too, or a deleted note keeps turning up in search.
      await _isar.pageTextRecords.filter().notebookIdEqualTo(id).deleteAll();
      await _isar.notebooks.delete(id);
    });
  }

  /// Permanently deletes every trashed notebook whose retention window has
  /// passed. Returns how many were purged. Safe to call on every launch.
  Future<int> purgeExpiredTrash({Duration retention = trashRetention}) async {
    final cutoff = DateTime.now().subtract(retention);
    final expired = await _isar.notebooks
        .filter()
        .deletedAtIsNotNull()
        .deletedAtLessThan(cutoff)
        .findAll();
    for (final notebook in expired) {
      await deleteNotebook(notebook.id);
    }
    return expired.length;
  }

  /// Permanently deletes everything currently in the trash.
  Future<int> emptyTrash() async {
    final trashed = await getTrashedNotebooks();
    for (final notebook in trashed) {
      await deleteNotebook(notebook.id);
    }
    return trashed.length;
  }

  /// Updates the title and modifiedAt timestamp of an existing notebook.
  Future<void> updateNotebook(Notebook notebook) async {
    notebook.modifiedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.notebooks.put(notebook);
    });
  }

  /// Updates the title of an existing notebook, keeping [modifiedAt] current.
  Future<void> updateTitle(int id, String title) async {
    final notebook = await _isar.notebooks.get(id);
    if (notebook != null) {
      notebook.title = title;
      notebook.modifiedAt = DateTime.now();
      await _isar.writeTxn(() async {
        await _isar.notebooks.put(notebook);
      });
    }
  }

  /// Updates the background color of an existing notebook.
  Future<void> updateBackgroundColor(int id, int color) async {
    final notebook = await _isar.notebooks.get(id);
    if (notebook != null) {
      notebook.backgroundColor = color;
      notebook.modifiedAt = DateTime.now();
      await _isar.writeTxn(() async {
        await _isar.notebooks.put(notebook);
      });
    }
  }

  /// Updates the page/paper template style of an existing notebook.
  Future<void> updateTemplateIndex(int id, int templateIndex) async {
    final notebook = await _isar.notebooks.get(id);
    if (notebook != null) {
      notebook.templateIndex = templateIndex;
      notebook.modifiedAt = DateTime.now();
      await _isar.writeTxn(() async {
        await _isar.notebooks.put(notebook);
      });
    }
  }

  /// Updates the canvas layout mode (0 = infinite, 1 = single page).
  Future<void> updateLayoutMode(int id, int layoutMode) async {
    final notebook = await _isar.notebooks.get(id);
    if (notebook != null) {
      notebook.layoutMode = layoutMode;
      notebook.modifiedAt = DateTime.now();
      await _isar.writeTxn(() async {
        await _isar.notebooks.put(notebook);
      });
    }
  }

  /// Gets a notebook by ID.
  Future<Notebook?> getNotebook(int id) async {
    return await _isar.notebooks.get(id);
  }

  // ---- organisation ---------------------------------------------------------

  /// Pins or unpins a notebook.
  ///
  /// [modifiedAt] is deliberately untouched: pinning is a shelving decision,
  /// not an edit, and bumping it would reshuffle the "recently edited" sort.
  Future<void> setPinned(int id, bool pinned) async {
    await _isar.writeTxn(() async {
      final notebook = await _isar.notebooks.get(id);
      if (notebook == null) return;
      notebook.pinned = pinned;
      await _isar.notebooks.put(notebook);
    });
  }

  /// Moves a notebook into [folderId], or out of any folder when null.
  Future<void> setFolder(int id, int? folderId) async {
    await _isar.writeTxn(() async {
      final notebook = await _isar.notebooks.get(id);
      if (notebook == null) return;
      notebook.folderId = folderId;
      await _isar.notebooks.put(notebook);
    });
  }

  /// Replaces a notebook's tags. Normalised on write — trimmed, lowercased and
  /// de-duplicated — so filtering never has to normalise at read time.
  Future<void> setTags(int id, List<String> tags) async {
    await _isar.writeTxn(() async {
      final notebook = await _isar.notebooks.get(id);
      if (notebook == null) return;
      notebook.tags = normalizeTags(tags);
      await _isar.notebooks.put(notebook);
    });
  }

  /// Trimmed, lowercased, de-duplicated, blanks dropped, sorted for a stable
  /// order. Public so the UI can show the same form it will store.
  static List<String> normalizeTags(Iterable<String> tags) {
    final cleaned = <String>{
      for (final tag in tags)
        if (tag.trim().isNotEmpty) tag.trim().toLowerCase(),
    }.toList()
      ..sort();
    return cleaned;
  }

  /// Every tag in use across live notebooks, with how many notes carry each.
  Future<Map<String, int>> tagCounts() async {
    final counts = <String, int>{};
    for (final notebook in await getAllNotebooks()) {
      for (final tag in notebook.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ---- folders --------------------------------------------------------------

  Future<List<Folder>> getFolders() async {
    final folders = await _isar.folders.where().findAll();
    folders.sort((a, b) {
      final byIndex = a.sortIndex.compareTo(b.sortIndex);
      return byIndex != 0
          ? byIndex
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return folders;
  }

  Future<Folder> createFolder(String name) async {
    final folder = Folder()
      ..name = name.trim()
      ..createdAt = DateTime.now()
      ..sortIndex = (await _isar.folders.count());
    await _isar.writeTxn(() async {
      await _isar.folders.put(folder);
    });
    return folder;
  }

  Future<void> renameFolder(int id, String name) async {
    await _isar.writeTxn(() async {
      final folder = await _isar.folders.get(id);
      if (folder == null) return;
      folder.name = name.trim();
      await _isar.folders.put(folder);
    });
  }

  /// Deletes a folder. The notebooks inside it are kept and become unfiled —
  /// deleting a container must never delete the contents.
  Future<void> deleteFolder(int id) async {
    await _isar.writeTxn(() async {
      final inside =
          await _isar.notebooks.filter().folderIdEqualTo(id).findAll();
      for (final notebook in inside) {
        notebook.folderId = null;
      }
      await _isar.notebooks.putAll(inside);
      await _isar.folders.delete(id);
    });
  }
}
