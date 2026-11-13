// The exact content of the two kinds of figure a sentence cannot hold: an
// equation, and a table.
//
// A general description ("the quadratic formula", "a table of trial results")
// names them without containing them, so a question about the third row or
// the sign of a term has nothing to stand on. After the general read has said
// "this is an equation" or "this is a table", a second, narrow question is put
// to the same picture: write this as LaTeX; write this as a table. Each is
// asked as plain text, not JSON — LaTeX is full of backslashes, and a small
// model that must also escape them inside a JSON string breaks the whole
// reply (`\frac` is a form feed followed by "rac").
//
// This file is the pure half: the prompts, and turning the replies into
// something safe to keep. Anything that does not hold up is dropped, and the
// figure keeps its general description.

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// A table read off a page: its column headings and its rows.
@immutable
class FigureTable {
  final List<String> columns;
  final List<List<String>> rows;

  const FigureTable({required this.columns, required this.rows});

  /// The most rows and columns kept. A table past this is a spreadsheet, and
  /// would crowd everything else out of a prompt.
  static const int maxRows = 30;
  static const int maxColumns = 8;

  /// The table as Markdown, which every model reads and the student can too.
  String toMarkdown() => [
        '| ${columns.join(' | ')} |',
        '| ${columns.map((_) => '---').join(' | ')} |',
        for (final row in rows) '| ${row.join(' | ')} |',
      ].join('\n');

  Map<String, dynamic> toJson() => {'columns': columns, 'rows': rows};

  /// Null for anything that is not a usable table (see [parseMarkdownTable]
  /// for what usable means) — a damaged cache entry costs the table only.
  static FigureTable? fromJson(Object? json) {
    if (json is! Map) return null;
    final columns = json['columns'];
    final rows = json['rows'];
    if (columns is! List || rows is! List) return null;
    final cols = [for (final c in columns) if (c is String) c];
    final body = [
      for (final r in rows)
        if (r is List) [for (final c in r) if (c is String) c],
    ];
    if (cols.length < 2 || body.isEmpty) return null;
    if (body.any((r) => r.length != cols.length)) return null;
    return FigureTable(columns: cols, rows: body);
  }

  @override
  bool operator ==(Object other) =>
      other is FigureTable &&
      listEquals(other.columns, columns) &&
      other.rows.length == rows.length &&
      [
        for (var i = 0; i < rows.length; i++) listEquals(other.rows[i], rows[i]),
      ].every((same) => same);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(columns), Object.hashAll(rows.expand((r) => r)));
}

/// Asks for an equation, or a worked derivation, as LaTeX.
const String kLatexPrompt = '''
This image shows mathematics from a student's notes. Write it out as LaTeX.

Rules:
- One line of the image per line of output, in the same order.
- Output only the LaTeX: no dollar signs, no \\[ \\], no code fences, no words of explanation.
- Copy exactly what is written, including any mistake. Do not solve, simplify or continue it.
- If a symbol cannot be read, write ? in its place.''';

/// Asks for a table as a Markdown table.
const String kTablePrompt = '''
This image shows a table from a student's notes. Write it out as a Markdown table.

Rules:
- The first row is the column headings. If the table has none, use short ones that fit.
- One row of the image per row of output, in the same order. Keep every cell, including empty ones.
- Copy the values exactly as written. Do not add, total or correct anything.
- Output only the table: no code fences, no words before or after.''';

final RegExp _fence = RegExp(r'^```[a-zA-Z]*\s*$');

final RegExp _textGroup = RegExp(r'\\(text|mathrm|textbf|textit)\{[^{}]*\}');
final RegExp _command = RegExp(r'\\[A-Za-z]+');
final RegExp _sentence =
    RegExp(r'(?:[A-Za-z]{2,}[ ,.;:]+){3}[A-Za-z]{2,}');
final RegExp _mathSign = RegExp(r'[\\=^_+\-*/<>0-9]');

/// True for a reply that is words about the image ("I cannot read this")
/// rather than a transcription of it: no sign of mathematics at all, or a run
/// of four ordinary words outside any `\text{…}`.
bool _looksLikeProse(String latex) {
  if (!_mathSign.hasMatch(latex)) return true;
  final bare = latex.replaceAll(_textGroup, ' ').replaceAll(_command, ' ');
  return _sentence.hasMatch(bare);
}

/// A model's reply to [kLatexPrompt] as clean LaTeX — one expression per line,
/// no delimiters — or '' when the reply is not usable: empty, far too long to
/// be a transcription, or with unbalanced braces (which would not render, and
/// usually means the reply was cut off).
String cleanLatex(String raw) {
  final lines = <String>[];
  for (var line in raw.split('\n')) {
    line = line.trim();
    if (line.isEmpty || _fence.hasMatch(line)) continue;
    // Delimiters the model added anyway.
    for (final (open, close) in const [
      (r'$$', r'$$'),
      (r'\[', r'\]'),
      (r'\(', r'\)'),
      (r'$', r'$'),
    ]) {
      if (line.length >= open.length + close.length &&
          line.startsWith(open) &&
          line.endsWith(close)) {
        line = line.substring(open.length, line.length - close.length).trim();
        break;
      }
    }
    if (line == r'$$' || line == r'\[' || line == r'\]') continue;
    if (line.isNotEmpty) lines.add(line);
  }
  final latex = lines.join('\n');
  if (latex.isEmpty || latex.length > 1200 || lines.length > 20) return '';
  if (latex.contains(r'$')) return ''; // prose with inline maths, not LaTeX
  if (_looksLikeProse(latex)) return '';

  var depth = 0;
  for (var i = 0; i < latex.length; i++) {
    final c = latex[i];
    if (c == r'\') {
      i++; // an escaped brace is a character, not a group
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') depth--;
    if (depth < 0) return '';
  }
  return depth == 0 ? latex : '';
}

/// A model's reply to [kTablePrompt] as a [FigureTable], or null when it is
/// not one: fewer than two columns, no rows under the headings, or rows that
/// do not agree on how many columns there are (a misread grid is worse than no
/// grid — every value would sit under the wrong heading).
FigureTable? parseMarkdownTable(String raw) {
  final rows = <List<String>>[];
  for (var line in raw.split('\n')) {
    line = line.trim();
    if (!line.contains('|')) continue;
    // Outer pipes come as a pair. A line with only a trailing one ("1 |") has
    // an empty last cell, not a closing pipe.
    if (line.startsWith('|')) {
      line = line.substring(1);
      if (line.endsWith('|')) line = line.substring(0, line.length - 1);
    }
    final cells = [for (final c in line.split('|')) c.trim()];
    // The |---|:--:| rule under the headings.
    if (cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c))) continue;
    rows.add(cells);
  }
  if (rows.length < 2) return null;
  final width = rows.first.length;
  if (width < 2 || width > FigureTable.maxColumns) return null;
  if (rows.any((r) => r.length != width)) return null;
  final body = rows.skip(1).take(FigureTable.maxRows).toList();
  if (body.every((r) => r.every((c) => c.isEmpty))) return null;
  return FigureTable(columns: rows.first, rows: body);
}
