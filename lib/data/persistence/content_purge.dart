// Everything derived from a notebook's or page's content, in one place, so
// deleting the note really deletes it: RAG chunks (verbatim text + embeddings),
// summaries, study memory, flashcards, quiz history, plans and lecture
// recordings. Add a new per-notebook collection here or it will outlive its
// notebook.

import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_paths.dart';
import '../../features/ai/data/flashcards/flashcard_record.dart';
import '../../features/ai/data/memory/concept_mastery_record.dart';
import '../../features/ai/data/memory/concept_relation_record.dart';
import '../../features/ai/data/memory/quiz_attempt_record.dart';
import '../../features/ai/data/rag/note_chunk_record.dart';
import '../../features/ai/data/study_planner/study_plan_record.dart';
import '../../features/summarize/data/cache/summary_cache.dart';
import 'lecture_recording_record.dart';

/// Deletes the derived rows of a whole notebook. Call inside a write
/// transaction; returns the recordings' relative audio paths so the caller can
/// delete the files once the transaction has committed.
Future<List<String>> purgeNotebookRows(Isar isar, int notebookId) async {
  final recordings = isar.lectureRecordingRecords.filter().notebookIdEqualTo(
    notebookId,
  );
  final audio = (await recordings.findAll())
      .map((r) => r.relativePath)
      .toList();
  await recordings.deleteAll();
  await isar.noteChunkRecords
      .filter()
      .notebookIdEqualTo(notebookId)
      .deleteAll();
  await isar.summaryCaches.filter().notebookIdEqualTo(notebookId).deleteAll();
  await isar.flashcardRecords
      .filter()
      .notebookIdEqualTo(notebookId)
      .deleteAll();
  await isar.quizAttemptRecords
      .filter()
      .notebookIdEqualTo(notebookId)
      .deleteAll();
  await isar.studyPlanRecords
      .filter()
      .notebookIdEqualTo(notebookId)
      .deleteAll();
  await isar.conceptMasteryRecords
      .filter()
      .notebookIdEqualTo(notebookId)
      .deleteAll();
  await isar.conceptRelationRecords
      .filter()
      .notebookIdEqualTo(notebookId)
      .deleteAll();
  return audio;
}

/// Deletes the derived rows of one page (same contract as [purgeNotebookRows]).
/// Notebook-level summaries are dropped too: they were written from content
/// that no longer exists. Concept mastery is per-notebook, so it stays.
Future<List<String>> purgePageRows(
  Isar isar, {
  required int notebookId,
  required int pageId,
}) async {
  final recordings = isar.lectureRecordingRecords.filter().pageIdEqualTo(
    pageId,
  );
  final audio = (await recordings.findAll())
      .map((r) => r.relativePath)
      .toList();
  await recordings.deleteAll();
  await isar.noteChunkRecords.filter().pageIdEqualTo(pageId).deleteAll();
  await isar.flashcardRecords.filter().pageIdEqualTo(pageId).deleteAll();
  await isar.quizAttemptRecords.filter().pageIdEqualTo(pageId).deleteAll();
  await isar.summaryCaches.filter().notebookIdEqualTo(notebookId).deleteAll();
  return audio;
}

/// Best-effort file cleanup after the rows are gone. A leftover file is
/// storage waste, not corruption, so failures are swallowed — per file, so one
/// that will not delete does not strand the rest or the notebook directory.
/// [fileRelativePaths] are any other files (page ink, imported images and their
/// text sidecars) relative to app documents.
Future<void> deleteContentFiles({
  int? notebookDirId,
  List<String> audioRelativePaths = const [],
  List<String> fileRelativePaths = const [],
}) async {
  String docs;
  try {
    docs = (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    return;
  }
  Future<void> rm(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  for (final rel in audioRelativePaths) {
    await rm('$docs/$rel');
    await rm('$docs/${StoragePaths.transcriptSidecar(rel)}');
  }
  for (final rel in fileRelativePaths) {
    await rm('$docs/$rel');
  }
  if (notebookDirId != null) {
    try {
      final dir = Directory(
        StoragePaths.getNotebookDir(docs, '$notebookDirId'),
      );
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
