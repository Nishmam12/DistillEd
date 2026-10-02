import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:inkflow/editor/import/document_scanner_port.dart';
import 'package:inkflow/editor/import/scene_import_service.dart';
import 'package:inkflow/features/import/pdf_service.dart';

/// A scanner that hands back whatever pages the test gives it, or fails.
class _FakeScanner implements DocumentScannerPort {
  final bool supported;
  final List<String> pages;
  final Object? failure;
  int scans = 0;

  _FakeScanner({this.supported = true, this.pages = const [], this.failure});

  @override
  bool get isSupported => supported;

  @override
  Future<List<String>> scan() async {
    scans++;
    final f = failure;
    if (f != null) throw f;
    return pages;
  }
}

/// A picker that never gets asked for anything the test did not expect.
class _FakePicker extends ImagePicker {
  final String? path;
  ImageSource? askedFor;

  _FakePicker({this.path});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    askedFor = source;
    return path == null ? null : XFile(path!);
  }
}

void main() {
  late Directory docs;
  late Directory scratch;

  /// A real JPEG on disk — the import re-encodes whatever it is given.
  String writeJpeg(String name, {int width = 40, int height = 20}) {
    final file = File('${scratch.path}/$name');
    file.writeAsBytesSync(img.encodeJpg(img.Image(width: width, height: height)));
    return file.path;
  }

  setUp(() {
    docs = Directory.systemTemp.createTempSync('inkflow_docs_');
    scratch = Directory.systemTemp.createTempSync('inkflow_scan_');
  });

  tearDown(() {
    docs.deleteSync(recursive: true);
    scratch.deleteSync(recursive: true);
  });

  SceneImportService service({
    DocumentScannerPort? scanner,
    ImagePicker? picker,
  }) =>
      SceneImportService(
        scanner: scanner,
        picker: picker,
        documentsDir: () async => docs.path,
      );

  group('importScan', () {
    test('every scanned page becomes an imported image, in order', () async {
      final scanner = _FakeScanner(pages: [
        writeJpeg('a.jpg', width: 40, height: 20),
        writeJpeg('b.jpg', width: 30, height: 60),
      ]);

      final imported = await service(scanner: scanner).importScan('nb1');

      expect(imported, hasLength(2));
      expect(imported[0].pixelSize.width, 40);
      expect(imported[0].pixelSize.height, 20);
      expect(imported[1].pixelSize.width, 30);
      expect(imported[1].pixelSize.height, 60);
      // Stored under the notebook, relative to the documents dir, one file each.
      for (final page in imported) {
        expect(page.relativePath, startsWith('notes/nb1/imports/'));
        expect(File('${docs.path}/${page.relativePath}').existsSync(), isTrue);
      }
      expect(imported[0].relativePath, isNot(imported[1].relativePath));
    });

    test('pages are described by their place in the scan', () async {
      final scanner =
          _FakeScanner(pages: [writeJpeg('a.jpg'), writeJpeg('b.jpg')]);

      final imported = await service(scanner: scanner).importScan('nb1');

      expect(imported.map((p) => p.description),
          ['Scanned page 1', 'Scanned page 2']);
    });

    test('backing out of the scanner imports nothing', () async {
      final imported =
          await service(scanner: _FakeScanner()).importScan('nb1');

      expect(imported, isEmpty);
    });

    test('a page that cannot be decoded is an ImportException', () async {
      final junk = File('${scratch.path}/junk.jpg')
        ..writeAsStringSync('not an image');
      final scanner = _FakeScanner(pages: [junk.path]);

      await expectLater(
        service(scanner: scanner).importScan('nb1'),
        throwsA(isA<ImportException>()),
      );
    });
  });

  group('importCapture (the camera entry)', () {
    test('uses the scanner where the device has one', () async {
      final scanner = _FakeScanner(pages: [writeJpeg('a.jpg')]);
      final picker = _FakePicker();

      final imported =
          await service(scanner: scanner, picker: picker).importCapture('nb1');

      expect(imported, hasLength(1));
      expect(scanner.scans, 1);
      expect(picker.askedFor, isNull, reason: 'no raw camera shot was taken');
    });

    test('falls back to the plain camera when scanning is unavailable',
        () async {
      final scanner = _FakeScanner(failure: const ScanUnavailableException());
      final picker = _FakePicker(path: writeJpeg('shot.jpg'));

      final imported =
          await service(scanner: scanner, picker: picker).importCapture('nb1');

      expect(imported, hasLength(1));
      expect(scanner.scans, 1, reason: 'it did try the scanner first');
      expect(picker.askedFor, ImageSource.camera);
    });

    test('goes straight to the camera on a device that cannot scan', () async {
      final scanner = _FakeScanner(supported: false);
      final picker = _FakePicker(path: writeJpeg('shot.jpg'));

      final imported =
          await service(scanner: scanner, picker: picker).importCapture('nb1');

      expect(imported, hasLength(1));
      expect(scanner.scans, 0);
      expect(picker.askedFor, ImageSource.camera);
    });

    test('with no scanner at all it is just the camera', () async {
      final picker = _FakePicker(path: writeJpeg('shot.jpg'));

      final imported = await service(picker: picker).importCapture('nb1');

      expect(imported, hasLength(1));
      expect(picker.askedFor, ImageSource.camera);
    });

    test('cancelling the camera fallback imports nothing', () async {
      final picker = _FakePicker();

      final imported = await service(picker: picker).importCapture('nb1');

      expect(imported, isEmpty);
    });

    test('a scan the user backed out of does not open the camera', () async {
      final picker = _FakePicker(path: writeJpeg('shot.jpg'));

      final imported =
          await service(scanner: _FakeScanner(), picker: picker)
              .importCapture('nb1');

      expect(imported, isEmpty);
      expect(picker.askedFor, isNull);
    });
  });

  group('canScan', () {
    test('is true only when a supported scanner is wired', () {
      expect(service().canScan, isFalse);
      expect(service(scanner: _FakeScanner(supported: false)).canScan, isFalse);
      expect(service(scanner: _FakeScanner()).canScan, isTrue);
    });
  });

  group('scanSourceName', () {
    test('names a multi-page scan by when it was taken', () {
      expect(SceneImportService.scanSourceName(DateTime(2026, 10, 2, 9, 5)),
          'Scan 2 Oct, 09:05');
    });
  });
}
