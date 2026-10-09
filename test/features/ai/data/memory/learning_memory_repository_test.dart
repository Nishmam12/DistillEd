// The Learning Memory store on a real database: what the Context Engine records
// about a page is what the knowledge graph later reads back, per notebook and
// per page.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:distill_ed/features/ai/data/memory/concept_mastery_record.dart';
import 'package:distill_ed/features/ai/data/memory/concept_relation_record.dart';
import 'package:distill_ed/features/ai/data/memory/learning_memory_repository.dart';
import 'package:distill_ed/features/ai/data/memory/learning_preferences_record.dart';
import 'package:distill_ed/features/ai/data/memory/quiz_attempt_record.dart';

import '../../../../support/isar_native_library.dart';

Future<void> main() async {
  final library = await isarNativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  group('IsarLearningMemoryRepository', () {
    late Directory dir;
    late Isar isar;
    late IsarLearningMemoryRepository memory;

    setUpAll(() async {
      if (library != null) await initIsarForTests(library);
    });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('learning_memory_test_');
      isar = await Isar.open(
        [
          ConceptMasteryRecordSchema,
          ConceptRelationRecordSchema,
          QuizAttemptRecordSchema,
          LearningPreferencesRecordSchema,
        ],
        directory: dir.path,
        name: 'memory',
      );
      memory = IsarLearningMemoryRepository(isar: () => isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    Future<Set<String>> namesOn(int notebookId) async => {
          for (final c in await memory.allConcepts(notebookId)) c.conceptName,
        };

    test('the concepts a page teaches are recorded for its notebook', () async {
      await memory.observePageContext(
        notebookId: 1,
        keyConcepts: ['Photosynthesis', 'Chlorophyll'],
        pageId: 7,
      );

      expect(await namesOn(1), {'Photosynthesis', 'Chlorophyll'});
      expect(await namesOn(2), isEmpty, reason: 'other notebooks are not touched');
    }, skip: skip);

    test('a concept counts toward the page it was last seen on', () async {
      await memory.observePageContext(
          notebookId: 1, keyConcepts: ['Cells'], pageId: 7);
      await memory.observePageContext(
          notebookId: 1, keyConcepts: ['Atoms'], pageId: 8);

      Future<Set<String>> onPages(Set<int> pages) async => {
            for (final c
                in await memory.conceptsForPages(1, pages))
              c.conceptName,
          };
      expect(await onPages({7}), {'Cells'});
      expect(await onPages({8}), {'Atoms'});
      expect(await onPages({7, 8}), {'Cells', 'Atoms'});
      expect(await onPages({9}), isEmpty);
    }, skip: skip);

    test('seeing a concept again does not record it twice', () async {
      await memory.observePageContext(
          notebookId: 1, keyConcepts: ['Cells'], pageId: 7);
      await memory.observePageContext(
          notebookId: 1, keyConcepts: ['cells'], pageId: 8);

      expect(await memory.allConcepts(1), hasLength(1),
          reason: 'concept identity is the normalised name');
    }, skip: skip);

    test('a blank concept name is ignored', () async {
      await memory.observePageContext(
        notebookId: 1,
        keyConcepts: ['   ', 'Real concept'],
        pageId: 7,
      );

      expect(await namesOn(1), {'Real concept'});
    }, skip: skip);
  });
}
