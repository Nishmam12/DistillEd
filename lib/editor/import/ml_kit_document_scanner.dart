// The ML Kit Document Scanner behind [DocumentScannerPort].
//
// It runs inside Google Play services — the scanner UI, edge detection,
// perspective correction and shadow removal all live there, which is why it adds
// almost nothing to the app and needs no camera permission. Android only, and
// the plugin is still beta.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'
    as mlkit;

import 'document_scanner_port.dart';

class MlKitDocumentScanner implements DocumentScannerPort {
  /// Most pages one scan may add. The scanner UI has no real ceiling; this keeps
  /// a runaway session from becoming a hundred-page import.
  static const int maxPages = 20;

  /// The plugin reports a dismissed scanner as a platform error with this
  /// message (see its Android `onActivityResult`); anything else is a failure.
  static const String cancelledMessage = 'Operation cancelled';

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<List<String>> scan() async {
    final scanner = mlkit.DocumentScanner(
      options: mlkit.DocumentScannerOptions(
        documentFormats: {mlkit.DocumentFormat.jpeg},
        pageLimit: maxPages,
        // Edge detection + perspective + cleaning (shadows, stains).
        mode: mlkit.ScannerMode.full,
        // Lets the user scan a photo already in the gallery, too.
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      return result.images ?? const [];
    } on PlatformException catch (e) {
      if (e.message == cancelledMessage) return const [];
      throw ScanUnavailableException(e.message);
    } on MissingPluginException {
      throw const ScanUnavailableException('scanner plugin not present');
    } finally {
      try {
        await scanner.close();
      } catch (_) {
        // Closing only frees the native instance; it must not replace the
        // scan's own outcome.
      }
    }
  }
}
