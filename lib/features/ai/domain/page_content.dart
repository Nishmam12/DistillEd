// What the AI platform "sees" on one page — the value object every AI
// feature consumes instead of touching scene elements directly.

import 'dart:ui';

/// Where a piece of page content came from.
enum PageSourceKind { ink, typedText, image }

/// One content-bearing region of a page, with rough bounds so UI can later
/// highlight "the AI is looking at this".
class PageContentSource {
  final PageSourceKind kind;

  /// World-space bounding box of the source element(s).
  final Rect bounds;

  /// True when the source holds visual content the pipeline cannot read yet
  /// (photos, imported PDF pages — which are rasterized images on this app).
  /// OCR for these is deliberately out of scope until a later phase.
  final bool needsOcr;

  const PageContentSource({
    required this.kind,
    required this.bounds,
    this.needsOcr = false,
  });
}

/// The extracted, AI-readable content of a single page.
class PageContent {
  /// Text recognized from handwritten ink ('' when the page has no ink).
  final String recognizedInkText;

  /// ML Kit top-candidate score for the ink (lower = more likely); null when
  /// the page has no ink or the model returned no score. Feeds confidence
  /// gating (e.g. the meaningfulness gate).
  final double? inkTopScore;

  /// Typed text from text elements, concatenated in reading order
  /// (top-to-bottom, then left-to-right).
  final String typedText;

  /// Text read by OCR out of the page's images — imported PDF pages, photos of
  /// a whiteboard or a textbook. Empty when the page has no images, when they
  /// hold no text, or when no OCR reader was wired in.
  ///
  /// Kept apart from [typedText] because it is read, not written: the user did
  /// not type it, and it carries OCR's error rate.
  final String recognizedImageText;

  /// Which parts of the page contributed (or couldn't), with bounds.
  final List<PageContentSource> sources;

  const PageContent({
    required this.recognizedInkText,
    required this.typedText,
    this.recognizedImageText = '',
    this.inkTopScore,
    this.sources = const [],
  });

  static const empty = PageContent(recognizedInkText: '', typedText: '');

  /// Everything readable on the page, ink first, blank-line separated.
  String get combinedText => [
        recognizedInkText.trim(),
        typedText.trim(),
        recognizedImageText.trim(),
      ].where((t) => t.isNotEmpty).join('\n\n');

  bool get hasText => combinedText.isNotEmpty;

  /// True when the page holds images the pipeline cannot read yet.
  bool get hasUnrecognizedImages => sources.any((s) => s.needsOcr);
}
