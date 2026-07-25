// Repository providing CRUD operations for Notebook and NotePage collections.

import 'package:isar/isar.dart';

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

  /// Returns all notebooks, ordered by most recently modified first.
  Future<List<Notebook>> getAllNotebooks() async {
    return _isar.notebooks.where().sortByModifiedAtDesc().findAll();
  }

  /// Deletes a notebook and all its pages by notebook ID.
  Future<void> deleteNotebook(int id) async {
    await _isar.writeTxn(() async {
      // Delete all pages belonging to this notebook.
      await _isar.notePages.filter().notebookIdEqualTo(id).deleteAll();
      // Delete the notebook itself.
      await _isar.notebooks.delete(id);
    });
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
}
