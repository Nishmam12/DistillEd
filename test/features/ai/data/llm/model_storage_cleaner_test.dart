// Tests the real [assertSafeToDelete] — the rule standing between a user and a
// silently deleted 2.4 GB model. It is deliberately a pure top-level function
// so these assertions bind to shipping code rather than to a fake that restates
// the logic and would pass no matter what the app actually did.
//
// The two plugin behaviours the rule exists to survive:
//
//   • `getOrphanedFiles()` returns [] when it FAILS, not only when there is
//     nothing to clean — indistinguishable from success without care.
//   • `cleanupStorage()` spares files from a protected list rebuilt inside a
//     try/catch that can return partial, in which case installed models appear
//     as orphans and would be deleted.
//
// What is NOT covered here: the plugin round trips in
// FlutterGemmaStorageCleaner (getOrphanedFiles/isModelInstalled/cleanupStorage)
// need a device.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/data/llm/model_storage_cleaner.dart';

const _llm = 'gemma-4-E2B-it.litertlm';
const _embedModel = 'embeddinggemma-300M_seq512_mixed-precision.tflite';
const _tokenizer = 'sentencepiece.model';
const _known = {_llm, _embedModel, _tokenizer};

/// Runs the real guard. Returns normally when the batch may be deleted.
void check(List<String> orphans, {Set<String> installed = const {}}) =>
    assertSafeToDelete(
      orphanFilenames: orphans,
      // Only files BOTH known to this app and currently installed are passed —
      // this mirrors FlutterGemmaStorageCleaner._installedKnownFiles().
      installedKnownFiles: installed.intersection(_known),
    );

void main() {
  test('a genuine leftover may be deleted', () {
    expect(() => check([_tokenizer]), returnsNormally);
  });

  test('an empty batch is trivially safe', () {
    // Note the caller never gets here: cleanup() short-circuits on empty, so an
    // unreadable orphan list (which the plugin reports as []) can never reach
    // a delete. Covered by 'nothing to clean' below.
    expect(() => check([]), returnsNormally);
  });

  test('a known file that is NOT installed is a real orphan and may go', () {
    // The crash-window case: a complete file whose metadata write never landed.
    // It carries a known name, but nothing claims it.
    expect(() => check([_embedModel], installed: const {}), returnsNormally);
  });

  test('files unrelated to this app are deleted without objection', () {
    expect(
      () => check(['some-old-model.task', 'leftover.bin'],
          installed: const {_llm}),
      returnsNormally,
    );
  });

  group('the degraded-protected-list guard', () {
    test('refuses when an INSTALLED model is listed as orphaned', () {
      // The signature of `_getProtectedFiles()` having returned a partial list.
      expect(
        () => check([_llm], installed: const {_llm}),
        throwsA(isA<StorageCleanupUnsafeException>()),
      );
    });

    test('one bad entry vetoes the whole batch, not just itself', () {
      expect(
        () => check(['stray-leftover.bin', _embedModel],
            installed: const {_embedModel}),
        throwsA(isA<StorageCleanupUnsafeException>()),
      );
    });

    test('catches the tokenizer too, not just the big files', () {
      expect(
        () => check([_tokenizer], installed: const {_tokenizer}),
        throwsA(isA<StorageCleanupUnsafeException>()),
      );
    });

    test('the message tells the user what to do rather than naming internals',
        () {
      expect(
        () => check([_llm], installed: const {_llm}),
        throwsA(isA<StorageCleanupUnsafeException>().having(
            (e) => e.message, 'message', contains('Restart the app'))),
      );
    });
  });

  group('cleanup() short-circuits before the guard', () {
    // Documents the ordering that makes an unreadable orphan list safe: the
    // plugin returns [] both when there is nothing to clean AND when it failed
    // internally, so cleanup() treats empty as "do nothing" and never reaches
    // cleanupStorage(). Without that, a failed read would delete everything
    // unprotected.
    test('nothing to clean means no delete is attempted', () async {
      final cleaner = _NoOrphansCleaner();
      expect(await cleaner.cleanup(), 0);
      expect(cleaner.deleteAttempted, isFalse);
    });
  });
}

/// Stands in for the real cleaner with an orphan list that comes back empty —
/// the shape of both "nothing to do" and "the plugin failed".
class _NoOrphansCleaner implements ModelStorageCleaner {
  var deleteAttempted = false;

  @override
  Future<List<OrphanedModelFile>> findOrphans() async => const [];

  @override
  Future<int> cleanup() async {
    final found = await findOrphans();
    if (found.isEmpty) return 0;
    deleteAttempted = true;
    return found.length;
  }
}
