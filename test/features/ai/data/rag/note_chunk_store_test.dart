// The chunk store against a REAL database (docs/TECH_MIGRATION_PLAN.md, phase
// 4.5). Chunks are keyed by page AND the model they were built with, so a page
// can hold its serving chunks and its target chunks at once. The keying lives in
// the store's queries, so a fake would test nothing. Like the read cache test,
// this finds Isar's native library through the package config and skips itself
// if it cannot.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:inkflow/features/ai/data/rag/note_chunk_record.dart';
import 'package:inkflow/features/ai/data/rag/note_chunk_store.dart';
import 'package:inkflow/features/ai/domain/rag/note_chunk.dart';

Future<String?> _nativeLibrary() async {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  final entry = packages
      .cast<Map>()
      .where((p) => p['name'] == 'isar_community_flutter_libs');
  if (entry.isEmpty) return null;
  final rootUri = Uri.parse(entry.first['rootUri'] as String);
  final root = rootUri.isAbsolute
      ? File.fromUri(rootUri).path
      : File.fromUri(config.parent.uri.resolveUri(rootUri)).path;
  final candidate = switch (Abi.current()) {
    Abi.linuxX64 => '$root/linux/libisar.so',
    Abi.windowsX64 => '$root/windows/isar.dll',
    Abi.macosX64 || Abi.macosArm64 => '$root/macos/libisar.dylib',
    _ => null,
  };
  return candidate != null && File(candidate).existsSync() ? candidate : null;
}

NoteChunk _chunk(
  int page,
  int ordinal,
  String model, {
  String signature = 'sig',
}) =>
    NoteChunk(
      notebookId: 1,
      pageId: page,
      ordinal: ordinal,
      text: 'page $page chunk $ordinal',
      embedding: const [0.0, 1.0, 0.0],
      embeddingModelId: model,
      contentSignature: signature,
      embeddedAt: DateTime(2026, 10, 8),
    );

/// How many of the notebook's chunks each model has.
Map<String, int> _countsByModel(List<NoteChunk> chunks) {
  final counts = <String, int>{};
  for (final c in chunks) {
    counts[c.embeddingModelId] = (counts[c.embeddingModelId] ?? 0) + 1;
  }
  return counts;
}

Future<void> main() async {
  final library = await _nativeLibrary();
  final skip = library == null ? 'Isar native library not found' : null;

  group('the chunk store, keyed by page and model', () {
    late Directory dir;
    late Isar isar;
    late IsarNoteChunkStore store;

    setUpAll(() async {
      await Isar.initializeIsarCore(libraries: {Abi.current(): library!});
    });

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('chunk_store_test_');
      isar = await Isar.open(
        [NoteChunkRecordSchema],
        directory: dir.path,
        name: 'chunks',
      );
      store = IsarNoteChunkStore(isar: () => isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    test('replacing a page for one model keeps its chunks from another model',
        () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving'), _chunk(1, 1, 'serving')]);

      await store.replaceForPage(1, [_chunk(1, 0, 'target')]);

      expect(_countsByModel(await store.forNotebook(1)),
          {'serving': 2, 'target': 1});
    });

    test('replacing a page for a model swaps only that model\'s chunks',
        () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving')]);
      await store.replaceForPage(1, [_chunk(1, 0, 'target'), _chunk(1, 1, 'target')]);

      await store.replaceForPage(1, [_chunk(1, 0, 'target')]);

      expect(_countsByModel(await store.forNotebook(1)),
          {'serving': 1, 'target': 1});
    });

    test('a notebook is read from cache until something changes it, even behind the store',
        () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving')]);

      final first = await store.forNotebook(1);
      expect(identical(await store.forNotebook(1), first), isTrue);

      // content_purge deletes through Isar directly, not through the store.
      await isar.writeTxn(
          () => isar.noteChunkRecords.filter().pageIdEqualTo(1).deleteAll());
      expect(await store.forNotebook(1), isEmpty);

      await store.replaceForPage(1, [_chunk(1, 0, 'serving')]);
      await store.replaceForPage(1, [_chunk(1, 0, 'serving', signature: 'edited')]);
      expect((await store.forNotebook(1)).single.contentSignature, 'edited');
    });

    test('the index state is kept per model', () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving', signature: 'old-text')]);
      await store.replaceForPage(1, [_chunk(1, 0, 'target', signature: 'new-text')]);

      expect((await store.indexStateForPage(1, 'serving'))?.contentSignature,
          'old-text');
      expect((await store.indexStateForPage(1, 'target'))?.contentSignature,
          'new-text');
      expect(await store.indexStateForPage(1, 'other'), isNull);
    });

    test('deleting a page drops every model\'s chunks for that page, and no other',
        () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving')]);
      await store.replaceForPage(1, [_chunk(1, 0, 'target')]);
      await store.replaceForPage(2, [_chunk(2, 0, 'serving')]);

      await store.deleteForPage(1);

      final left = await store.forNotebook(1);
      expect(left.map((c) => c.pageId).toSet(), {2});
    });

    test('replacing a page with no chunks clears it, as before', () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving')]);
      await store.replaceForPage(2, [_chunk(2, 0, 'serving')]);

      await store.replaceForPage(1, const []);

      expect((await store.forNotebook(1)).map((c) => c.pageId).toSet(), {2});
    });

    test('deleting a model drops its chunks on every page and keeps the others',
        () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving')]);
      await store.replaceForPage(1, [_chunk(1, 0, 'target')]);
      await store.replaceForPage(2, [_chunk(2, 0, 'serving')]);

      await store.deleteModel('serving');

      expect(_countsByModel(await store.forNotebook(1)), {'target': 1});
    });

    test('deleting every model but the kept one leaves only the kept chunks',
        () async {
      await store.replaceForPage(1, [_chunk(1, 0, 'serving')]);
      await store.replaceForPage(1, [_chunk(1, 0, 'target')]);
      await store.replaceForPage(2, [_chunk(2, 0, 'old')]);

      await store.deleteModelsExcept({'target'});

      expect(_countsByModel(await store.forNotebook(1)), {'target': 1});
    });
  }, skip: skip);
}
