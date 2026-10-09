// Deleting a notebook or page must delete what was derived from it, not just
// the rows the UI shows. Real Isar, like the chunk store test; skips itself if
// the native library cannot be found.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:distill_ed/data/persistence/isar_scene_element_store.dart';
import 'package:distill_ed/data/persistence/lecture_recording_record.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/data/persistence/page_text_record.dart';
import 'package:distill_ed/data/persistence/scene_element_record.dart';
import 'package:distill_ed/features/ai/data/flashcards/flashcard_record.dart';
import 'package:distill_ed/features/ai/data/memory/concept_mastery_record.dart';
import 'package:distill_ed/features/ai/data/memory/concept_relation_record.dart';
import 'package:distill_ed/features/ai/data/memory/quiz_attempt_record.dart';
import 'package:distill_ed/features/ai/data/rag/note_chunk_record.dart';
import 'package:distill_ed/features/ai/data/study_planner/study_plan_record.dart';
import 'package:distill_ed/features/home/data/repositories/note_repository.dart';
import 'package:distill_ed/features/home/data/repositories/page_repository.dart';
import 'package:distill_ed/features/home/domain/models/folder.dart';
import 'package:distill_ed/features/home/domain/models/note_page.dart';
import 'package:distill_ed/features/home/domain/models/notebook.dart';
import 'package:distill_ed/features/summarize/data/cache/summary_cache.dart';

import '../../support/isar_native_library.dart';

NoteChunkRecord _chunk(int notebookId, int pageId) => NoteChunkRecord()
  ..notebookId = notebookId
  ..pageId = pageId
  ..ordinal = 0
  ..text = 'secret note text'
  ..embedding = [0.0, 1.0]
  ..embeddingModelId = 'm'
  ..contentSignature = 's'
  ..embeddedAt = DateTime(2026, 10, 9);

LectureRecordingRecord _recording(int notebookId, int pageId) =>
    LectureRecordingRecord()
      ..notebookId = notebookId
      ..pageId = pageId
      ..relativePath = 'audio/n${notebookId}_p$pageId.wav'
      ..startedAt = DateTime(2026, 10, 9)
      ..durationMs = 1000;

Future<void> main() async {
  final library = await isarNativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  group('deleting notes deletes what was derived from them', () {
    late Directory dir;
    late Isar isar;

    setUpAll(() async {
      await initIsarForTests(library!);
    });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('purge_test_');
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
        name: 'purge',
      );
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    test('deleting a notebook removes its chunks and recordings, not others',
        () async {
      await isar.writeTxn(() async {
        await isar.noteChunkRecords.putAll([_chunk(1, 10), _chunk(2, 20)]);
        await isar.lectureRecordingRecords
            .putAll([_recording(1, 10), _recording(2, 20)]);
      });

      await NoteRepository(isar).deleteNotebook(1);

      final chunks = await isar.noteChunkRecords.where().findAll();
      expect(chunks.map((c) => c.notebookId), [2]);
      final recs = await isar.lectureRecordingRecords.where().findAll();
      expect(recs.map((r) => r.notebookId), [2]);
    });

    test('deleting a page removes that page\'s chunks and recordings only',
        () async {
      final repo = NoteRepository(isar);
      final nb = await repo.createNotebook('n');
      final pages = PageRepository(isar);
      final second = await pages.createPage(nb.id);
      final first = (await pages.getPagesForNotebook(nb.id)).first;
      await isar.writeTxn(() async {
        await isar.noteChunkRecords
            .putAll([_chunk(nb.id, first.id), _chunk(nb.id, second.id)]);
        await isar.lectureRecordingRecords.putAll(
            [_recording(nb.id, first.id), _recording(nb.id, second.id)]);
      });

      await pages.deletePage(nb.id, second.pageIndex);

      final chunks = await isar.noteChunkRecords.where().findAll();
      expect(chunks.map((c) => c.pageId), [first.id]);
      final recs = await isar.lectureRecordingRecords.where().findAll();
      expect(recs.map((r) => r.pageId), [first.id]);
    });

    test('scene store: delete by id and atomic replace touch only that page',
        () async {
      final store = IsarSceneElementStore(isar: () => isar);
      FreehandElement el(String id) => FreehandElement(
          id: id, zOrder: 0, color: 0, size: 1, points: const []);
      await store.upsertForPage(1, 10, [el('a'), el('b'), el('c')]);
      await store.upsertForPage(1, 11, [el('a')]);

      await store.deleteElements(10, {'a', 'c'});
      expect((await store.loadForPage(10)).map((e) => e.id), ['b']);
      expect((await store.loadForPage(11)).map((e) => e.id), ['a']);

      await store.replaceForPage(1, 10, [el('x'), el('y')]);
      expect(
          (await store.loadForPage(10)).map((e) => e.id).toSet(), {'x', 'y'});
      expect((await store.loadForPage(11)).map((e) => e.id), ['a']);
    });
  }, skip: skip);
}
