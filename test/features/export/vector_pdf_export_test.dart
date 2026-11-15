// The notebook PDF export: page sizes, and the searchable text it lays down
// (handwriting, the words of page pictures, Bangla text boxes).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/page_size.dart';
import 'package:margo/domain/model/page_words.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/features/export/pdf_export_sheet.dart';
import 'package:margo/features/export/vector_pdf_export.dart';
import 'package:margo/features/home/domain/models/note_page.dart';
import 'package:margo/features/home/domain/models/notebook.dart';
import 'package:margo/features/import/page_words_service.dart';

final PdfFonts _fonts = (
  regular: File('assets/fonts/pdf/NotoSans-Regular.ttf').readAsBytesSync(),
  bold: File('assets/fonts/pdf/NotoSans-Bold.ttf').readAsBytesSync(),
  bengali: File('assets/fonts/pdf/NotoSansBengali-Regular.ttf').readAsBytesSync(),
);

Notebook _notebook({int layoutMode = 0, PageSizeKind size = PageSizeKind.fitScreen}) =>
    Notebook()
      ..id = 1
      ..title = 'Biology'
      ..layoutMode = layoutMode
      ..pageSize = size.index
      ..createdAt = DateTime(2026)
      ..modifiedAt = DateTime(2026);

NotePage _page(int id) => NotePage()
  ..id = id
  ..notebookId = 1
  ..pageIndex = id - 1
  ..createdAt = DateTime(2026)
  ..modifiedAt = DateTime(2026);

FreehandElement _ink(String id, double x, double y) => FreehandElement(
      id: id,
      zOrder: 0,
      points: [
        StrokePoint(x: x, y: y, pressure: 0.5),
        StrokePoint(x: x + 60, y: y + 5, pressure: 0.5),
      ],
      color: 0xFF000000,
      size: 3,
    );

class _Words implements PageWordsService {
  @override
  String get docsDir => '';
  @override
  OcrWordsReader get readWords => (_) async => PageWords.empty;
  @override
  PageWords? cached(String relativeImagePath) => null;
  @override
  Future<PageWords> wordsFor(String relativeImagePath) =>
      throw StateError('an export must never read a picture');
  @override
  Future<PageWords> storedWordsFor(String relativeImagePath) async =>
      const PageWords(source: PageWordsSource.pdf, words: [
        PageWord(text: 'Mitosis', box: Rect.fromLTRB(0.1, 0.1, 0.3, 0.15), line: 0),
        PageWord(text: 'phases', box: Rect.fromLTRB(0.32, 0.1, 0.5, 0.15), line: 0),
      ]);
}

VectorPdfExport _export({PageWordsService? words}) => VectorPdfExport(
      docsDir: Directory.systemTemp.path,
      words: words,
      fonts: _fonts,
      background: false,
      compress: false,
    );

int _invisible(String pdf) => '3 Tr'.allMatches(pdf).length;

