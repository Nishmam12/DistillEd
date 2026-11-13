// Reads notebooks out of the app into [NotebookSnapshot]s, and adds them back
// as new notebooks — the bridge between the `.margo` format and the stores.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/constants/storage_paths.dart';
import '../../domain/model/scene_element.dart';
import '../../editor/state/scene_controller.dart';
import '../../features/home/data/repositories/note_repository.dart';
import '../../features/home/data/repositories/page_repository.dart';
import '../persistence/page_text_store.dart';
import '../persistence/scene_element_store.dart';
import 'backup_service.dart';
import 'notebook_archive.dart';

class AppBackupLibrary implements BackupLibrary {
  AppBackupLibrary({
    required this.notes,
    required this.pages,
    required this.elements,
    required this.texts,
    required this.docsDir,
  });

  final NoteRepository notes;
  final PageRepository pages;
  final SceneElementStore elements;
  final PageTextStore texts;

  /// The app documents folder every relative path is under.
  final String docsDir;

  @override
  Future<List<int>> notebookIds() async =>
      [for (final n in await notes.getAllNotebooks()) n.id];

  @override
  Future<NotebookSnapshot?> snapshot(int id) async {
    final notebook = await notes.getNotebook(id);
    if (notebook == null || notebook.isInTrash) return null;

    final pageSnapshots = <PageSnapshot>[];
    final media = <String, Uint8List>{};
    for (final page in await pages.getPagesForNotebook(id)) {
      // Edits still queued for the page belong in the backup.
      await SceneController.flushPage(page.id);
      final els = await elements.loadForPage(page.id);
      for (final e in els) {
        if (e is! ImageElement) continue;
        await _addMedia(media, e.relativeImagePath);
        await _addMedia(media, StoragePaths.pdfTextSidecar(e.relativeImagePath));
      }
      pageSnapshots.add(PageSnapshot(
        elements: els,
        text: await texts.forPage(page.id),
        importGroupId: page.importGroupId,
        importSourceName: page.importSourceName,
      ));
    }

    return NotebookSnapshot(
      sourceId: id,
      meta: NotebookMeta(
        title: notebook.title,
        backgroundColor: notebook.backgroundColor,
        templateIndex: notebook.templateIndex,
        layoutMode: notebook.layoutMode,
        tags: notebook.tags,
        createdAt: notebook.createdAt,
      ),
      pages: pageSnapshots,
      media: media,
    );
  }

  /// Reads [rel] into [media] if it is one of the app's own files and exists.
  /// Lecture audio is not included: it is large, and a backup is meant to stay
  /// small enough to keep many of.
  Future<void> _addMedia(Map<String, Uint8List> media, String rel) async {
    if (rel.isEmpty || media.containsKey(rel)) return;
    if (!StoragePaths.isSafeRelativePath(rel) || !rel.startsWith('notes/')) {
      return;
    }
    final file = File('$docsDir/$rel');
    if (await file.exists()) media[rel] = await file.readAsBytes();
  }

  @override
  Future<int> add(NotebookSnapshot snapshot) async {
    final created = await notes.createNotebook(
      snapshot.meta.title,
      templateIndex: snapshot.meta.templateIndex,
      backgroundColor: snapshot.meta.backgroundColor,
    );
    final id = created.id;
    if (snapshot.meta.layoutMode != 0) {
      await notes.updateLayoutMode(id, snapshot.meta.layoutMode);
    }
    if (snapshot.meta.tags.isNotEmpty) await notes.setTags(id, snapshot.meta.tags);

    final moved = snapshot.remappedTo(id);
    for (final m in moved.media.entries) {
      if (!StoragePaths.isSafeRelativePath(m.key)) continue;
      final file = File('$docsDir/${m.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(m.value, flush: true);
    }

    // A new notebook has one page; add the rest.
    for (var i = 1; i < moved.pages.length; i++) {
      await pages.createPage(id);
    }
    final newPages = await pages.getPagesForNotebook(id);
    for (var i = 0; i < moved.pages.length && i < newPages.length; i++) {
      final page = moved.pages[i];
      final pageId = newPages[i].id;
      if (page.importGroupId != null) {
        await pages.tagImport(
          pageId,
          importGroupId: page.importGroupId!,
          importSourceName: page.importSourceName ?? '',
        );
      }
      await elements.replaceForPage(id, pageId, [
        for (final e in page.elements)
          // A picture whose path is not one of ours is dropped, not followed.
          if (e is! ImageElement ||
              StoragePaths.isSafeRelativePath(e.relativeImagePath))
            e,
      ]);
      if (page.text.trim().isNotEmpty) {
        await texts.save(notebookId: id, pageId: pageId, text: page.text);
      }
    }
    debugPrint('[Backup] restored "${snapshot.meta.title}" as notebook $id');
    return id;
  }
}
