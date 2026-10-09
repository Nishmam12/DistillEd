// Debug builds only (Settings → AI → Export RAG corpus): reads every notebook's
// pages, with the same title each page is indexed under, and returns the corpus
// as JSON lines for an external embedding eval.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkflow/core/providers/search_providers.dart';
import 'package:inkflow/data/persistence/page_text_store.dart';
import 'package:inkflow/editor/state/page_notifier.dart';
import 'package:inkflow/features/ai/domain/rag/page_chunker.dart';
import 'package:inkflow/features/ai/domain/rag/rag_corpus.dart';
import 'package:inkflow/features/export/export_share_service.dart';
import 'package:inkflow/features/home/data/repositories/note_repository.dart';
import 'package:inkflow/features/home/data/repositories/page_repository.dart';
import 'package:inkflow/features/home/presentation/home_notifier.dart';

Future<String> _buildRagCorpus({
  required NoteRepository notes,
  required PageRepository pages,
  required PageTextStore texts,
}) async {
  final corpus = <CorpusPage>[];
  for (final notebook in await notes.getAllNotebooks()) {
    // An imported document's name is part of its page's title, as it is when
    // the page is indexed, so the eval embeds what the app embeds.
    final sources = {
      for (final page in await pages.getPagesForNotebook(notebook.id))
        page.id: page.importSourceName,
    };
    for (final page in await texts.forNotebook(notebook.id)) {
      corpus.add(CorpusPage(
        notebookId: notebook.id,
        pageId: page.pageId,
        title: chunkTitle(
          notebookTitle: notebook.title,
          sourceName: sources[page.pageId],
        ),
        text: page.text,
      ));
    }
  }
  return ragCorpusJsonl(corpus);
}

/// Shares the corpus through the system share sheet. Only the debug-only Settings
/// row calls this.
Future<void> shareRagCorpus(WidgetRef ref) async {
  final corpus = await _buildRagCorpus(
    notes: ref.read(noteRepositoryProvider),
    pages: ref.read(pageRepositoryProvider),
    texts: ref.read(pageTextStoreProvider),
  );
  await ExportShareService.shareFile(
    bytes: Uint8List.fromList(utf8.encode(corpus)),
    filename: 'rag_corpus.jsonl',
    mimeType: 'application/x-ndjson',
  );
}