void main() {
  group('page sizes', () {
    test('a notebook on A4 exports every page at A4, even empty ones', () {
      final sheets = VectorPdfExport.notebookSheets(
        [[], [_ink('a', 10, 10)]],
        _notebook(layoutMode: 1, size: PageSizeKind.a4Portrait),
      )!;
      expect(sheets.bounded, isTrue);
      expect(sheets.rects, everyElement(const Rect.fromLTWH(0, 0, 794, 1123)));
    });

    test('an endless notebook uses its largest content box for every page', () {
      final sheets = VectorPdfExport.notebookSheets([
        [_ink('a', 0, 0)],
        [_ink('b', 1000, 1000), _ink('c', 1400, 1300)],
        [],
      ], _notebook())!;
      expect(sheets.bounded, isFalse);
      final sizes = sheets.rects.map((r) => r.size).toSet();
      expect(sizes, hasLength(1), reason: 'one size for the whole document');
      // Each page is centred on its own content.
      expect(sheets.rects[1].center.dx, greaterThan(1000));
    });

    test('an endless notebook with nothing on it has nothing to export', () {
      expect(VectorPdfExport.notebookSheets([[], []], _notebook()), isNull);
    });

    test('fit screen is not a paper size: it sizes to the content', () {
      final sheets = VectorPdfExport.notebookSheets(
          [[_ink('a', 0, 0)]], _notebook(layoutMode: 1))!;
      expect(sheets.bounded, isFalse);
    });
  });

  group('searchable text', () {
    testWidgets('handwriting is laid invisibly over each written line',
        (tester) async {
      final statuses = <String>[];
      final pdf = await tester.runAsync(() => _export().notebook(
            pages: [_page(1), _page(2)],
            scenes: [
              [_ink('a', 100, 100)],
              [],
            ],
            notebook: _notebook(layoutMode: 1, size: PageSizeKind.a4Portrait),
            readHandwriting: (els) async => [
              (text: 'cell division', bounds: const Rect.fromLTWH(100, 95, 60, 15)),
              (text: '  ', bounds: const Rect.fromLTWH(0, 0, 10, 10)),
            ],
            onStatus: statuses.add,
          ));
      final text = latin1.decode(pdf!);
      expect(_invisible(text), 1, reason: 'the blank line is left out');
      expect(statuses.first, 'Reading handwriting on page 1 of 2…');
      expect(statuses, isNot(contains('Reading handwriting on page 2 of 2…')),
          reason: 'a page with no ink is not read');
      expect(statuses.last, 'Building the PDF…');
    });

    testWidgets('a page the reader fails on is still exported', (tester) async {
      final pdf = await tester.runAsync(() => _export().notebook(
            pages: [_page(1)],
            scenes: [
              [_ink('a', 100, 100)],
            ],
            notebook: _notebook(),
            readHandwriting: (_) async => throw Exception('no model'),
          ));
      expect(latin1.decode(pdf!), contains('/MediaBox'));
    });

    testWidgets('the kept words of a page picture are searchable, and no '
        'picture is read', (tester) async {
      final pdf = await tester.runAsync(() => _export(words: _Words()).notebook(
            pages: [_page(1)],
            scenes: [
              const [
                ImageElement(
                  id: 'pdf',
                  zOrder: 0,
                  geometryData: [0, 0, 794, 1123],
                  relativeImagePath: 'notes/1/imports/p.png',
                ),
              ],
            ],
            notebook: _notebook(layoutMode: 1, size: PageSizeKind.a4Portrait),
          ));
      expect(_invisible(latin1.decode(pdf!)), 2);
    });

    testWidgets('a Bangla text box is drawn as a picture, with its text '
        'searchable over it', (tester) async {
      final pdf = await tester.runAsync(() => _export().notebook(
            pages: [_page(1)],
            scenes: [
              const [
                TextElement(
                  id: 't',
                  zOrder: 0,
                  geometryData: [50, 50, 300, 100],
                  text: 'কোষ বিভাজন',
                  color: 0xFF000000,
                  fontSize: 20,
                ),
              ],
            ],
            notebook: _notebook(layoutMode: 1, size: PageSizeKind.a4Portrait),
          ));
      final text = latin1.decode(pdf!);
      expect(text, contains('/Subtype/Image'));
      // One invisible run per font: the Bangla words, the space between.
      expect(_invisible(text), 3);
    });

    testWidgets('typed English text is real text, not a picture',
        (tester) async {
      final pdf = await tester.runAsync(() => _export().selection(const [
            TextElement(
              id: 't',
              zOrder: 0,
              geometryData: [50, 50, 300, 100],
              text: 'Cell division',
              color: 0xFF000000,
              fontSize: 20,
            ),
          ]));
      final text = latin1.decode(pdf!);
      expect(text, isNot(contains('/Subtype/Image')));
      expect(text, contains(' Tz'));
      expect(_invisible(text), 0);
    });
  });

  test('the document is built in a background isolate', () async {
    final pdf = await VectorPdfExport(
      docsDir: Directory.systemTemp.path,
      fonts: _fonts,
      compress: false,
    ).selection([_ink('a', 0, 0), _ink('b', 50, 80)]);
    expect(latin1.decode(pdf!), contains('/MediaBox'));
  });

  group('the export sheet', () {
    testWidgets('returns the handwriting choice, or null when dismissed',
        (tester) async {
      bool? result = true;
      var done = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPdfExportSheet(context,
                    handwriting: true, pageCount: 3);
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('3 pages, sharp at any zoom. Typed text and the text '
          'of PDF pages can be searched and copied.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pdfExportHandwriting')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pdfExportGo')));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(result, isFalse);
    });
  });
}
