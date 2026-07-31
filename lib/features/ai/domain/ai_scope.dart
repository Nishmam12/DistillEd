// What a request COVERS — the one definition of "this page" vs "this PDF" vs
// "the whole notebook", shared by Ask-your-notes, Summarize, Explain and the
// Knowledge Graph.
//
// It exists because every one of those features had drifted to its own answer.
// Summarize named selection/page/notebook in a sidebar enum; Ask retrieved over
// a whole notebook and nothing else; the Knowledge Graph could only be built
// for a notebook; and RAG indexing, which is what actually makes any of them
// work, only ever ran on the page the user was looking at. A student who
// imports a 40-page lecture PDF into a notebook that also holds their own
// revision notes is served badly by all three of those: "this page" is one
// slide, "the whole notebook" mixes the lecture with their own writing, and
// "the whole PDF" — the unit they actually think in — had no name at all.
//
// So a scope is resolved to a PAGE-ID SET plus enough metadata to label it, and
// every feature takes it from here. Two properties matter:
//
//   • Resolution is pure. [AiScopeResolver] takes a page loader callback, so
//     scoping is unit-tested with a list and no Isar (the same seam
//     [RagIndexer] and [RagRetriever] use).
//   • A scope is resolved ONCE and then carried as data. Features never
//     re-derive "which pages did they mean" halfway through a run, so a page
//     inserted mid-answer can't silently widen what was asked for.
//
// Grouping comes from [NotePage.importGroupId], minted per import — see that
// field's doc for why it lives on the page rather than being inferred.

/// The unit a request covers.
enum AiScopeKind {
  /// Only the elements the user has selected, on the page they're on.
  selection,

  /// The single page currently open. Never silently more than that.
  page,

  /// Every page that arrived from the same import — "the whole PDF".
  importGroup,

  /// Every page in the notebook.
  notebook,
}

/// One page as scope resolution sees it: its id and where it came from.
/// Deliberately not [NotePage] — this domain must not know about Isar.
class ScopePage {
  final int pageId;

  /// The import this page arrived with, or null when the user made it by hand.
  final String? importGroupId;

  /// Human name of the imported file, e.g. `lecture.pdf`.
  final String? importSourceName;

  const ScopePage({
    required this.pageId,
    this.importGroupId,
    this.importSourceName,
  });
}

/// A resolved scope: exactly which pages, and how to describe them.
class AiScope {
  final AiScopeKind kind;
  final int notebookId;

  /// The pages covered, in page order. Empty only when the notebook is (or when
  /// a stale page id was resolved) — callers treat empty as "nothing to read"
  /// rather than as an error.
  final List<int> pageIds;

  /// The page the request started from. Set for every kind: even a
  /// notebook-wide summary is launched from somewhere, and the Explain /
  /// selection paths need it.
  final int? focusPageId;

  /// Selected element ids — [AiScopeKind.selection] only, empty otherwise.
  final Set<String> elementIds;

  /// The import this scope covers, for [AiScopeKind.importGroup].
  final String? importGroupId;

  /// Name of the imported file, when known — for the label a menu shows.
  final String? importSourceName;

  const AiScope({
    required this.kind,
    required this.notebookId,
    required this.pageIds,
    this.focusPageId,
    this.elementIds = const {},
    this.importGroupId,
    this.importSourceName,
  });

  /// True when this scope reads more than the page the user is on — the
  /// condition for showing a "reading N pages" note in the UI.
  bool get spansMultiplePages => pageIds.length > 1;

  /// Page ids as a set, for the retrieval filter.
  Set<int> get pageIdSet => pageIds.toSet();

  /// Short human description, e.g. `this page`, `lecture.pdf (12 pages)`.
  /// Used in menus and in the "answered from…" line, so a student can always
  /// see what the answer was allowed to read.
  String get label => switch (kind) {
        AiScopeKind.selection => 'the selection',
        AiScopeKind.page => 'this page',
        AiScopeKind.importGroup => importSourceName == null
            ? 'this PDF (${pageIds.length} pages)'
            : '$importSourceName (${pageIds.length} pages)',
        AiScopeKind.notebook => 'the whole notebook',
      };
}

/// Turns a requested [AiScopeKind] into the concrete pages it covers.
///
/// Storage-agnostic: pages arrive through [pagesOf], wired in production to the
/// page repository and in tests to a plain list.
class AiScopeResolver {
  final Future<List<ScopePage>> Function(int notebookId) _pagesOf;

  const AiScopeResolver({
    required Future<List<ScopePage>> Function(int notebookId) pagesOf,
  }) : _pagesOf = pagesOf;

  /// Resolves [kind] for [pageId] within [notebookId].
  ///
  /// [AiScopeKind.importGroup] falls back to the single page when that page did
  /// not come from an import — asking for "the whole PDF" on a hand-written
  /// page is a UI state that shouldn't arise (see [optionsFor]), and quietly
  /// widening it to the notebook would read pages the user never asked for.
  Future<AiScope> resolve({
    required AiScopeKind kind,
    required int notebookId,
    required int pageId,
    Set<String> elementIds = const {},
  }) async {
    switch (kind) {
      case AiScopeKind.selection:
        return AiScope(
          kind: kind,
          notebookId: notebookId,
          pageIds: [pageId],
          focusPageId: pageId,
          elementIds: elementIds,
        );

      case AiScopeKind.page:
        return AiScope(
          kind: kind,
          notebookId: notebookId,
          pageIds: [pageId],
          focusPageId: pageId,
        );

      case AiScopeKind.importGroup:
        final pages = await _pagesOf(notebookId);
        final here = _find(pages, pageId);
        final groupId = here?.importGroupId;
        if (groupId == null) {
          return AiScope(
            kind: AiScopeKind.page,
            notebookId: notebookId,
            pageIds: [pageId],
            focusPageId: pageId,
          );
        }
        final group = [
          for (final p in pages)
            if (p.importGroupId == groupId) p,
        ];
        return AiScope(
          kind: kind,
          notebookId: notebookId,
          pageIds: [for (final p in group) p.pageId],
          focusPageId: pageId,
          importGroupId: groupId,
          importSourceName: here?.importSourceName,
        );

      case AiScopeKind.notebook:
        final pages = await _pagesOf(notebookId);
        return AiScope(
          kind: kind,
          notebookId: notebookId,
          pageIds: [for (final p in pages) p.pageId],
          focusPageId: pageId,
        );
    }
  }

  /// The import group [pageId] belongs to, or null when it wasn't imported.
  ///
  /// Drives whether a scope menu offers "Whole PDF" at all — the option is
  /// hidden rather than shown-and-disabled, since a page that came from
  /// nowhere has no PDF to name.
  Future<ScopePage?> importGroupOf({
    required int notebookId,
    required int pageId,
  }) async {
    final page = _find(await _pagesOf(notebookId), pageId);
    return page?.importGroupId == null ? null : page;
  }

  static ScopePage? _find(List<ScopePage> pages, int pageId) {
    for (final p in pages) {
      if (p.pageId == pageId) return p;
    }
    return null;
  }
}
