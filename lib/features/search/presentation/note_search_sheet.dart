// Find-in-notebook: type a word, see which pages contain it, tap to jump.
//
// Reads the same per-page text the home search reads, so anything findable from
// the notes list is findable inside the note.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/search_providers.dart';
import '../../../data/persistence/page_text_store.dart';
import '../../../editor/state/page_notifier.dart';
import '../domain/note_search.dart';

/// Opens find-in-notebook. Resolves to the page index the user chose to jump
/// to, or null if they dismissed without picking one.
Future<int?> showNoteSearchSheet(
  BuildContext context,
  WidgetRef ref, {
  required int notebookId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      // Sit above the keyboard rather than behind it.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _NoteSearchSheet(notebookId: notebookId),
    ),
  );
}

class _NoteSearchSheet extends ConsumerStatefulWidget {
  final int notebookId;

  const _NoteSearchSheet({required this.notebookId});

  @override
  ConsumerState<_NoteSearchSheet> createState() => _NoteSearchSheetState();
}

class _NoteSearchSheetState extends ConsumerState<_NoteSearchSheet> {
  final _controller = TextEditingController();

  List<PageText> _pages = const [];
  Map<int, int> _pageIndexById = const {};
  List<NoteSearchHit> _hits = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Loads the notebook's text once. Searching then runs in memory on every
  /// keystroke — a notebook's worth of text is small, and re-querying storage
  /// per character would be pointless work.
  Future<void> _load() async {
    final pages =
        await ref.read(pageRepositoryProvider).getPagesForNotebook(widget.notebookId);
    final texts =
        await ref.read(pageTextStoreProvider).forNotebook(widget.notebookId);
    if (!mounted) return;
    setState(() {
      _pages = texts;
      _pageIndexById = {
        for (var i = 0; i < pages.length; i++) pages[i].id: i,
      };
      _loading = false;
    });
  }

  void _onQueryChanged(String query) {
    setState(() {
      _hits = NoteSearch.search(
        pages: _pages,
        pageIndexById: _pageIndexById,
        query: query,
        // Ordering comes from the notebook, and a page absent from the ordering
        // cannot be jumped to, so drop those rather than showing a dead row.
      ).where((h) => h.pageIndex >= 0).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Find in notebook',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
              ),
            ),
            if (!_loading && query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _resultsLabel(query),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Flexible(child: _body(query)),
          ],
        ),
      ),
    );
  }

  String _resultsLabel(String query) {
    final total = NoteSearch.countMatches(_pages, query);
    if (total == 0) return 'No matches';
    final shown = _hits.length;
    final pages = _hits.map((h) => h.pageIndex).toSet().length;
    final suffix = ' on $pages ${pages == 1 ? 'page' : 'pages'}';
    return shown < total
        ? 'Showing $shown of $total matches$suffix'
        : '$total ${total == 1 ? 'match' : 'matches'}$suffix';
  }

  Widget _body(String query) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (query.isEmpty) {
      return _message(
        _pages.isEmpty
            ? 'Nothing has been read from this notebook yet. Handwriting and '
                'imported pages become searchable shortly after you write them.'
            : 'Type to search this notebook.',
      );
    }
    if (_hits.isEmpty) {
      return _message('No matches for "$query".');
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _hits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final hit = _hits[i];
        return ListTile(
          title: Text(hit.pageLabel,
              style: Theme.of(context).textTheme.labelMedium),
          subtitle: _HighlightedSnippet(hit: hit),
          onTap: () => Navigator.pop(context, hit.pageIndex),
        );
      },
    );
  }

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

/// The snippet with the matched run emphasised.
class _HighlightedSnippet extends StatelessWidget {
  final NoteSearchHit hit;

  const _HighlightedSnippet({required this.hit});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    final end = hit.matchStart + hit.matchLength;
    // Defensive: never let a bad offset throw inside a list item.
    if (hit.matchStart < 0 || end > hit.snippet.length) {
      return Text(hit.snippet, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: hit.snippet.substring(0, hit.matchStart)),
          TextSpan(
            text: hit.snippet.substring(hit.matchStart, end),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
            ),
          ),
          TextSpan(text: hit.snippet.substring(end)),
        ],
      ),
    );
  }
}
