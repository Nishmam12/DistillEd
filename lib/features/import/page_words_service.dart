// The words of a page picture, when the user needs them: selecting text on it
// or highlighting over it.
//
// First the sidecar the PDF import wrote (`StoragePaths.pdfWordsSidecar`). A
// picture with none (a scan, a photo, or a PDF imported before word boxes were
// kept) is read once on the device with ML Kit and the result written to the
// same sidecar, so it is instant the next time. Nothing here runs unless the
// user asks: no background reading of every page.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_paths.dart';
import '../../domain/model/page_words.dart';
import '../../editor/state/scene_controller.dart' show appDocsPathProvider;
import '../ai/presentation/ai_providers.dart'
    show imageTextRecognitionServiceProvider;

/// Reads the words off the picture at an absolute path (ML Kit on the device).
typedef OcrWordsReader = Future<PageWords> Function(String absolutePath);

class PageWordsService {
  PageWordsService({required this.docsDir, required this.readWords});

  final String docsDir;
  final OcrWordsReader readWords;
  final Map<String, PageWords> _cache = {};
  final Map<String, Future<PageWords>> _pending = {};

  /// Already loaded, without waiting: null until [wordsFor] has finished once.
  PageWords? cached(String relativeImagePath) => _cache[relativeImagePath];

  /// The words of the picture at [relativeImagePath]. Never throws: a picture
  /// that cannot be read has no words.
  Future<PageWords> wordsFor(String relativeImagePath) {
    final hit = _cache[relativeImagePath];
    if (hit != null) return SynchronousFuture(hit);
    return _pending[relativeImagePath] ??= _load(relativeImagePath)
        .whenComplete(() {
      _pending.remove(relativeImagePath);
    });
  }

  /// The words already kept for the picture, without ever reading the picture:
  /// for an export, which must not run OCR over a whole notebook. Empty when
  /// there is no sidecar yet.
  Future<PageWords> storedWordsFor(String relativeImagePath) async {
    final hit = _cache[relativeImagePath];
    if (hit != null) return hit;
    if (!StoragePaths.isSafeRelativePath(relativeImagePath)) {
      return PageWords.empty;
    }
    final sidecar =
        File(StoragePaths.pdfWordsSidecar('$docsDir/$relativeImagePath'));
    try {
      if (!await sidecar.exists()) return PageWords.empty;
      return PageWords.decode(await sidecar.readAsString());
    } catch (_) {
      return PageWords.empty;
    }
  }

  Future<PageWords> _load(String rel) async {
    if (!StoragePaths.isSafeRelativePath(rel)) return PageWords.empty;
    final image = '$docsDir/$rel';
    final sidecar = File(StoragePaths.pdfWordsSidecar(image));
    PageWords words;
    try {
      if (await sidecar.exists()) {
        words = PageWords.decode(await sidecar.readAsString());
      } else {
        if (!await File(image).exists()) return PageWords.empty;
        words = await readWords(image);
        final tmp = File('${sidecar.path}.tmp');
        await tmp.writeAsString(words.encode(), flush: true);
        await tmp.rename(sidecar.path);
      }
    } catch (e) {
      debugPrint('[PageWords] could not read the words of $rel: $e');
      return PageWords.empty;
    }
    _cache[rel] = words;
    if (_cache.length > 64) _cache.remove(_cache.keys.first);
    return words;
  }
}

/// The words of one picture, by relative path: the kept ones, or read off the
/// picture once. Only watched after a search opened the page.
final pageWordsProvider = FutureProvider.autoDispose.family<PageWords, String>(
    (ref, rel) => ref.watch(pageWordsServiceProvider).wordsFor(rel));

final pageWordsServiceProvider = Provider<PageWordsService>((ref) {
  final ocr = ref.watch(imageTextRecognitionServiceProvider);
  return PageWordsService(
    docsDir: ref.watch(appDocsPathProvider),
    readWords: ocr.words,
  );
});
