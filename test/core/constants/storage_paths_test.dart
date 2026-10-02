import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/constants/storage_paths.dart';

void main() {
  group('pdfTextSidecar — where a PDF page\'s own text is kept', () {
    test('sits beside the page image, with a .txt extension', () {
      expect(StoragePaths.pdfTextSidecar('notes/1/imports/pdf_ab12_3.png'),
          'notes/1/imports/pdf_ab12_3.txt');
    });

    test('is the same path the cache gives the page, so no lookup is needed',
        () {
      final image = StoragePaths.getPdfPageCacheRelativePath('7', 'ab12', 3);

      expect(StoragePaths.pdfTextSidecar(image),
          'notes/7/imports/pdf_ab12_3.txt');
    });

    test('only the file\'s own extension is replaced', () {
      expect(StoragePaths.pdfTextSidecar('notes/v1.2/imports/p.png'),
          'notes/v1.2/imports/p.txt');
    });

    test('a path with no extension gains one', () {
      expect(StoragePaths.pdfTextSidecar('notes/1/imports/p'),
          'notes/1/imports/p.txt');
    });
  });
}
