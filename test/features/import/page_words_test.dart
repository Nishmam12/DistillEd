import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/constants/storage_paths.dart';
import 'package:margo/domain/model/page_words.dart';
import 'package:margo/features/import/page_words_service.dart';
import 'package:margo/features/import/pdf_text_layer.dart';

void main() {
  group('PageWords file', () {
    test('round trip', () {
      const words = PageWords(source: PageWordsSource.ocr, words: [
        PageWord(text: 'Mitosis', box: Rect.fromLTRB(0.1, 0.2, 0.3, 0.25), line: 0),
        PageWord(text: 'phases', box: Rect.fromLTRB(0.1, 0.3, 0.3, 0.35), line: 1),
      ]);
      final back = PageWords.decode(words.encode());
      expect(back.source, PageWordsSource.ocr);
      expect(back.words, words.words);
    });

    test('a damaged file reads as no words, and bad entries are skipped', () {
      expect(PageWords.decode('not json').isEmpty, isTrue);
      expect(PageWords.decode('[1, 2]').isEmpty, isTrue);
      final back = PageWords.decode('{"v":1,"source":"pdf","words":['
          '{"t":"ok","l":0,"b":[0,0,0.5,0.1]},'
          '{"t":"","b":[0,0,1,1]},'
          '{"t":"x","b":[0,0]},'
          '{"t":"y","b":[0,"a",1,1]}]}');
      expect(back.words.map((w) => w.text), ['ok']);
    });
  });

  group('wordsFromPdfChars', () {
    // A 100 x 200 pt page. PDF y runs up from the bottom.
    PdfCharRect at(double x, double top, {double h = 10, double w = 5}) =>
        (left: x, bottom: top - h, right: x + w, top: top);

    test('splits words, flips y and normalises, and counts lines', () {
      const text = 'Hi yo\nok';
      final rects = [
        at(10, 190), at(15, 190), // Hi
        at(20, 190), // space
        at(25, 190), at(30, 190), // yo
        at(35, 190), // newline
        at(10, 170), at(15, 170), // ok
      ];
      final words = wordsFromPdfChars(
          text: text, rects: rects, pageWidth: 100, pageHeight: 200);
      expect(words.words.map((w) => w.text), ['Hi', 'yo', 'ok']);
      expect(words.words.map((w) => w.line), [0, 0, 1]);
      final hi = words.words.first.box;
      expect(hi.left, closeTo(0.10, 1e-9));
      expect(hi.right, closeTo(0.20, 1e-9));
      expect(hi.top, closeTo(10 / 200, 1e-9)); // 200 - 190
      expect(hi.bottom, closeTo(20 / 200, 1e-9));
    });

    test('a word placed below without a line break still starts a line', () {
      final words = wordsFromPdfChars(
        text: 'a b',
        rects: [at(10, 190), at(15, 190), at(10, 150)],
        pageWidth: 100,
        pageHeight: 200,
      );
      expect(words.words.map((w) => w.line), [0, 1]);
    });

    test('hidden text (zero-size or off the page) is left out', () {
      final words = wordsFromPdfChars(
        text: 'ok no',
        rects: [
          at(10, 190), at(15, 190), at(20, 190),
          at(30, 190, h: 0), at(35, 190, h: 0), // zero-size font
        ],
        pageWidth: 100,
        pageHeight: 200,
      );
      expect(words.words.map((w) => w.text), ['ok']);
    });

    test('mismatched input gives no words', () {
      expect(
          wordsFromPdfChars(
                  text: 'abc', rects: [at(0, 10)], pageWidth: 100, pageHeight: 200)
              .isEmpty,
          isTrue);
    });
  });

  group('PageWordsService', () {
    late Directory docs;
    const rel = 'notes/1/imports/pdf_abc_1.png';
    setUp(() {
      docs = Directory.systemTemp.createTempSync('margo_words_');
      File('${docs.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
    });
    tearDown(() => docs.deleteSync(recursive: true));

    const ocrWords = PageWords(source: PageWordsSource.ocr, words: [
      PageWord(text: 'scan', box: Rect.fromLTRB(0, 0, 0.2, 0.1), line: 0),
    ]);

    test('reads the sidecar the import wrote, without OCR', () async {
      const pdfWords = PageWords(source: PageWordsSource.pdf, words: [
        PageWord(text: 'pdf', box: Rect.fromLTRB(0, 0, 0.2, 0.1), line: 0),
      ]);
      File(StoragePaths.pdfWordsSidecar('${docs.path}/$rel'))
          .writeAsStringSync(pdfWords.encode());
      var reads = 0;
      final service = PageWordsService(
          docsDir: docs.path,
          readWords: (_) async {
            reads++;
            return ocrWords;
          });
      final words = await service.wordsFor(rel);
      expect(words.words.single.text, 'pdf');
      expect(reads, 0);
    });

    test('with no sidecar: reads the picture once and keeps the result',
        () async {
      var reads = 0;
      PageWordsService make() => PageWordsService(
          docsDir: docs.path,
          readWords: (_) async {
            reads++;
            return ocrWords;
          });
      final service = make();
      final both = await Future.wait(
          [service.wordsFor(rel), service.wordsFor(rel)]);
      expect(both[0].words.single.text, 'scan');
      expect(reads, 1, reason: 'two asks at once share one read');
      expect(service.cached(rel), isNotNull);

      // A new session reads the file, not the picture.
      final words = await make().wordsFor(rel);
      expect(words.words.single.text, 'scan');
      expect(reads, 1);
    });

    test('a picture that cannot be read has no words, and no file is kept',
        () async {
      final service = PageWordsService(
          docsDir: docs.path, readWords: (_) async => throw Exception('no'));
      expect((await service.wordsFor(rel)).isEmpty, isTrue);
      expect(
          File(StoragePaths.pdfWordsSidecar('${docs.path}/$rel')).existsSync(),
          isFalse);
    });

    test('a path outside the app files is refused', () async {
      final service = PageWordsService(
          docsDir: docs.path, readWords: (_) async => ocrWords);
      expect((await service.wordsFor('../secret.png')).isEmpty, isTrue);
    });
  });
}
