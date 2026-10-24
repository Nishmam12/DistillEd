// Centralized storage path definitions
class StoragePaths {
  /// Base directory for a specific notebook.
  static String getNotebookDir(String docsDir, String notebookId) =>
      '$docsDir/notes/$notebookId';

  /// Relative path for cached PDF pages (relative to docsDir).
  static String getPdfPageCacheRelativePath(String notebookId, String pdfHash, int pageIndex) =>
      'notes/$notebookId/imports/pdf_${pdfHash}_$pageIndex.png';

  /// Where the text PDFium read off a PDF page is kept: beside the page's image,
  /// same name, `.txt`. Works on a relative or an absolute path, so the import
  /// (which writes it) and the reader (which looks it up from the element's
  /// relative image path) agree with no index between them.
  static String pdfTextSidecar(String imagePath) {
    final dot = imagePath.lastIndexOf('.');
    final hasExtension = dot > imagePath.lastIndexOf('/');
    return '${hasExtension ? imagePath.substring(0, dot) : imagePath}.txt';
  }

  /// Where a lecture recording's transcript is kept: beside the audio, named for
  /// it, `.transcript.json`. No schema — the audio file's own path is the key, so
  /// whatever owns the recording owns its transcript.
  static String transcriptSidecar(String audioPath) {
    final dot = audioPath.lastIndexOf('.');
    final hasExtension = dot > audioPath.lastIndexOf('/');
    return '${hasExtension ? audioPath.substring(0, dot) : audioPath}.transcript.json';
  }

  /// Whether [rel] is a path the app itself writes under app documents: inside
  /// `notes/` or `audio/`, relative, with no `.`/`..` segments. Stored paths can
  /// arrive from pasted JSON, so anything else (`margo.isar`, `../x`, `/abs`)
  /// must never be opened or deleted.
  static bool isSafeRelativePath(String rel) {
    if (!(rel.startsWith('notes/') || rel.startsWith('audio/'))) return false;
    if (rel.contains('\\')) return false;
    return !rel.split('/').any((s) => s.isEmpty || s == '.' || s == '..');
  }

  /// Relative path for cached free images (relative to docsDir).
  static String getFreeImageCacheRelativePath(String notebookId, String contentId) =>
      'notes/$notebookId/imports/img_$contentId.png';
}
