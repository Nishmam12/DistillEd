// Shares exported files via the system share sheet or saves to device storage.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// The longest title, in characters, kept in an export's file name. A file
  /// system refuses a name over 255 bytes, and a pasted title can be longer.
  static const int _maxTitleChars = 80;

  /// `<title>_<timestamp>.<extension>` for an export, with the title shortened
  /// (never the extension, which the share target needs) and made safe.
  @visibleForTesting
  static String fileName(String title, int timestamp, String extension) {
    final safe = safeFilename(title);
    final short = safe.length > _maxTitleChars
        ? safe.substring(0, _maxTitleChars)
        : safe;
    return '${short}_$timestamp.$extension';
  }

  /// Shares PNG image bytes via the system share sheet.
  static Future<void> sharePng(Uint8List pngBytes, String notebookTitle) async {
    await shareFile(
      bytes: pngBytes,
      filename: fileName(
        notebookTitle,
        DateTime.now().millisecondsSinceEpoch,
        'png',
      ),
      mimeType: 'image/png',
    );
  }

  /// Shares PDF bytes via the system share sheet.
  static Future<void> sharePdf(Uint8List pdfBytes, String notebookTitle) async {
    await shareFile(
      bytes: pdfBytes,
      filename: fileName(
        notebookTitle,
        DateTime.now().millisecondsSinceEpoch,
        'pdf',
      ),
      mimeType: 'application/pdf',
    );
  }

}
