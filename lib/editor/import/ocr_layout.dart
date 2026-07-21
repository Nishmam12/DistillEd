// Places OCR results onto the page.
//
// Pure — no ML Kit, no files, no device — so the mapping can be tested the same
// way `ink_lines.dart` is. The recogniser reports boxes in the *source image's*
// pixel space; the picture on the page is an [ImageElement] the user may since
// have moved or resized. This converts between the two.
//
// Text is laid out one recognised LINE per box rather than one per block: a
// block spans several lines, and re-wrapping its text inside a block-sized
// rectangle would drift out of step with where the words actually sit on the
// page. Per-line boxes stay put, and each line stays independently editable.

import 'dart:ui';

/// One recognised line: its text, and where it sat in the source image.
typedef OcrBox = ({String text, Rect bounds});

/// One line ready to become a scene text element.
typedef PlacedText = ({String text, Rect bounds, double fontSize});

/// Ratio between a line's drawn font size and the height of its box.
///
/// Flutter lays a paragraph out at roughly 1.2x the font size, so a font sized
/// at the full box height would overflow it. Sizing slightly under keeps the
/// drawn line inside the box the recogniser found it in.
const double kOcrFontHeightRatio = 0.8;

/// Smallest font an extracted line is given. Below this the text is unreadable
/// and un-tappable, and it is almost always OCR noise rather than real content.
const double kOcrMinFontSize = 6.0;

/// Line height multiplier Flutter lays a paragraph out at, used to give each
/// extracted line a box that matches the text actually drawn in it.
const double kOcrLineHeightRatio = 1.3;

/// Measures the width of [text] drawn at [fontSize].
typedef MeasureText = double Function(String text, double fontSize);

/// Rough width estimate used when no real measurer is supplied: about half the
/// font size per character, which is a fair average for Latin text.
///
/// Good enough for tests and for a fallback, but production passes a real
/// measurer — the estimate is blind to which characters are actually in the
/// string, and "WWW" and "iii" are nothing like the same width.
double estimateTextWidth(String text, double fontSize) =>
    text.length * fontSize * 0.5;

/// Maps [boxes] from [sourcePixels] space into [target], the scene rect the
/// picture currently occupies.
///
/// Boxes are scaled independently on each axis, so this stays correct even if
/// the user has resized the picture out of its original aspect ratio. Empty
/// text is dropped. Returns an empty list when there is nothing to map onto —
/// a zero-sized source or target.
///
/// [measureWidth] measures drawn text; it defaults to [estimateTextWidth], but
/// callers that can reach the text engine should pass a real measurer.
///
/// Rotation is not handled: an [ImageElement] rotated on the page will place
/// its extracted text axis-aligned. Extracting before rotating gives the right
/// result, and the text can be rotated with the picture afterwards.
List<PlacedText> layOutOcrBoxes({
  required List<OcrBox> boxes,
  required Size sourcePixels,
  required Rect target,
  MeasureText measureWidth = estimateTextWidth,
}) {
  if (sourcePixels.width <= 0 ||
      sourcePixels.height <= 0 ||
      target.width <= 0 ||
      target.height <= 0) {
    return const [];
  }

  final scaleX = target.width / sourcePixels.width;
  final scaleY = target.height / sourcePixels.height;

  final out = <PlacedText>[];
  for (final box in boxes) {
    final text = box.text.trim();
    if (text.isEmpty) continue;

    final mapped = Rect.fromLTRB(
      target.left + box.bounds.left * scaleX,
      target.top + box.bounds.top * scaleY,
      target.left + box.bounds.right * scaleX,
      target.top + box.bounds.bottom * scaleY,
    );
    if (mapped.width <= 0 || mapped.height <= 0) continue;

    final fontSize = _fontSizeFor(text, mapped, measureWidth);

    // Give the line a box matching the text actually drawn, centred on where
    // the recogniser found it. The mapped box is only a locator: for slanted or
    // curving handwriting its axis-aligned height is far greater than the
    // letters, so adopting it wholesale would leave the text floating at the
    // top of a tall empty rectangle.
    final height = fontSize * kOcrLineHeightRatio;
    out.add((
      text: text,
      bounds: Rect.fromLTWH(
        mapped.left,
        mapped.center.dy - height / 2,
        mapped.width,
        height,
      ),
      fontSize: fontSize,
    ));
  }
  return out;
}

/// The largest font at which [text] still fits inside [box] on both axes.
///
/// Height alone is not enough. ML Kit reports an axis-aligned box per line, so
/// a line of handwriting that slants or curves gets a box far taller than its
/// letters — sizing off that produced text several times too big, which then
/// wrapped because it no longer fitted the width. Drawn width is linear in font
/// size, so one measurement gives the width-limited size exactly.
double _fontSizeFor(String text, Rect box, MeasureText measureWidth) {
  final byHeight = box.height * kOcrFontHeightRatio;
  final widthAtGuess = measureWidth(text, byHeight);
  final byWidth = widthAtGuess > 0
      ? byHeight * (box.width / widthAtGuess)
      : byHeight;

  final size = byHeight < byWidth ? byHeight : byWidth;
  return size < kOcrMinFontSize ? kOcrMinFontSize : size;
}
