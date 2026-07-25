// Anki export for flashcards, as plain text — no dependency, fully offline.
//
// Two shapes share one RFC-4180 body:
//   • [flashcardsToCsv]     — bare `front,back` rows (the escaping unit lives
//                             here so it stays testable).
//   • [flashcardsToAnkiCsv] — the same rows behind Anki's file header
//                             directives, so the file imports straight into a
//                             NAMED deck with the Basic notetype and its two
//                             columns auto-mapped to Front/Back — no manual
//                             mapping in Anki's import dialog.
//
// A true `.apkg` (a ZIP-wrapped SQLite collection) was the logged fast-follow.
// It's deliberately still deferred: it needs a native SQLite dependency, which
// (a) can't be exercised by `flutter test` on the dev host and (b) can't be
// round-tripped against real Anki from here — so this dependency-free, fully
// unit-tested, fully-offline path is preferred. The directive header closes the
// real ergonomic gap (preset deck + notetype + field mapping) for simple
// front/back study cards. See AI_PROGRESS.md for the full rationale.
//
// The file write + share sheet is handled by the caller via ExportShareService.

import '../../domain/models/flashcard.dart';

/// Deck name used when the page has no identified topic to name the deck after.
const String kDefaultAnkiDeckName = 'DistillEd Flashcards';

/// RFC-4180-style CSV: one `front,back` row per card, CRLF-separated, fields
/// quoted only when they contain a comma, quote, or newline.
String flashcardsToCsv(List<Flashcard> cards) {
  return cards
      .map((c) => '${_escape(c.front)},${_escape(c.back)}')
      .join('\r\n');
}

/// The Anki-importable deck as text: file header directives followed by the
/// [flashcardsToCsv] rows. Importing this drops the cards into a deck named
/// [deckName] (falling back to [kDefaultAnkiDeckName] when blank) using Anki's
/// built-in Basic notetype.
///
/// Requires Anki 2.1.54+ for the directives; older versions ignore the `#`
/// lines (the file still imports, just without the deck/notetype preset).
/// `#html:false` keeps `<`, `>` and `&` literal so plain-text cards import as
/// written.
String flashcardsToAnkiCsv(List<Flashcard> cards, {String? deckName}) {
  final directives = <String>[
    '#separator:Comma',
    '#html:false',
    '#notetype:Basic',
    '#deck:${sanitizeAnkiDeckName(deckName)}',
  ];
  final body = flashcardsToCsv(cards);
  final buffer = StringBuffer(directives.join('\r\n'));
  if (body.isNotEmpty) buffer..write('\r\n')..write(body);
  return buffer.toString();
}

/// Collapses CR/LF (which would split the single `#deck:` directive line, or
/// read oddly in an `.apkg` deck name) to spaces and trims; a blank result
/// becomes [kDefaultAnkiDeckName]. Shared by both Anki export paths.
String sanitizeAnkiDeckName(String? raw) {
  final cleaned =
      (raw ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
  return cleaned.isEmpty ? kDefaultAnkiDeckName : cleaned;
}

String _escape(String field) {
  final needsQuoting = field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r');
  if (!needsQuoting) return field;
  return '"${field.replaceAll('"', '""')}"';
}
