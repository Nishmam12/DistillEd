import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/page_links.dart';
import 'package:margo/domain/model/page_words.dart';
import 'package:margo/features/import/pdf_text_layer.dart';
import 'dart:ui' show Rect;

/// A PDF "reader" that returns a fixed text per page, or fails.
class _FakeSource implements PdfTextSource {
  final List<String> pages;
  final Object? failure;
  int opened = 0;

  _FakeSource(this.pages, {this.failure});

  @override
  Future<List<String>> pagesText(String pdfPath) async {
    opened++;
    final f = failure;
    if (f != null) throw f;
    return pages;
  }

  int wordsRead = 0;

  /// Pages (0-based) whose words cannot be placed, as a turned page's cannot.
  Set<int> unplaceable = {};
  int linksRead = 0;

  @override
  Future<List<PageLinks>> pagesLinks(String pdfPath) async {
    linksRead++;
    final f = failure;
    if (f != null) throw f;
    return [
      for (var i = 0; i < pages.length; i++)
        PageLinks(links: [
          PageLink(rect: const Rect.fromLTRB(0, 0, 0.5, 0.1), destPage: i + 1),
        ], outline: [
          OutlineEntry(title: 'Part ${i + 1}', depth: 0, order: i),
        ]),
    ];
  }

  @override
  Future<List<PageWords?>> pagesWords(String pdfPath) async {
    wordsRead++;
    final f = failure;
    if (f != null) throw f;
    return [
      for (var i = 0; i < pages.length; i++)
        if (unplaceable.contains(i))
          null
        else
          PageWords(source: PageWordsSource.pdf, words: [
            if (pages[i].isNotEmpty)
              PageWord(
                  text: pages[i].split(' ').first,
                  box: const Rect.fromLTRB(0.1, 0.1, 0.3, 0.15),
                  line: 0),
          ]),
    ];
  }
}

