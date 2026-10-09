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
    // share() can return before the target app has read the file (it resolves
    // when the sheet closes), so the file is NOT deleted afterwards. Instead the
    // previous exports are swept at the start of the next one.
    final tempDir = Directory('${(await getTemporaryDirectory()).path}/exports');
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
    await tempDir.create(recursive: true);
    final file = File('${tempDir.path}/${safeFilename(filename)}');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: filename,
      ),
    );
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

}
