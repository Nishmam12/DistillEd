// Text and Markdown files become typed text pages: the text is cleaned of
// Markdown syntax (Margo shows plain typed text, not a rendered document) and
// split into page-sized pieces.

import 'dart:convert';

/// Splits [text] into pieces no taller than [maxHeight], as measured by
/// [heightOf]. Breaks fall between paragraphs where possible, else between
/// words; a single word taller than a page goes on a page of its own.
///
/// [heightOf] is the real layout (the painter's), injected so this needs no
/// fonts in tests.
List<String> paginateText(
    String text, double maxHeight, double Function(String) heightOf) {
  final pages = <String>[];
  var current = '';

  void add(String piece, String joiner) {
    final candidate = current.isEmpty ? piece : '$current$joiner$piece';
    if (heightOf(candidate) <= maxHeight) {
      current = candidate;
      return;
    }
    if (current.trim().isNotEmpty) pages.add(current);
    current = piece;
  }

  for (final paragraph in text.split('\n')) {
    final candidate = current.isEmpty ? paragraph : '$current\n$paragraph';
    if (heightOf(candidate) <= maxHeight) {
      current = candidate;
      continue;
    }
    if (current.trim().isNotEmpty) pages.add(current);
    current = '';
    if (heightOf(paragraph) <= maxHeight) {
      current = paragraph;
      continue;
    }
    // A paragraph longer than a page: break it between words.
    for (final word in paragraph.split(' ')) {
      add(word, ' ');
    }
  }
  if (current.trim().isNotEmpty) pages.add(current);
  return pages;
}

bool isMarkdownName(String name) {
  final n = name.toLowerCase();
  return n.endsWith('.md') || n.endsWith('.markdown');
}

/// [markdown] as plain text: headings, emphasis, code fences, quotes and link
/// syntax removed; list bullets become "•". Not a full parser: tables and HTML
/// pass through as written.
String plainFromMarkdown(String markdown) {
  final out = <String>[];
  for (var line in markdown.split('\n')) {
    if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) continue;
    line = line
        .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
        .replaceFirst(RegExp(r'^\s{0,3}>\s?'), '')
        .replaceFirstMapped(
            RegExp(r'^(\s*)[-*+]\s+(\[[ xX]\]\s+)?'), (m) => '${m[1]}• ')
        .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\(([^)\s]+)[^)]*\)'), (m) => '${m[1]} (${m[2]})')
        .replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m[2]!)
        .replaceAllMapped(RegExp(r'(?<![\w*])([*_])(?!\s)(.+?)(?<!\s)\1(?![\w*])'),
            (m) => m[2]!)
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);
    // A horizontal rule is just a break.
    if (RegExp(r'^\s*([-*_]\s*){3,}$').hasMatch(line)) line = '';
    out.add(line);
  }
  return out.join('\n');
}

/// File bytes as text: UTF-8 (a bad byte becomes \uFFFD, never a failure),
/// without a byte-order mark, with Windows line ends made plain.
String decodeTextFile(List<int> bytes) {
  var text = const Utf8Decoder(allowMalformed: true).convert(bytes);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
