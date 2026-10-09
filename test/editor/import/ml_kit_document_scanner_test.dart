import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/editor/import/document_scanner_port.dart';
import 'package:distill_ed/editor/import/ml_kit_document_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_document_scanner');
  final calls = <MethodCall>[];

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the scanned pages in order', () async {
    answerWith((call) async => call.method == 'vision#startDocumentScanner'
        ? {
            'images': ['/scan/1.jpg', '/scan/2.jpg'],
            'pdf': null,
          }
        : null);

    expect(await MlKitDocumentScanner().scan(), ['/scan/1.jpg', '/scan/2.jpg']);
  });

  test('asks for cleaned-up JPEG pages, with gallery import', () async {
    answerWith((call) async => {'images': <String>[], 'pdf': null});

    await MlKitDocumentScanner().scan();

    final start =
        calls.singleWhere((c) => c.method == 'vision#startDocumentScanner');
    final options = (start.arguments as Map)['options'] as Map;
    expect(options['formats'], ['jpeg']);
    expect(options['mode'], 'full');
    expect(options['isGalleryImport'], isTrue);
    expect(options['pageLimit'], MlKitDocumentScanner.maxPages);
  });

  test('closes the native scanner when it is done', () async {
    answerWith((call) async => {'images': ['/scan/1.jpg'], 'pdf': null});

    await MlKitDocumentScanner().scan();

    expect(calls.map((c) => c.method).last, 'vision#closeDocumentScanner');
  });

  test('a scan with no images is empty, not an error', () async {
    answerWith((call) async => {'images': null, 'pdf': null});

    expect(await MlKitDocumentScanner().scan(), isEmpty);
  });

  test('dismissing the scanner is an empty scan', () async {
    answerWith((call) async {
      if (call.method == 'vision#startDocumentScanner') {
        throw PlatformException(
            code: 'DocumentScanner', message: 'Operation cancelled');
      }
      return null;
    });

    expect(await MlKitDocumentScanner().scan(), isEmpty);
  });

  test('a scanner that cannot start is ScanUnavailableException', () async {
    answerWith((call) async {
      if (call.method == 'vision#startDocumentScanner') {
        throw PlatformException(
            code: 'DocumentScanner', message: 'Failed to start document scanner');
      }
      return null;
    });

    await expectLater(MlKitDocumentScanner().scan(),
        throwsA(isA<ScanUnavailableException>()));
  });

  test('a missing plugin is ScanUnavailableException, not a crash', () async {
    // No handler registered: the channel answers MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    await expectLater(MlKitDocumentScanner().scan(),
        throwsA(isA<ScanUnavailableException>()));
  });

  test('a failing close never hides the scan result', () async {
    answerWith((call) async {
      if (call.method == 'vision#closeDocumentScanner') {
        throw PlatformException(code: 'x', message: 'close failed');
      }
      return {'images': ['/scan/1.jpg'], 'pdf': null};
    });

    expect(await MlKitDocumentScanner().scan(), ['/scan/1.jpg']);
  });

  test('is supported on Android only', () {
    // flutter test runs as Android unless overridden.
    expect(MlKitDocumentScanner().isSupported, isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(MlKitDocumentScanner().isSupported, isFalse);
  });
}
