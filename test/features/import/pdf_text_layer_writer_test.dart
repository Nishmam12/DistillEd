import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/import/pdf_text_layer.dart';

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
}

void main() {
  late Directory dir;

  /// The absolute page-image paths an import produced (the PNGs themselves are
  /// irrelevant here — only the paths beside which text is written).
  List<String> images(int count) => [
        for (var i = 1; i <= count; i++) '${dir.path}/imports/pdf_abc_$i.png',
      ];

  String sidecar(int page) => '${dir.path}/imports/pdf_abc_$page.txt';

  setUp(() => dir = Directory.systemTemp.createTempSync('inkflow_pdftext_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('each page\'s text is written beside its image', () async {
    final source = _FakeSource(['First slide text', 'Second slide text']);

    await PdfTextLayerWriter(source)
        .write(pdfPath: '/x.pdf', pageImagePaths: images(2));

    expect(File(sidecar(1)).readAsStringSync(), 'First slide text');
    expect(File(sidecar(2)).readAsStringSync(), 'Second slide text');
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
}
