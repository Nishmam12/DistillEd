// Where each word of a page picture sits: the data behind selecting text on an
// imported page and snapping a highlighter to it.
//
// Kept in a sidecar file beside the page image (`StoragePaths.pdfWordsSidecar`),
// like the page's `.txt`, so it needs no database column. Boxes are normalised
// to the picture (0..1, origin top-left), so they stay right however the
// picture is moved or resized on the page.

import 'dart:convert';
import 'dart:ui';

/// One word and its box, normalised to the page picture.
class PageWord {
  final String text;

  /// 0..1 over the picture, origin top-left.
  final Rect box;

  /// Which line of the page the word is on, counted from 0 in reading order.
  final int line;

  const PageWord({required this.text, required this.box, required this.line});

  @override
  bool operator ==(Object other) =>
      other is PageWord &&
      other.text == text &&
      other.box == box &&
      other.line == line;

  @override
  int get hashCode => Object.hash(text, box, line);

  @override
  String toString() => 'PageWord($text, $box, line $line)';
}

/// Where a page's words came from.
enum PageWordsSource {
  /// The PDF's own text layer: exact.
  pdf,

  /// Read off the picture on the device (ML Kit): for scans, photos and PDFs
  /// imported before word boxes were kept.
  ocr,
}

/// Every word of one page picture, in reading order.
class PageWords {
  final PageWordsSource source;
  final List<PageWord> words;

  const PageWords({required this.source, required this.words});

  static const PageWords empty =
      PageWords(source: PageWordsSource.pdf, words: []);

  bool get isEmpty => words.isEmpty;

  static const int _version = 1;

  String encode() => jsonEncode({
        'v': _version,
        'source': source.name,
        'words': [
          for (final w in words)
            {
              't': w.text,
              'l': w.line,
              'b': [
                _round(w.box.left),
                _round(w.box.top),
                _round(w.box.right),
                _round(w.box.bottom),
              ],
            },
        ],
      });

  /// Reads [raw] back. Anything that is not a valid file reads as no words
  /// rather than throwing: the words are a convenience, and the page still
  /// works without them.
  static PageWords decode(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return empty;
      final source = PageWordsSource.values.firstWhere(
        (s) => s.name == m['source'],
        orElse: () => PageWordsSource.pdf,
      );
      final out = <PageWord>[];
      for (final w in m['words'] as List? ?? const []) {
        if (w is! Map) continue;
        final text = w['t'];
        final b = w['b'];
        if (text is! String || text.isEmpty || b is! List || b.length != 4) {
          continue;
        }
        final n = [for (final v in b) v is num ? v.toDouble() : double.nan];
        if (n.any((v) => !v.isFinite)) continue;
        out.add(PageWord(
          text: text,
          box: Rect.fromLTRB(n[0], n[1], n[2], n[3]),
          line: (w['l'] as num? ?? 0).toInt(),
        ));
      }
      return PageWords(source: source, words: out);
    } catch (_) {
      return empty;
    }
  }

  /// Five decimals is a hundredth of a pixel on a 1,000-pixel page: plenty, and
  /// it keeps the file small.
  static double _round(double v) => (v * 100000).roundToDouble() / 100000;
}
