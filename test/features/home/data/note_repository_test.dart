// The notebook repository on a real database: creating, trashing, restoring,
// purging, tagging and filing notes. Deleting a note's content is covered by
// content_purge_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:distill_ed/data/persistence/lecture_recording_record.dart';
import 'package:distill_ed/data/persistence/page_text_record.dart';
import 'package:distill_ed/data/persistence/scene_element_record.dart';
import 'package:distill_ed/features/ai/data/flashcards/flashcard_record.dart';
import 'package:distill_ed/features/ai/data/memory/concept_mastery_record.dart';
import 'package:distill_ed/features/ai/data/memory/concept_relation_record.dart';
import 'package:distill_ed/features/ai/data/memory/quiz_attempt_record.dart';
import 'package:distill_ed/features/ai/data/rag/note_chunk_record.dart';
import 'package:distill_ed/features/ai/data/study_planner/study_plan_record.dart';
import 'package:distill_ed/features/home/data/repositories/note_repository.dart';
import 'package:distill_ed/features/home/domain/models/folder.dart';
import 'package:distill_ed/features/home/domain/models/note_page.dart';
import 'package:distill_ed/features/home/domain/models/notebook.dart';
import 'package:distill_ed/features/summarize/data/cache/summary_cache.dart';

import '../../../support/isar_native_library.dart';

Future<void> main() async {
  final library = await isarNativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  group('NoteRepository', () {
    late Directory dir;
    late Isar isar;
    late NoteRepository repo;

    setUpAll(() async {
      if (library != null) await initIsarForTests(library);
    });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('note_repository_test_');
      isar = await Isar.open(
        [
          NotebookSchema,
          NotePageSchema,
          FolderSchema,
          SceneElementRecordSchema,
          PageTextRecordSchema,
          NoteChunkRecordSchema,
          LectureRecordingRecordSchema,
          SummaryCacheSchema,
          FlashcardRecordSchema,
          QuizAttemptRecordSchema,
          StudyPlanRecordSchema,
          ConceptMasteryRecordSchema,
          ConceptRelationRecordSchema,
        ],
        directory: dir.path,
        name: 'notes',
      );
      repo = NoteRepository(isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    Future<List<String>> liveTitles() async =>
        [for (final n in await repo.getAllNotebooks()) n.title];

    test('a new notebook starts with one page', () async {
      final notebook = await repo.createNotebook('Biology');

      expect(notebook.pageCount, 1);
      final pages = await isar.notePages
          .filter()
          .notebookIdEqualTo(notebook.id)
          .findAll();
      expect(pages, hasLength(1));
      expect(pages.single.pageIndex, 0);
    }, skip: skip);

    test('a trashed note leaves the home list and comes back on restore',
        () async {
      final notebook = await repo.createNotebook('Chemistry');

      await repo.moveToTrash(notebook.id);
      expect(await liveTitles(), isEmpty);
      expect((await repo.getTrashedNotebooks()).map((n) => n.title),
          ['Chemistry']);

      await repo.restoreFromTrash(notebook.id);
      expect(await liveTitles(), ['Chemistry']);
      expect(await repo.getTrashedNotebooks(), isEmpty);
    }, skip: skip);

    test('purging removes only trash past its retention window', () async {
      final recent = await repo.createNotebook('Recent');
      final old = await repo.createNotebook('Old');
      await repo.moveToTrash(recent.id);
      await repo.moveToTrash(old.id);

      // Within the default 30 days: nothing is purged.
      expect(await repo.purgeExpiredTrash(), 0);
      expect(await repo.getTrashedNotebooks(), hasLength(2));

      // A window that every trashed note has passed purges both.
      expect(await repo.purgeExpiredTrash(retention: const Duration(days: -1)),
          2);
      expect(await repo.getTrashedNotebooks(), isEmpty);
      expect(await isar.notePages.count(), 0,
          reason: 'a purged note takes its pages with it');
    }, skip: skip);

    test('emptying the trash deletes every trashed note and nothing else',
        () async {
      final keep = await repo.createNotebook('Keep');
      final bin = await repo.createNotebook('Bin');
      await repo.moveToTrash(bin.id);

      expect(await repo.emptyTrash(), 1);

      expect(await liveTitles(), ['Keep']);
      expect(await repo.getNotebook(bin.id), isNull);
      expect(await repo.getNotebook(keep.id), isNotNull);
    }, skip: skip);

    test('tags are trimmed, lowercased, de-duplicated and counted per note',
        () async {
      final a = await repo.createNotebook('A');
      final b = await repo.createNotebook('B');

      await repo.setTags(a.id, ['  Exam ', 'exam', 'Physics', '']);
      await repo.setTags(b.id, ['physics']);

      expect((await repo.getNotebook(a.id))!.tags, ['exam', 'physics']);
      expect(await repo.tagCounts(), {'exam': 1, 'physics': 2});
    }, skip: skip);

    test('deleting a folder files its notes instead of deleting them',
        () async {
      final folder = await repo.createFolder('Semester 1');
      final notebook = await repo.createNotebook('Lecture notes');
      await repo.setFolder(notebook.id, folder.id);

      await repo.deleteFolder(folder.id);

      expect(await repo.getFolders(), isEmpty);
      final kept = await repo.getNotebook(notebook.id);
      expect(kept, isNotNull, reason: 'the notes inside a folder are kept');
      expect(kept!.folderId, isNull);
    }, skip: skip);

    test('a title change is saved and shown in the list', () async {
      final notebook = await repo.createNotebook('Draft');

      await repo.updateTitle(notebook.id, 'Final');

      expect(await liveTitles(), ['Final']);
    }, skip: skip);
  });
}
