// The corpus the embedding evaluation reads (docs/TECH_MIGRATION_PLAN.md, phase
// 4.9): every page of the student's notes, cut at each candidate chunk size, one
// JSON object per line. an external eval script (removed from the repo) embedded it.
//
// Pages carry their id into every chunk. A chunk id changes with its size, so
// the eval set names PAGES as the answers and a question scores at every size.

import 'dart:convert';

import 'page_chunker.dart';

/// The chunk sizes the evaluation compares, in words. The overlap scales with the
/// size, so 250 keeps its 30 words and 500 and 1000 keep the same 12%.
const List<int> kCorpusChunkSizes = [250, 500, 1000];

/// One page of notes as the corpus reads it.
class CorpusPage {
  final int notebookId;
  final int pageId;

  /// What the page is embedded under (see [chunkTitle]); null when it has none.
  final String? title;

  final String text;

  const CorpusPage({
    required this.notebookId,
    required this.pageId,
    required this.title,
    required this.text,
  });
}

/// Writes every page at every size in [chunkSizes], one JSON object per line.
///
/// Each line: `id` (`w<size>-p<page>-c<ordinal>`), `chunk_words`, `page_id`,
/// `title`, `text`. The `text` is the passage as stored, with its overlap; the
/// title is kept apart, so the eval can embed it under whichever prompt contract
/// it is testing.
String ragCorpusJsonl(
  Iterable<CorpusPage> pages, {
  List<int> chunkSizes = kCorpusChunkSizes,
}) {
  final out = StringBuffer();
  for (final page in pages) {
    for (final size in chunkSizes) {
      final overlap = (size * kChunkOverlapWords / kChunkWords).round();
      for (final draft in chunkPage(
        text: page.text,
        notebookId: page.notebookId,
        pageId: page.pageId,
        maxWords: size,
        overlapWords: overlap,
      )) {
        out.writeln(jsonEncode({
          'id': 'w$size-p${page.pageId}-c${draft.source.ordinal}',
          'chunk_words': size,
          'page_id': page.pageId,
          'title': page.title,
          'text': draft.text,
        }));
      }
    }
  }
  return out.toString();
}
