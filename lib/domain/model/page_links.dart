// The links and contents entries of one imported PDF page, kept in a sidecar
// beside the page picture (`StoragePaths.pdfLinksSidecar`).
//
// What a file holds depends only on the PDF and its page number, never on which
// pages of the PDF were imported: a later import of other pages of the same PDF
// finds the file already there and leaves it. So a link keeps the PDF page
// number it points at, and the page it lands on is worked out when it is
// followed, from the picture's own name (`pdf_<hash>_<number>.png`).

import 'dart:convert';
import 'dart:ui';

/// A clickable area of the page: a web address, or another page of the PDF.
class PageLink {
  /// 0..1 over the picture, origin top-left.
  final Rect rect;

  /// Where a web link goes. Not checked here: it is checked when it is opened
  /// (`isSafeLinkUrl`), since it can arrive inside someone else's backup.
  final String? url;

  /// The PDF page (1 is the first) a link to another page goes to.
  final int? destPage;

  const PageLink({required this.rect, this.url, this.destPage});

  @override
  bool operator ==(Object other) =>
      other is PageLink &&
      other.rect == rect &&
      other.url == url &&
      other.destPage == destPage;

  @override
  int get hashCode => Object.hash(rect, url, destPage);
}

/// One line of a PDF's table of contents that lands on this page.
class OutlineEntry {
  final String title;

  /// 0 for a top-level entry.
  final int depth;

  /// Where the entry sits in the whole contents, so entries landing on one
  /// page stay in the order the PDF lists them.
  final int order;

  const OutlineEntry(
      {required this.title, required this.depth, required this.order});

  @override
  bool operator ==(Object other) =>
      other is OutlineEntry &&
      other.title == title &&
      other.depth == depth &&
      other.order == order;

  @override
  int get hashCode => Object.hash(title, depth, order);
}

class PageLinks {
  final List<PageLink> links;
  final List<OutlineEntry> outline;

  const PageLinks({this.links = const [], this.outline = const []});

  static const PageLinks empty = PageLinks();

  bool get isEmpty => links.isEmpty && outline.isEmpty;

  static const int _version = 1;

  String encode() => jsonEncode({
        'v': _version,
        'links': [
          for (final l in links)
            {
              'b': [
                _round(l.rect.left),
                _round(l.rect.top),
                _round(l.rect.right),
                _round(l.rect.bottom),
              ],
              'u': ?l.url,
              'p': ?l.destPage,
            },
        ],
        'outline': [
          for (final o in outline)
            {'t': o.title, 'd': o.depth, 'o': o.order},
        ],
      });

  /// Reads [raw] back. Anything that is not a valid file reads as nothing,
  /// and entries that are not valid are skipped.
  static PageLinks decode(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return empty;
      final links = <PageLink>[];
      for (final l in m['links'] as List? ?? const []) {
        if (l is! Map) continue;
        final b = l['b'];
        if (b is! List || b.length != 4) continue;
        final n = [for (final v in b) v is num ? v.toDouble() : double.nan];
        if (n.any((v) => !v.isFinite)) continue;
        final url = l['u'];
        final page = l['p'];
        if (url is! String && page is! int) continue;
        links.add(PageLink(
          rect: Rect.fromLTRB(n[0], n[1], n[2], n[3]),
          url: url is String ? url : null,
          destPage: page is int ? page : null,
        ));
      }
      final outline = <OutlineEntry>[];
      for (final o in m['outline'] as List? ?? const []) {
        if (o is! Map) continue;
        final title = o['t'];
        if (title is! String || title.trim().isEmpty) continue;
        outline.add(OutlineEntry(
          title: title,
          depth: (o['d'] as num? ?? 0).toInt().clamp(0, 12),
          order: (o['o'] as num? ?? 0).toInt(),
        ));
      }
      return PageLinks(links: links, outline: outline);
    } catch (_) {
      return empty;
    }
  }

  static double _round(double v) => (v * 100000).roundToDouble() / 100000;
}

/// Whether a link's web address is one to open: http, https or mail, and
/// nothing that runs code or reaches a file. Checked when the link is opened.
bool isSafeLinkUrl(String? url) {
  if (url == null || url.length > 2000) return false;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  if (uri.isScheme('http') || uri.isScheme('https')) return uri.host.isNotEmpty;
  return uri.isScheme('mailto') && uri.path.isNotEmpty;
}

/// The name of the picture of PDF page [destPage] that sits beside the picture
/// at [imagePath], or null when [imagePath] is not a PDF page picture. Works on
/// a relative path.
String? siblingPdfPagePath(String imagePath, int destPage) {
  final m = RegExp(r'^(.*/pdf_[0-9A-Fa-f]+_)(\d+)(\.[A-Za-z]+)$').firstMatch(imagePath);
  if (m == null || destPage < 1) return null;
  return '${m.group(1)}$destPage${m.group(3)}';
}