void main() {
  late Directory dir;

  /// The absolute page-image paths an import produced (the PNGs themselves are
  /// irrelevant here — only the paths beside which text is written).
  List<String> images(int count) => [
        for (var i = 1; i <= count; i++) '${dir.path}/imports/pdf_abc_$i.png',
      ];

  String sidecar(int page) => '${dir.path}/imports/pdf_abc_$page.txt';

  setUp(() => dir = Directory.systemTemp.createTempSync('margo_pdftext_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('each page\'s text is written beside its image', () async {
    final source = _FakeSource(['First slide text', 'Second slide text']);

    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));

    expect(File(sidecar(1)).readAsStringSync(), 'First slide text');
    expect(File(sidecar(2)).readAsStringSync(), 'Second slide text');
  });

  test('importing pages 3–4 keeps the text of pages 3–4, not 1–2', () async {
    final source = _FakeSource(['one', 'two', 'three', 'four']);

    await PdfTextLayerWriter(source).write(
      pdfPath: '/x.pdf',
      pageImagePaths: [
        '${dir.path}/imports/pdf_abc_3.png',
        '${dir.path}/imports/pdf_abc_4.png',
      ],
      firstPage: 3,
    );

    expect(File(sidecar(3)).readAsStringSync(), 'three');
    expect(File(sidecar(4)).readAsStringSync(), 'four');
  });

  test('a page with no text gets an EMPTY file — "looked, found nothing"',
      () async {
    final source = _FakeSource(['Some text', '   \n ', '']);

    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(3));

    expect(File(sidecar(2)).existsSync(), isTrue);
    expect(File(sidecar(2)).readAsStringSync(), isEmpty);
    expect(File(sidecar(3)).readAsStringSync(), isEmpty);
  });

  test('a PDF whose pages already have their text is not opened again',
      () async {
    final first = _FakeSource(['One', '']);
    await PdfTextLayerWriter(first)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));

    final again = _FakeSource(['One', '']);
    await PdfTextLayerWriter(again)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));

    expect(first.opened, 1);
    expect(again.opened, 0,
        reason: 're-importing the same PDF costs nothing, like its page images');
  });

  test('existing text is never overwritten', () async {
    File(sidecar(1))
      ..createSync(recursive: true)
      ..writeAsStringSync('from an earlier import');
    final source = _FakeSource(['new', 'second']);

    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));

    expect(File(sidecar(1)).readAsStringSync(), 'from an earlier import');
    expect(File(sidecar(2)).readAsStringSync(), 'second');
  });

  test('a PDF that cannot be read never fails the import', () async {
    final source = _FakeSource(const [], failure: StateError('PDFium missing'));

    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));

    expect(File(sidecar(1)).existsSync(), isFalse);
    expect(File(sidecar(2)).existsSync(), isFalse);
  });

  test('pages the reader returned nothing for are left unwritten, not empty',
      () async {
    // Three images but text for only two pages: the third is UNKNOWN, and an
    // empty file would claim it had been read and found blank.
    final source = _FakeSource(['One', 'Two']);

    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(3));

    expect(File(sidecar(2)).existsSync(), isTrue);
    expect(File(sidecar(3)).existsSync(), isFalse);
  });

  test('text beyond the imported pages is ignored', () async {
    final source = _FakeSource(['One', 'Two', 'Three']);

    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));

    expect(File(sidecar(3)).existsSync(), isFalse);
  });

  test('no pages, nothing to do — and the PDF is not even opened', () async {
    final source = _FakeSource(['One']);

    await PdfTextLayerWriter(source).write(pdfPath: '/x.pdf', pageImagePaths: []);

    expect(source.opened, 0);
  });

  String words(int page) => '${dir.path}/imports/pdf_abc_$page.words.json';

  test('each page also gets its words, beside its text', () async {
    final source = _FakeSource(['First slide', '']);
    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));
    final first = PageWords.decode(File(words(1)).readAsStringSync());
    expect(first.words.single.text, 'First');
    // A page with no text still gets a file, so it is not read again later.
    expect(PageWords.decode(File(words(2)).readAsStringSync()).isEmpty, isTrue);
  });

  test('a page whose words cannot be placed keeps no words file, so its picture '
      'is read when words are first needed', () async {
    final source = _FakeSource(['a', 'b'])..unplaceable = {1};
    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));
    expect(File(words(1)).existsSync(), isTrue);
    expect(File(words(2)).existsSync(), isFalse);
    expect(File(sidecar(2)).readAsStringSync(), 'b', reason: 'its text is kept');
  });

  test('re-importing a PDF imported before word boxes fills in the words only',
      () async {
    for (var i = 1; i <= 2; i++) {
      File(sidecar(i))
        ..createSync(recursive: true)
        ..writeAsStringSync('kept');
    }
    final source = _FakeSource(['new text', 'more']);
    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));
    expect(File(words(1)).existsSync(), isTrue);
    expect(source.wordsRead, 1);
    expect(source.opened, 0, reason: 'the text was there: not read again');
    expect(File(sidecar(1)).readAsStringSync(), 'kept');
  });

  String links(int page) => '${dir.path}/imports/pdf_abc_$page.links.json';

  test('each page also gets its links and contents entries', () async {
    final source = _FakeSource(['a', 'b']);
    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));
    final second = PageLinks.decode(File(links(2)).readAsStringSync());
    expect(second.links.single.destPage, 2);
    expect(second.outline.single.title, 'Part 2');
  });

  test('importing pages 3-4 keeps the links of pages 3-4, and a link to a '
      'page that was not imported is not lost', () async {
    final source = _FakeSource(['1', '2', '3', '4']);
    await PdfTextLayerWriter(source).write(
      pdfPath: '/x.pdf',
      pageImagePaths: [
        '${dir.path}/imports/pdf_abc_3.png',
        '${dir.path}/imports/pdf_abc_4.png',
      ],
      firstPage: 3,
    );
    expect(PageLinks.decode(File(links(3)).readAsStringSync()).outline.single.title,
        'Part 3');
    expect(File(links(1)).existsSync(), isFalse);
  });

  test('re-importing a PDF imported before links were kept fills them in only',
      () async {
    for (var i = 1; i <= 2; i++) {
      File(sidecar(i))
        ..createSync(recursive: true)
        ..writeAsStringSync('kept');
      File(words(i)).writeAsStringSync(PageWords.empty.encode());
    }
    final source = _FakeSource(['x', 'y']);
    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));
    expect(File(links(1)).existsSync(), isTrue);
    expect(source.linksRead, 1);
    expect(source.wordsRead, 0, reason: 'the words were there');
    expect(source.opened, 0, reason: 'the text was there');
  });
}
