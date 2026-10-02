// What the import flow needs from a document scanner, and nothing about how one
// works — so everything above it is tested with a fake and the plugin stays in
// `ml_kit_document_scanner.dart` (docs/AI_PIPELINE_PLAN.md, item 15).
//
// A scanner is a better "camera" for notes than a raw photo: it finds the page's
// edges, straightens the perspective and lifts shadows, so every later step
// (ML Kit, Gemma vision) reads a cleaner image for less work.

/// Opens a document scanner and returns what the user scanned.
abstract class DocumentScannerPort {
  /// Whether this device can scan at all. False means "use the plain camera",
  /// not an error — the scanner is an Android-only upgrade.
  bool get isSupported;

  /// Runs the scan flow and returns the file path of each scanned page, in
  /// order. Empty when the user backed out.
  ///
  /// Throws [ScanUnavailableException] when the scanner could not start — no
  /// Google Play services, or an old one — so the caller can fall back to a
  /// plain camera shot instead of stranding the user.
  Future<List<String>> scan();
}

/// The scanner could not be started on this device.
class ScanUnavailableException implements Exception {
  final String? reason;
  const ScanUnavailableException([this.reason]);

  @override
  String toString() => 'ScanUnavailableException: ${reason ?? 'unavailable'}';
}
