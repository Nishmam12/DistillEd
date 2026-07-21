// Wraps ML Kit Text Recognition (image OCR) for the AI platform.
//
// Distinct from `../handwriting/` next door: that is digital-INK recognition,
// which reads pen strokes and knows nothing about pixels. This reads an image —
// an imported PDF page, a photo of a whiteboard, a screenshot.
//
// Two consumers, one engine:
//   * [PageContentExtractor], so every AI feature can read imported pages
//     instead of flagging them unreadable;
//   * the editor's "Extract text", which needs the per-line boxes as well as
//     the text so it can lay editable text over the picture.

import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

/// One recognised line: its text and where it sat in the source image, in
/// source pixels.
typedef RecognizedLine = ({String text, Rect bounds});

/// Thrown when OCR fails at the platform layer. Carries a message fit to show
/// the user.
class TextExtractionException implements Exception {
  final String message;
  final Object? cause;
  TextExtractionException(this.message, [this.cause]);

  @override
  String toString() => 'TextExtractionException: $message';
}

class ImageTextRecognitionService {
  final mlkit.TextRecognizer _recognizer;

  /// Text already read, keyed by absolute path.
  ///
  /// An imported file never changes — it is written once under a content hash
  /// or a unique id and only ever deleted — so a hit is always valid. Without
  /// this, every debounced page analysis would re-OCR every image on the page.
  final Map<String, List<RecognizedLine>> _cache = {};

  /// Latin script covers the notes this app is built for. Other scripts are a
  /// separate model and a deliberate future choice, not a per-image guess.
  ImageTextRecognitionService({mlkit.TextRecognizer? recognizer})
      : _recognizer = recognizer ??
            mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);

  /// Recognises the image at [absolutePath], one entry per line in reading
  /// order. Cached; see [_cache].
  ///
  /// Lines rather than blocks: a block spans several lines, and re-wrapping its
  /// text inside a block-sized rectangle drifts from where the words sit.
  Future<List<RecognizedLine>> lines(String absolutePath) async {
    final cached = _cache[absolutePath];
    if (cached != null) return cached;

    final mlkit.RecognizedText result;
    try {
      result = await _recognizer
          .processImage(mlkit.InputImage.fromFilePath(absolutePath));
    } catch (e) {
      throw TextExtractionException(
          "Couldn't read the text in that picture.", e);
    }

    final out = [
      for (final block in result.blocks)
        for (final line in block.lines)
          if (line.text.trim().isNotEmpty)
            (text: line.text, bounds: line.boundingBox),
    ];
    _cache[absolutePath] = out;
    return out;
  }

  /// The image's text as a single block, lines joined top-to-bottom. Empty when
  /// there is no text, or when the image can't be read at all — a page whose
  /// picture failed to OCR should still surface its ink and typed text rather
  /// than failing the whole extraction.
  Future<String> readText(String absolutePath) async {
    try {
      final found = await lines(absolutePath);
      return found.map((l) => l.text.trim()).join('\n');
    } on TextExtractionException {
      return '';
    }
  }

  Future<void> dispose() async {
    _cache.clear();
    await _recognizer.close();
  }
}
