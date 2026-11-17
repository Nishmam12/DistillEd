// Loads what `rankTerms` ranks for one notebook: its stored page text and the
// key concepts the learning memory keeps for it. Read when a title or tag
// field opens; never throws (no suggestions instead).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/persistence/page_text_store.dart';
import '../../ai/presentation/ai_providers.dart' show learningMemoryProvider;
import '../domain/suggested_terms.dart';

Future<List<String>> suggestedTermsFor(WidgetRef ref, int notebookId,
    {int max = 10}) async {
  try {
    final pages = await ref.read(pageTextStoreProvider).forNotebook(notebookId);
    final concepts = await ref.read(learningMemoryProvider).allConcepts(notebookId)
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return rankTerms(
      pageTexts: [for (final p in pages) p.text],
      concepts: [for (final c in concepts.take(5)) c.conceptName],
      max: max,
    );
  } catch (_) {
    return const [];
  }
}
