// CSV export for flashcards — Anki imports a plain "front,back" CSV directly.
// Pure string builder (no I/O) so the escaping is unit-tested; the file write +
// share sheet is handled by the caller via ExportShareService.
//
// `.apkg` (a SQLite deck) is a deliberate fast-follow: CSV first keeps this loop
// dependency-free and fully offline.

import '../../domain/models/flashcard.dart';

/// RFC-4180-style CSV: one `front,back` row per card, CRLF-separated, fields
/// quoted only when they contain a comma, quote, or newline.
String flashcardsToCsv(List<Flashcard> cards) {
  return cards
      .map((c) => '${_escape(c.front)},${_escape(c.back)}')
      .join('\r\n');
}

String _escape(String field) {
  final needsQuoting = field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r');
  if (!needsQuoting) return field;
  return '"${field.replaceAll('"', '""')}"';
}
