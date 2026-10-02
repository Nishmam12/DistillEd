// Reads a REAL PDF through PDFium, so it needs the native library — which
// `flutter test` does not build on a desktop host. Point PDFIUM_PATH at a
// libpdfium (the pdfium-binaries release the app bundles, e.g.
// .../chromium%2F7811/pdfium-linux-x64.tgz → lib/libpdfium.so) to run it; without
// one it skips, so the suite stays green on machines that have none.
//
//   PDFIUM_PATH=/path/to/libpdfium.so flutter test test/features/import/pdfium_text_source_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/import/pdf_text_layer.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  final pdfium = Platform.environment['PDFIUM_PATH'];
  final skip = pdfium == null || !File(pdfium).existsSync()
      ? 'set PDFIUM_PATH to a libpdfium to run this'
      : null;

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('inkflow_pdfium_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> pdfWith(List<String?> pageTexts) async {
    final doc = pw.Document();
    for (final text in pageTexts) {
      doc.addPage(pw.Page(
          build: (_) => text == null
              ? pw.SizedBox()
              : pw.Center(child: pw.Text(text, style: const pw.TextStyle(fontSize: 14)))));
    }
    final file = File('${dir.path}/doc.pdf')..writeAsBytesSync(await doc.save());
    return file.path;
  }

  test('reads the text of every page, in order, blank pages included',
      () async {
    final path = await pdfWith([
      'Photosynthesis converts light into chemical energy.',
      null, // a page with nothing on it, like a scan with no text layer
      'Cellular respiration releases that energy as ATP.',
    ]);

    final pages =
        await PdfiumTextSource(cacheDir: () async => dir.path).pagesText(path);

    expect(pages, hasLength(3));
    expect(pages[0].trim(), 'Photosynthesis converts light into chemical energy.');
    expect(pages[1].trim(), isEmpty);
    expect(pages[2].trim(), 'Cellular respiration releases that energy as ATP.');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('a file that is not a PDF is an error, not an empty result', () async {
    final file = File('${dir.path}/not.pdf')..writeAsStringSync('hello');

    await expectLater(
        PdfiumTextSource(cacheDir: () async => dir.path).pagesText(file.path),
        throwsA(anything));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('end to end: the writer leaves each page\'s text beside its image',
      () async {
    final path = await pdfWith(['Mitosis divides one cell into two.', null]);
    final images = ['${dir.path}/p_1.png', '${dir.path}/p_2.png'];

    await PdfTextLayerWriter(PdfiumTextSource(cacheDir: () async => dir.path))
        .write(pdfPath: path, pageImagePaths: images);

    expect(File('${dir.path}/p_1.txt').readAsStringSync().trim(),
        'Mitosis divides one cell into two.');
    expect(File('${dir.path}/p_2.txt').readAsStringSync().trim(), isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
