// Shares exported files via the system share sheet or saves to device storage.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportShareService {
  /// Shares a file via the system share sheet.
  static Future<void> shareFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${safeFilename(filename)}');
    await file.writeAsBytes(bytes);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          subject: filename,
        ),
      );
    } finally {
      // The share sheet has what it needs by now; a copy of every export would
      // otherwise sit in the cache until the OS got round to clearing it.
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// [name] as a single safe file name. A notebook title is user text, and one
  /// containing `/` or `..` would otherwise write outside the export directory.
  static String safeFilename(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '_')
        .trim();
    return cleaned.isEmpty ? 'export' : cleaned;
  }

  /// Shares PNG image bytes via the system share sheet.
  static Future<void> sharePng(Uint8List pngBytes, String notebookTitle) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await shareFile(
      bytes: pngBytes,
      filename: '${notebookTitle}_$timestamp.png',
      mimeType: 'image/png',
    );
  }

  /// Shares PDF bytes via the system share sheet.
  static Future<void> sharePdf(Uint8List pdfBytes, String notebookTitle) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await shareFile(
      bytes: pdfBytes,
      filename: '${notebookTitle}_$timestamp.pdf',
      mimeType: 'application/pdf',
    );
  }

  /// Saves PNG bytes to the app's documents directory.
  static Future<String> saveToDocuments(
    Uint8List pngBytes,
    String notebookTitle,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exports');
    await exportDir.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = safeFilename('${notebookTitle}_$timestamp.png');
    final file = File('${exportDir.path}/$filename');
    await file.writeAsBytes(pngBytes);

    return file.path;
  }
}
