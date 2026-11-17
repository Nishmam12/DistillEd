// The notebook editor on the unified engine. Opens a notebook
// by id, drives page navigation through the existing [pageProvider], and binds
// the unified [SceneCanvas] to the real Isar-backed scene store (so edits load
// and autosave through [SceneElementRecord]). Paper colour + template come from
// the [Notebook]. All chrome is shared with the dev playground.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_log.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/paper_colors.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../data/backup/backup_service.dart' show BackupTrigger;
import '../../backup/backup_controller.dart';
import '../../../domain/commands/scene_command.dart';
import '../../../domain/geometry/element_bounds.dart';
import '../../../domain/model/scene_element.dart';
import '../../ai/domain/ai_scope.dart';
import '../../ai/domain/page_content_extractor.dart' show kLocalImageReads;
import '../../ai/presentation/ai_providers.dart';
import '../../ai/presentation/notebook_index_notifier.dart';
import '../../search/presentation/page_index_provider.dart';
import '../../home/domain/suggested_terms.dart' show asTitle;
import '../../home/presentation/suggested_terms_loader.dart';
import '../../ai/presentation/sidebar/ai_sidebar.dart';
import '../../ai/domain/features/explainer.dart' show ExplainMode;
import '../../ai/presentation/explain_notifier.dart' show ExplainRequest;
import 'controls/text_selection_bar.dart';
import '../../ai/presentation/sidebar/floating_ai_panel.dart';
import '../../ai/presentation/widgets/cloud_send_dialog.dart';
import '../../../domain/model/page_size.dart';
import '../../../domain/model/template_type.dart';
import '../../import/pdf_service.dart'
    show ImportCancelledException, ImportException, PdfLockedException;
import '../../../editor/import/text_pages.dart' show paginateText;
import '../../../editor/render/scene_element_painter.dart'
    show SceneElementPainter;
import '../../audio/domain/lecture_recording.dart' show LectureRecording;
import '../../audio/presentation/audio_providers.dart';
import '../../audio/presentation/lecture_transcript_sheet.dart';
import '../../audio/presentation/lecture_transcription_notifier.dart';
import '../../audio/presentation/recording_notifier.dart';
import '../../audio/presentation/transcription_providers.dart';
import '../../audio/presentation/lecture_language_picker.dart';
import '../../search/presentation/note_search_sheet.dart';
import '../../../editor/import/fit_image_rect.dart';
import '../../../editor/import/ml_kit_document_scanner.dart';
import '../../../editor/import/scene_import_service.dart';
import '../../share/share_intake.dart' show SharedPayload;
import '../../../editor/state/page_notifier.dart';
import '../../home/data/repositories/note_repository.dart';
import '../../home/domain/models/notebook.dart';
import '../../summarize/presentation/summarize_notifier.dart';
import '../../home/presentation/home_notifier.dart';
import '../../summarize/presentation/widgets/summary_bottom_sheet.dart';
import '../../../widgets/template_icons.dart';
import '../../../editor/state/editor_tool_controller.dart';
import '../../../editor/state/history_controller.dart';
import '../../../editor/state/library_controller.dart';
import '../../../editor/state/scene_controller.dart';
import '../../../editor/state/page_text_selection.dart';
import '../../../editor/state/search_highlight.dart';
import '../../../editor/ui/pdf_link_layer.dart';
import '../../../editor/ui/search_highlight_layer.dart';
import '../../../domain/model/element_link.dart';
import '../../../domain/model/page_links.dart';
import '../../../core/utils/external_links.dart';
import '../../import/link_target.dart';
import '../../../editor/state/selection_controller.dart';
import '../../../editor/state/viewport_controller.dart';
import '../../../editor/ui/editable_note_title.dart';
import 'controls/backlinks_chip.dart';
import 'controls/editor_app_bar_actions.dart';
import 'controls/editor_bottom_bar.dart';
import '../../../editor/ui/controls/editor_tool_options_overlay.dart';
import '../../../editor/ui/controls/page_actions_sheet.dart';
import '../../../editor/ui/controls/undo_redo_buttons.dart';
import '../../../editor/ui/neighbour_pages_layer.dart';
import '../../../editor/ui/scene_canvas.dart';
import '../../../editor/ui/universal_color_palette.dart';
import '../../../editor/ui/zoom_pill.dart';

part 'notebook_editor_widgets.dart';

/// On-screen size an inserted AI note aims for, in logical pixels. Converted
/// to scene units against the live zoom so a note looks the same whether it
/// was inserted at 14% or 300%.
const double _noteScreenWidth = 360.0;
const double _noteScreenFontSize = 16.0;

/// Finds a clear scene-space slot for an "insert as note" box, **within
/// [bounds]** (the slice of the scene currently on screen).
///
/// Starts at [bounds]' top-left and slides the [width]×[height] box straight
/// down past every rect in [existing] it would overlap, so a note never lands
/// on top of existing content — the user's own text and handwriting included —
/// or on a note inserted moments earlier. A box only clears rects it actually
/// overlaps, so a note can sit beside content off to one side.
///
/// Returns null when no clear slot fits inside [bounds]: the caller reports
/// "no space" rather than dropping the note somewhere off-screen that the user
/// would have to zoom out to find. The scan is bounded so a pathological
/// layout can't loop forever.
@visibleForTesting
Rect? placeNoteSlot({
  required Rect bounds,
  required double width,
  required double height,
  required List<Rect> existing,
}) {
  const gap = 16.0;
  final left = bounds.left + gap;
  var box = Rect.fromLTWH(left, bounds.top + gap, width, height);

  for (var i = 0; i < 200; i++) {
    if (box.bottom > bounds.bottom) return null;

    var lowestOverlap = double.negativeInfinity;
    for (final r in existing) {
      if (r.overlaps(box) && r.bottom > lowestOverlap) lowestOverlap = r.bottom;
    }
    if (lowestOverlap == double.negativeInfinity) return box;

    box = Rect.fromLTWH(left, lowestOverlap + gap, width, height);
  }
  return null;
}

/// Where a picture added to the current page lands: half the size of the area
/// it lands in, centred there if that spot is clear of [existing] content, else
/// in the first clear slot ([placeNoteSlot]), else centred anyway — it arrives
/// selected, ready to be dragged, so a crowded view still gets it.
///
/// [page] is the sheet in page mode: only the paper is drawn there, so the
/// picture is kept on it. [Rect.zero] when [source] cannot be measured.
@visibleForTesting
Rect placeImageInView({
  required Size source,
  required Rect visible,
  Rect? page,
  required List<Rect> existing,
}) {
  final centred = inlinePlacement(source, visible, page: page);
  if (centred.isEmpty) return Rect.zero;
  if (!existing.any(centred.overlaps)) return centred;

  final area = page == null || page.isEmpty
      ? visible
      : (visible.overlaps(page) ? visible.intersect(page) : page);
  return placeNoteSlot(
        bounds: area,
        width: centred.width,
        height: centred.height,
        existing: existing,
      ) ??
      centred;
}

/// What the user picked from the import sheet.
enum _ImportSource { gallery, camera, pdf, text }

class NotebookEditorScreen extends ConsumerStatefulWidget {
  final int notebookId;

  /// Open on this page (0-based) and, with [searchQuery], tint its matches:
  /// set when a home-screen search result is opened.
  final int? initialPageIndex;
  final String? searchQuery;

  /// What was shared into Margo for this note; imported once the page is ready.
  final SharedPayload? pendingShare;

  const NotebookEditorScreen({
    super.key,
    required this.notebookId,
    this.initialPageIndex,
    this.searchQuery,
    this.pendingShare,
  });

  @override
  ConsumerState<NotebookEditorScreen> createState() =>
      _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends ConsumerState<NotebookEditorScreen> {
  final Set<int> _loadedPages = {};
  bool _openedAtResult = false;
  Notebook? _notebook;
  // Set when the notebook is missing or could not be opened. Without it the
  // screen would wait on the page list forever.
  bool _unavailable = false;

  /// Whether the docked AI panel is showing (wide screens only; on phones the
  /// AI action opens a bottom sheet instead and this stays false).
  bool _aiPanelOpen = false;

  /// Pictures just added to the page that the user is still positioning; null
  /// when nothing is being placed. See [_placeOnPage].
  ({
    ScenePageKey key,
    Set<String> ids,
    List<ImportedImage> images,
    EditorTool previousTool,
  })? _placing;

  /// The canvas area's size at its first layout, held for the rest of the
  /// session: the page of a "fit screen" notebook. See the [LayoutBuilder] in
  /// [build] for why it cannot live in the canvas.
  Size? _screenSheet;

  /// The page's size in the page layouts: the notebook's paper size, or for a
  /// "fit screen" notebook the screen-shaped sheet latched above.
  Size? get _pageSheet => _pageKind.size ?? _screenSheet;

  PageSizeKind get _pageKind =>
      PageSizeKind.fromIndex(_notebook?.pageSize ?? 0);

  /// Continuous layout: a page step is on its way (see [_stepPage]).
  bool _pageStepPending = false;

  /// The docked AI panel's width while its edge is being dragged; null when
  /// not dragging, and the saved width is used.
  double? _aiPanelDragWidth;

  /// Disambiguates ids of AI-inserted notes and imported images created in the
  /// same microsecond.
  int _noteSeq = 0;

  final SceneImportService _import =
      SceneImportService(scanner: MlKitDocumentScanner());

  // Held from initState: `ref` is unusable in dispose().
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    // listen: false — subscribing to an inherited widget in initState asserts.
    _container = ProviderScope.containerOf(context, listen: false);
    Future.microtask(_init);
  }

  @override
  void dispose() {
    // Leaving the editor must not leave the microphone live with no control on
    // screen (a killed process would also lose the unfinalized file). Only the
    // route popping reaches here; backgrounding the app does not.
    final provider = recordingNotifierProvider(widget.notebookId);
    final active = _container.read(provider).active;
    if (active != null) {
      unawaited(_container.read(provider.notifier).stop(active.pageId));
    }
    // What was written here becomes searchable now, not at the next start.
    unawaited(_container.read(pageIndexQueueProvider).run());
    // Per-page scene and undo state would otherwise live until the app dies.
    _container.read(pageProvider(widget.notebookId).notifier).release();
    // The search tint, reading mode and the canvas lock belong to this visit:
    // the next notebook opens untinted, with its tools, moving freely. Cleared
    // a moment later: a provider is not changed while the tree is being torn
    // down.
    final container = _container;
    Future.microtask(() {
      container.read(searchHighlightProvider.notifier).state = null;
      final readingFrom = container.read(readingModeProvider);
      if (readingFrom != null) {
        container.read(readingModeProvider.notifier).state = null;
        container.read(editorToolProvider.notifier).useTool(readingFrom);
      }
      container.read(canvasLockedProvider.notifier).state = false;
    });
    // Leaving a note is when "back up after each note" runs. The backup waits
    // for this page's queued writes itself (see AppBackupLibrary.snapshot).
    if (_container.read(settingsProvider).autoBackup) {
      unawaited(_container
          .read(backupControllerProvider.notifier)
          .trigger(BackupTrigger.leftEditor));
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await ref.read(pageProvider(widget.notebookId).notifier).initialize();
      if (!mounted) return;
      final nb =
          await ref.read(noteRepositoryProvider).getNotebook(widget.notebookId);
      if (!mounted) return;
      if (nb == null) {
        setState(() => _unavailable = true);
        return;
      }
      await ref.read(libraryProvider.notifier).load();
      if (mounted) setState(() => _notebook = nb);
      final share = widget.pendingShare;
      if (share != null && mounted) unawaited(_receiveShare(share));
    } catch (e, st) {
      unawaited(ErrorLog.record(e, st));
      if (mounted) setState(() => _unavailable = true);
    }
  }

  Color get _paperColor => Color(_notebook?.backgroundColor ?? 0xFFFFFDF7);

  /// The notebook's own paper.
  TemplateType get _notebookTemplate {
    final i = _notebook?.templateIndex ?? 0;
    return (i >= 0 && i < TemplateType.values.length)
        ? TemplateType.values[i]
        : TemplateType.blank;
  }

  /// The paper of the page being written on: its own, or the notebook's.
  TemplateType get _template {
    final state = ref.read(pageProvider(widget.notebookId));
    if (state.pages.isEmpty) return _notebookTemplate;
    final i = state.currentPageIndex.clamp(0, state.pages.length - 1);
    return templateForPage(state.pages[i], _notebookTemplate);
  }

  /// 0 infinite, 1 single page, 2 continuous (see [Notebook.layoutMode]).
  int get _layoutMode => _notebook?.layoutMode ?? 0;

  /// Bounded pages: single page and continuous.
  bool get _pageMode => _layoutMode == 1 || _layoutMode == 2;

  bool get _continuous => _layoutMode == 2;

  /// Continuous layout: make the page above (-1) or below (1) the current
  /// one, shifting the view by one page so nothing on screen moves. Done a
  /// moment later, never in the middle of a viewport or pointer update.
  void _stepPage(int direction) {
    if (_pageStepPending) return;
    _pageStepPending = true;
    Future.microtask(() {
      _pageStepPending = false;
      if (!mounted || !_continuous) return;
      final state = ref.read(pageProvider(widget.notebookId));
      final count = state.pages.length;
      final next = state.currentPageIndex + direction;
      if (next < 0 || next >= count) return;
      _switchTo(next);
      ref
          .read(viewportProvider.notifier)
          .shiftPage(direction, above: next > 0, below: next < count - 1);
    });
  }

  /// Loads a page's elements from the store once per session.
  void _ensureLoaded(ScenePageKey key) {
    if (_loadedPages.contains(key.pageId)) return;
    _loadedPages.add(key.pageId);
    Future.microtask(
        () => ref.read(sceneControllerProvider(key).notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(pageProvider(widget.notebookId));
    // Reading mode hides the toolbars; see toggleReadingMode.
    final reading = ref.watch(readingModeProvider) != null;

    // Opened from a search result: go to the page once the pages are in.
    final openAt = widget.initialPageIndex;
    if (openAt != null &&
        !_openedAtResult &&
        openAt >= 0 &&
        openAt < pageState.pages.length) {
      _openedAtResult = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _switchTo(openAt);
        final q = widget.searchQuery;
        if (q != null) _tintSearch(openAt, q);
      });
    }

    // Every AI feature that can send text to a cloud model the student picked
    // is started from this screen (the AI panel and its sheets), so this is
    // where the "send this?" question is shown.
    showCloudSendPrompts(context, ref);

    // Placing pictures ends when they stop being selected (a tap elsewhere,
    // Done, a page turn) or when the user picks another tool themselves.
    // The words tinted for a search belong to the page they were found on:
    // leaving it ends the tint.
    ref.listen(pageProvider(widget.notebookId), (_, next) {
      final tint = ref.read(searchHighlightProvider);
      if (tint == null || next.pages.isEmpty) return;
      final at = next.currentPageIndex.clamp(0, next.pages.length - 1);
      if (next.pages[at].id != tint.pageId) {
        ref.read(searchHighlightProvider.notifier).state = null;
      }
    });
    ref.listen<Set<String>>(selectionProvider, (_, next) {
      final placing = _placing;
      if (placing != null && !next.containsAll(placing.ids)) _endPlacement();
    });
    ref.listen<EditorTool>(editorToolProvider.select((s) => s.tool), (_, next) {
      if (_placing != null && next != EditorTool.select) {
        setState(() => _placing = null);
      }
    });

    if (_unavailable) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("This notebook couldn't be opened."),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to notes'),
              ),
            ],
          ),
        ),
      );
    }

    if (pageState.pages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final index =
        pageState.currentPageIndex.clamp(0, pageState.pages.length - 1);
    final page = pageState.pages[index];
    final key = (notebookId: widget.notebookId, pageId: page.id);
    _ensureLoaded(key);

    // Continuous layout: the pages either side are drawn too, and the page
    // in the middle of the window is the one being written on.
    final above = _continuous && index > 0 ? pageState.pages[index - 1] : null;
    final below = _continuous && index < pageState.pages.length - 1
        ? pageState.pages[index + 1]
        : null;
    for (final p in [?above, ?below]) {
      _ensureLoaded((notebookId: widget.notebookId, pageId: p.id));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(viewportProvider.notifier)
            .setNeighbours(above: above != null, below: below != null);
      }
    });
    ref.listen(viewportProvider, (_, _) {
      if (!_continuous) return;
      final d = ref.read(viewportProvider.notifier).pageAtMiddle();
      if (d != 0) _stepPage(d);
    });

    return Scaffold(
      // The keyboard must not resize the canvas: it would shrink the page on
      // every frame of the keyboard's slide. Text fields that need to stay
      // above it (the docked AI panel) pad themselves instead.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: AppIconButton(
          AppIcons.home,
          tooltip: 'Home',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        // Title, then undo/redo beside it as in the Margo mockup. The title
        // gives way first so the history buttons never slide off-screen.
        title: Row(
          children: [
            Flexible(
              child: EditableNoteTitle(
                title: _notebook?.title ?? 'Notebook',
                onRename: _notebook == null ? null : _rename,
                suggestTitles: () async => [
                  for (final t in await suggestedTermsFor(
                      ref, widget.notebookId,
                      max: 5))
                    asTitle(t),
                ],
              ),
            ),
            const SizedBox(width: 16),
            UndoRedoButtons(pageKey: key),
          ],
        ),
        actions: [
          _RecordButton(notebookId: widget.notebookId, pageId: key.pageId),
          AppIconButton(
            AppIcons.toolbarSearch,
            tooltip: 'Find in notebook',
            onPressed: _findInNotebook,
          ),
          AppIconButton(
            AppIcons.ai,
            tooltip: 'AI insights',
            color: _aiPanelOpen ? context.colors.accent : null,
            onPressed: () => _toggleAiPanel(key),
          ),
          AppIconButton(
            AppIcons.note,
            tooltip: 'Study plan',
            onPressed: () => context.push('/note2/${widget.notebookId}/plan'),
          ),
          AppIconButton(
            AppIcons.graph,
            tooltip: 'Knowledge graph',
            onPressed: () => context.push(
                '/note2/${widget.notebookId}/graph?pageId=${key.pageId}'),
          ),
          AppIconButton(
            AppIcons.book,
            tooltip: 'Book view',
            onPressed: () => context.push('/note2/${widget.notebookId}/book'),
          ),
          EditorAppBarActions(
            pageKey: key,
            onReviewFlashcards: () =>
                context.push('/note2/${widget.notebookId}/review'),
            onChangeBackground: _notebook == null ? null : _showBackgroundSheet,
            onSummarize: () =>
                _summarizeScope(key, SummarizeScopeChoice.notebook),
            onIndexNotebook:
                _notebook == null ? null : () => unawaited(_indexWholeNotebook()),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                // Tool bar docked directly under the app bar, with a hairline
                // divider separating it from the canvas below.
                if (!reading) ...[
                  EditorBottomBar(
                    pageKey: key,
                    onImport: () => _showImportSheet(key),
                    onOpenLink: (link) => unawaited(_followElementLink(link)),
                  ),
                  const Divider(height: 1, thickness: 1),
                ],
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    // The page's size is latched here rather than inside the
                    // canvas, because the canvas is keyed by page id and so is
                    // rebuilt from scratch on every page turn — a latch living
                    // there would re-take its size from whatever the canvas had
                    // shrunk to, and switching pages with the AI panel open
                    // would leave the new page a narrow sliver. This state
                    // outlives both.
                    if (!constraints.biggest.isEmpty) {
                      _screenSheet ??= constraints.biggest;
                    }
                    final sheet = _pageSheet;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: SceneCanvas(
                            key: ValueKey(page.id),
                            notebookId: widget.notebookId,
                            pageId: page.id,
                            backgroundColor: _paperColor,
                            templateType: _template,
                            pageMode: _pageMode,
                            pageSize: sheet,
                            continuous: _continuous,
                            onNeighbourTouched: _stepPage,
                            stampStroke: (ageMs) => ref
                                .read(recordingSessionProvider(
                                    widget.notebookId))
                                .stampFor(ref.read(engineClockProvider)() - ageMs),
                          ),
                        ),
                        if (_continuous && sheet != null)
                          Positioned.fill(
                            child: NeighbourPagesLayer(
                              notebookId: widget.notebookId,
                              abovePageId: above?.id,
                              belowPageId: below?.id,
                              sheet: sheet,
                              paperColor: _paperColor,
                              template: _template,
                              aboveTemplate: above == null
                                  ? null
                                  : templateForPage(above, _notebookTemplate),
                              belowTemplate: below == null
                                  ? null
                                  : templateForPage(below, _notebookTemplate),
                            ),
                          ),
                        // Search words tinted, and the links of PDF pages.
                        Positioned.fill(
                            child: SearchHighlightLayer(pageKey: key)),
                        Positioned.fill(
                            child: PdfLinkLayer(
                                pageKey: key,
                                onFollow: _followLink,
                                onFollowElement: (link) =>
                                    unawaited(_followElementLink(link)))),
                        // Zoom level and the universal colour palette, both
                        // top-right under the toolbar; tap the pill to reset
                        // the view, tap the swatch to open the colour grid.
                        Positioned(
                          right: 16,
                          top: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const ZoomPill(),
                              if (!reading) ...const [
                                SizedBox(height: 8),
                                UniversalColorPalette(),
                              ] else ...[
                                const SizedBox(height: 8),
                                ActionChip(
                                  key: const ValueKey('exitReading'),
                                  avatar: const Icon(Icons.edit_outlined,
                                      size: 16),
                                  label: const Text('Done reading'),
                                  onPressed: () => toggleReadingMode(ref),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // The active tool's options — floats over the canvas
                        // rather than sitting in the toolbar's own layout, so
                        // opening/closing it never resizes (and so never
                        // shifts) the page underneath a mid-stroke drawing.
                        if (!reading)
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: EditorToolOptionsOverlay(pageKey: key),
                            ),
                          ),
                        if (_placing case final placing?
                            when placing.key.pageId == page.id)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Center(
                              child: _PlacementBar(
                                count: placing.ids.length,
                                onDone: () => ref
                                    .read(selectionProvider.notifier)
                                    .clear(),
                                onOwnPage: () =>
                                    unawaited(_placedToOwnPages()),
                                onRemove: _removePlaced,
                              ),
                            ),
                          ),
                        // "Linked from": pages that link here.
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: BacklinksChip(
                              pageKey: key,
                              onOpen: (link) => unawaited(_followElementLink(
                                  LinkToPage(link.pageId).encoded)),
                            ),
                          ),
                        ),
                        // The lecture player, above the bars that share
                        // the bottom edge.
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 80,
                          child: Center(
                            child: _LecturePlayerBar(
                                notebookId: widget.notebookId),
                          ),
                        ),
                        // Words selected on a page picture (select tool, Text).
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Center(
                            child: TextSelectionBar(
                              pageKey: key,
                              onAsk: (text) => _askAboutText(key, text),
                              onJump: _jumpToSearchHit,
                            ),
                          ),
                        ),
                        // The AI panel floating over the page (wide screens,
                        // the default): the page keeps its full size under it.
                        if (_aiPanelOpen && _aiPanelFloats(context))
                          Positioned.fill(
                            child: FloatingAiPanel(
                              rect: ref.watch(settingsProvider
                                  .select((s) => s.aiPanelFloatRect)),
                              onRectChanged: (r) => unawaited(ref
                                  .read(settingsProvider.notifier)
                                  .setAiPanelFloatRect(r)),
                              builder: (context, onMove, onMoveEnd) =>
                                  _aiSidebar(key,
                                      floating: true,
                                      onMove: onMove,
                                      onMoveEnd: onMoveEnd),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          // Docked AI panel beside the canvas on wide screens; phones use the
          // bottom sheet from _toggleAiPanel instead.
          if (_aiPanelOpen &&
              MediaQuery.of(context).size.width >= kAiSidebarBreakpoint &&
              !_aiPanelFloats(context))
            _aiSidebar(key, floating: false),
        ],
      ),
      bottomNavigationBar: _PageNavBar(
        index: index,
        count: pageState.pages.length,
        onPrev: index > 0 ? () => _switchTo(index - 1) : null,
        onNext: index < pageState.pages.length - 1
            ? () => _switchTo(index + 1)
            : null,
        onAdd: () =>
            ref.read(pageProvider(widget.notebookId).notifier).insertPage(),
        onGrid: () => context.push('/note2/${widget.notebookId}/pages'),
        onOutline: () =>
            context.push('/note2/${widget.notebookId}/outline'),
        onManage: () => showPageActionsSheet(
          context,
          ref,
          notebookId: widget.notebookId,
          pageIndex: index,
          pageCount: pageState.pages.length,
        ),
      ),
    );
  }

  /// Wide screens float the AI panel over the page unless the user docked it.
  bool _aiPanelFloats(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kAiSidebarBreakpoint &&
      ref.watch(settingsProvider.select((s) => s.aiPanelFloating));

  /// The wide-screen AI panel, docked beside the page or floating over it.
  Widget _aiSidebar(ScenePageKey key,
      {required bool floating,
      ValueChanged<Offset>? onMove,
      VoidCallback? onMoveEnd}) {
    return AiSidebar(
      pageKey: key,
      floating: floating,
      onMove: onMove,
      onMoveEnd: onMoveEnd,
      onToggleFloating: () => unawaited(ref
          .read(settingsProvider.notifier)
          .setAiPanelFloating(!floating)),
      width: _aiPanelWidth(context),
      onResize: floating
          ? null
          : (w) => setState(() => _aiPanelDragWidth = w.clamp(
              kAiSidebarMinWidth,
              aiSidebarMaxWidth(MediaQuery.sizeOf(context).width))),
      onResizeEnd: () {
        final w = _aiPanelDragWidth;
        if (w == null) return;
        unawaited(ref.read(settingsProvider.notifier).setAiPanelWidth(w));
        setState(() => _aiPanelDragWidth = null);
      },
      onClose: () => setState(() => _aiPanelOpen = false),
      onSummarize: (choice) => _summarizeScope(key, choice),
      onInsertNote: (text) => _insertNote(key, text),
      // Beside or over the canvas: jumping just switches the page behind the
      // panel, which stays open.
      onJumpToSource: _jumpToSource,
    );
  }

  double _aiPanelWidth(BuildContext context) =>
      (_aiPanelDragWidth ?? ref.watch(settingsProvider).aiPanelWidth).clamp(
          kAiSidebarMinWidth,
          aiSidebarMaxWidth(MediaQuery.sizeOf(context).width));

  void _switchTo(int i) {
    ref.read(selectionProvider.notifier).clear();
    ref.read(pageProvider(widget.notebookId).notifier).switchPage(i);
  }

  /// Find-in-notebook. Picking a result jumps to that page.
  Future<void> _findInNotebook() async {
    final pick = await showNoteSearchSheet(
      context,
      ref,
      notebookId: widget.notebookId,
    );
    if (pick == null || !mounted) return;
    _switchTo(pick.pageIndex);
    _tintSearch(pick.pageIndex, pick.query);
  }

  /// Marks the words [query] found on the page at [pageIndex], once the page
  /// is open, so they can be seen without hunting.
  void _tintSearch(int pageIndex, String query) {
    final pages = ref.read(pageProvider(widget.notebookId)).pages;
    if (pageIndex < 0 || pageIndex >= pages.length || query.trim().isEmpty) {
      return;
    }
    ref.read(searchHighlightProvider.notifier).state =
        SearchHighlight(pageId: pages[pageIndex].id, query: query);
  }

  /// Opens a result of the text bar's Search: the page, with the words tinted.
  void _jumpToSearchHit(int pageId, String query) {
    final pages = ref.read(pageProvider(widget.notebookId)).pages;
    final index = pages.indexWhere((p) => p.id == pageId);
    if (index < 0) return;
    _switchTo(index);
    _tintSearch(index, query);
  }

  /// A tap on a link of an imported PDF page: to another page of the notebook,
  /// or out to the web after asking.
  Future<void> _followLink(PageLink link, String imagePath) async {
    // A tap in Text mode also picked the word under it; following the link
    // should not leave that behind.
    ref.read(pageTextSelectionProvider.notifier).state = null;
    final dest = link.destPage;
    if (dest != null) {
      final state = ref.read(pageProvider(widget.notebookId));
      final store = ref.read(sceneElementStoreProvider);
      final index = await findLinkTargetPage(
        pages: state.pages,
        load: store.loadForPage,
        fromImagePath: imagePath,
        destPage: dest,
        currentIndex: state.currentPageIndex,
      );
      if (!mounted) return;
      if (index == null) {
        _toast("That page isn't in this notebook.");
        return;
      }
      _switchTo(index);
      return;
    }
    await _openWebLink(link.url);
  }

  /// A tap on a linked element: to a page (here or in another notebook), a
  /// whole notebook, or the web after asking.
  Future<void> _followElementLink(String raw) async {
    switch (ElementLink.parse(raw)) {
      case null:
        _toast("That link can't be opened.");
      case LinkToWeb(:final url):
        await _openWebLink(url);
      case LinkToNotebook(:final notebookId):
        if (notebookId == widget.notebookId) {
          _switchTo(0);
        } else if (await ref.read(noteRepositoryProvider).getNotebook(notebookId) ==
            null) {
          _toast('That notebook is no longer there.');
        } else if (mounted) {
          unawaited(context.push('/note2/$notebookId'));
        }
      case LinkToPage(:final pageId):
        final pages = ref.read(pageProvider(widget.notebookId)).pages;
        final here = pages.indexWhere((p) => p.id == pageId);
        if (here >= 0) {
          _switchTo(here);
          return;
        }
        final page = await ref.read(pageRepositoryProvider).getPage(pageId);
        if (!mounted) return;
        if (page == null) {
          _toast('That page is no longer there.');
          return;
        }
        unawaited(
            context.push('/note2/${page.notebookId}?page=${page.pageIndex}'));
    }
  }

  /// Opens [url] in the browser after asking. The address can come from a file
  /// inside someone else's backup: only web addresses are ever opened.
  Future<void> _openWebLink(String? url) async {
    if (url == null || !isSafeLinkUrl(url)) {
      _toast('Margo only opens web links.');
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open this link?'),
        content: SelectableText(url),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              key: const Key('openLinkConfirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    if (!await openExternalUrl(url) && mounted) {
      _toast("Couldn't open $url");
    }
  }

  /// Toggles the live AI insights surface. Wide screens dock it beside the
  /// canvas; phone-width screens open it as a bottom sheet so it never crowds
  /// the drawing area.
  void _toggleAiPanel(ScenePageKey key) {
    final wide = MediaQuery.of(context).size.width >= kAiSidebarBreakpoint;
    // Opening the panel is the first sign the student means to use the model, and
    // the page read that follows needs it: start the load now so it overlaps the
    // panel opening and the first debounce instead of following them. Closing
    // the panel (wide only — the sheet closes itself) warms nothing.
    if (!wide || !_aiPanelOpen) ref.read(localModelWarmerProvider)();
    if (wide) {
      setState(() => _aiPanelOpen = !_aiPanelOpen);
    } else {
      showAiSidebarSheet(context, key,
          onSummarize: (choice) => _summarizeScope(key, choice),
          onInsertNote: (text) => _insertNote(key, text),
          // The sheet covers the canvas, so close it before jumping — otherwise
          // the page switches out of sight behind it.
          onJumpToSource: (pageId) {
            Navigator.of(context).pop();
            _jumpToSource(pageId);
          });
    }
  }

  /// "Ask the AI" on selected words: opens the AI panel and explains them.
  void _askAboutText(ScenePageKey key, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final wide = MediaQuery.of(context).size.width >= kAiSidebarBreakpoint;
    if (!wide || !_aiPanelOpen) _toggleAiPanel(key);
    ref.read(explainNotifierProvider.notifier).run(ExplainRequest(
          mode: ExplainMode.intermediate,
          resolveContent: () async => trimmed,
        ));
  }

  /// Jumps to the page a "Ask your notes" source passage came from, by finding
  /// it in the current notebook. A no-op if the page is gone (e.g. deleted since
  /// it was indexed) rather than throwing.
  void _jumpToSource(int pageId) {
    final pages = ref.read(pageProvider(widget.notebookId)).pages;
    final index = pages.indexWhere((p) => p.id == pageId);
    if (index >= 0) _switchTo(index);
  }

  /// "Insert as note" from the AI sidebar: drops the text onto the current page
  /// as a [TextElement] through the same undoable history path a manual text
  /// box uses (never bypassing it), sized to the wrapped text and placed in the
  /// first clear spot inside the part of the page currently on screen.
  void _insertNote(ScenePageKey key, String text, {String link = ''}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final viewport = ref.read(viewportProvider);
    final canvasSize = ref.read(viewportProvider.notifier).viewportSize;
    if (canvasSize.isEmpty) return; // canvas hasn't laid out yet

    final visible = viewport.visibleSceneRect(canvasSize);

    // Size the note in SCENE units so it occupies a constant share of the
    // screen whatever the zoom: at 14% zoom a fixed 360-unit box is a ~50px
    // unreadable sliver. Clamped so a very zoomed-in view can't ask for a box
    // wider than the visible area itself.
    final zoom = viewport.zoom;
    final width = (_noteScreenWidth / zoom).clamp(1.0, visible.width);
    final fontSize = _noteScreenFontSize / zoom;
    final painter = TextPainter(
      text: TextSpan(text: trimmed, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final height = painter.height + 16 / zoom;
    painter.dispose();

    // Slide the box down past anything already on the page, staying inside the
    // visible area. Bounds come from the canonical [ElementBounds]; degenerate
    // (empty) boxes are dropped so they can't act as a phantom obstacle at the
    // origin, and eraser strokes are skipped since they aren't visible content
    // (same rule PageContentExtractor._inkBounds uses).
    final existing = <Rect>[];
    for (final e in ref.read(sceneControllerProvider(key))) {
      if (e is FreehandElement && e.isEraser) continue;
      final r = ElementBounds.of(e);
      if (!r.isEmpty) existing.add(r);
    }

    final box = placeNoteSlot(
      bounds: visible,
      width: width,
      height: height,
      existing: existing,
    );
    if (box == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('No empty space in view — scroll or zoom out to make room.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }

    final zOrder = ref.read(sceneControllerProvider(key).notifier).nextZOrder();

    ref.read(historyProvider(key).notifier).push(AddElementsCommand([
          TextElement(
            id: '${DateTime.now().microsecondsSinceEpoch}_ai${_noteSeq++}',
            zOrder: zOrder,
            geometryData: [box.left, box.top, box.right, box.bottom],
            text: trimmed,
            color: 0xFF1A1A1A,
            fontSize: fontSize,
            link: link,
          ),
        ]));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Added to the page'),
      duration: Duration(seconds: 1),
    ));
  }

  // ---- import ---------------------------------------------------------------

  /// Brings in what was shared into Margo: pictures onto the current page (or
  /// a page each, as the photo import offers), each PDF as its own document,
  /// and text as a note on the page.
  Future<void> _receiveShare(SharedPayload share) async {
    // The page's size latches on the canvas's first layout, and the PDF and
    // note paths need it: wait a few frames for it.
    for (var i = 0; i < 20 && (_pageSheet?.isEmpty ?? true); i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final state = ref.read(pageProvider(widget.notebookId));
    if (state.pages.isEmpty) return;
    final page =
        state.pages[state.currentPageIndex.clamp(0, state.pages.length - 1)];
    final key = (notebookId: widget.notebookId, pageId: page.id);

    final images = [for (final f in share.files) if (f.isImage) f.path];
    final pdfs = [for (final f in share.files) if (f.isPdf) f.path];
    final texts = [for (final f in share.files) if (f.isText) f.path];
    final skipped = [
      for (final f in share.files)
        if (!f.isImage && !f.isPdf && !f.isText) f.name
    ];
    try {
      if (images.isNotEmpty) await _importPhotos(key, paths: images);
      for (final pdf in pdfs) {
        if (!mounted) return;
        await _importPdf(given: pdf);
      }
      for (final file in texts) {
        if (!mounted) return;
        await _importTextFile(given: file);
      }
    } on ImportException catch (e) {
      _toast(e.message);
    }
    if (!mounted) return;
    final note = share.noteText;
    final web = share.link;
    // A shared web address is a card that opens it (hand tool, after asking).
    if (note != null) {
      _insertNote(key, note,
          link: web == null ? '' : LinkToWeb(web.toString()).encoded);
    }
    if (skipped.isNotEmpty) {
      _toast('Margo can\'t open ${skipped.join(', ')} yet.');
    }
    // "A note each": on to the next note's share.
    final next = share.next;
    if (next != null && mounted) {
      context.pushReplacement('/note2/${next.notebookId}', extra: next.share);
    }
  }

  /// Offers the import sources. Photos land on the current page, selected and
  /// ready to place (with an "Own page" button for a whiteboard shot to write
  /// over); scans and PDFs become pages of their own.
  Future<void> _showImportSheet(ScenePageKey key) async {
    final choice = await showModalBottomSheet<_ImportSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              subtitle: const Text('Pick one or more'),
              onTap: () => Navigator.of(context).pop(_ImportSource.gallery),
            ),
            // Where the device has a document scanner the camera entry is that:
            // it straightens and cleans the page, and everything that reads the
            // image afterwards works from a better picture.
            ListTile(
              leading: Icon(_import.canScan
                  ? Icons.document_scanner_outlined
                  : Icons.photo_camera_outlined),
              title: Text(_import.canScan ? 'Scan document' : 'Camera'),
              subtitle: _import.canScan
                  ? const Text('Straightens and cleans up the page')
                  : null,
              onTap: () => Navigator.of(context).pop(_ImportSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: const Text('One page per PDF page'),
              onTap: () => Navigator.of(context).pop(_ImportSource.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Text or Markdown file'),
              subtitle: const Text('Becomes typed pages'),
              onTap: () => Navigator.of(context).pop(_ImportSource.text),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      switch (choice) {
        case _ImportSource.gallery:
          await _importPhotos(key);
        case _ImportSource.camera:
          await _importCapture(key);
        case _ImportSource.pdf:
          await _importPdf();
        case _ImportSource.text:
          await _importTextFile();
      }
    } on ImportException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _importPhotos(ScenePageKey key, {List<String>? paths}) async {
    final imported = paths == null
        ? await _import.importPhotos('${widget.notebookId}')
        : await _import.importImageFiles(paths, '${widget.notebookId}');
    if (imported.isEmpty || !mounted) return;

    // More pictures than the AI reads on one page in one go: say so first,
    // and offer a page each.
    final onPage =
        ref.read(sceneControllerProvider(key)).whereType<ImageElement>().length;
    if (imported.length + onPage > kLocalImageReads) {
      final choice = await showDialog<PhotoLimitChoice>(
        context: context,
        builder: (_) => PhotoLimitDialog(
          adding: imported.length,
          onPage: onPage,
          limit: kLocalImageReads,
        ),
      );
      if (!mounted) return;
      switch (choice) {
        case null:
          return;
        case PhotoLimitChoice.ownPages:
          final pageIds = <int>[];
          for (final image in imported) {
            final id = await _addImageOnNewPage(image);
            if (!mounted) return;
            if (id != null) pageIds.add(id);
          }
          _indexPages(pageIds, announce: false);
          return;
        case PhotoLimitChoice.thisPage:
          break;
      }
    }
    _placeOnPage(key, imported);
  }

  /// The camera entry: a document scan where the device has a scanner, a plain
  /// photo where it doesn't. A scan is a page to write over, so it gets a page
  /// of its own (several become a page each, grouped like a PDF so "the whole
  /// scan" can be named as a scope); a plain photo is placed like any photo.
  Future<void> _importCapture(ScenePageKey key) async {
    final scanned = _import.canScan;
    final captured = await _import.importCapture('${widget.notebookId}');
    if (captured.isEmpty || !mounted) return;
    if (captured.length > 1) {
      await _addImportedPages(captured,
          sourceName: SceneImportService.scanSourceName(DateTime.now()));
    } else if (scanned) {
      final pageId = await _addImageOnNewPage(captured.single);
      if (pageId != null) _indexPages([pageId], announce: false);
    } else {
      _placeOnPage(key, captured);
    }
  }

  /// Imports the PDF at [given], or one the user picks.
  Future<void> _importPdf({String? given}) async {
    final picked = given ?? await _import.pickPdfPath();
    if (picked == null || !mounted) return;
    var path = picked;
    // Every page needs a sheet to be fitted to, so fail up front rather than
    // rendering the whole document and silently dropping each page.
    if (_pageSheet == null || _pageSheet!.isEmpty) {
      _toast('The page is still loading — try again in a moment.');
      return;
    }

    int count;
    try {
      count = await _import.pdfPageCount(path);
    } on PdfLockedException {
      if (!mounted) return;
      final locked = path;
      final unlocked = await showDialog<String>(
        context: context,
        builder: (_) => PdfPasswordDialog(
          fileName: SceneImportService.importSourceNameOf(locked),
          unlock: (password) => _import.unlockPdf(locked, password),
        ),
      );
      if (unlocked == null || !mounted) return;
      path = unlocked;
      count = await _import.pdfPageCount(path);
    }
    if (!mounted) return;
    if (count < 1) {
      _toast('That PDF had no pages to import.');
      return;
    }
    final options = await showModalBottomSheet<PdfImportOptions>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PdfImportSheet(
        fileName: SceneImportService.importSourceNameOf(path),
        pageCount: count,
      ),
    );
    if (options == null || !mounted) return;

    var cancelled = false;
    final progress =
        ValueNotifier<(int, int)>((0, options.last - options.first + 1));
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(
        progress: progress,
        onCancel: () => cancelled = true,
      ),
    );
    // Disposed once the dialog has fully gone, not while it animates out.
    unawaited(dialog.whenComplete(progress.dispose));

    final List<ImportedImage> pages;
    try {
      pages = await _import.importPdf(
        path,
        '${widget.notebookId}',
        firstPage: options.first,
        lastPage: options.last,
        onProgress: (done, total) => progress.value = (done, total),
        isCancelled: () => cancelled,
      );
    } on ImportCancelledException {
      if (mounted) _toast('Import cancelled.');
      return;
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
    if (!mounted) return;
    if (pages.isEmpty) {
      _toast('That PDF had no pages to import.');
      return;
    }

    await _addImportedPages(pages,
        sourceName: SceneImportService.importSourceNameOf(path),
        afterCurrent: options.afterCurrent,
        readNow: options.readText);
  }

  /// Imports a text or Markdown file — the one at [given], or one the user
  /// picks — as typed text pages, grouped like a PDF so it can be named as a
  /// scope.
  Future<void> _importTextFile({String? given}) async {
    final path = given ?? await _import.pickTextPath();
    if (path == null || !mounted) return;
    final sheet = _pageSheet;
    if (sheet == null || sheet.isEmpty) {
      _toast('The page is still loading — try again in a moment.');
      return;
    }
    final text = await _import.readTextFile(path);
    if (!mounted) return;

    const margin = 56.0;
    final width = sheet.width - 2 * margin;
    TextElement typed(String t, int zOrder) => TextElement(
          id: '${DateTime.now().microsecondsSinceEpoch}_tx${_noteSeq++}',
          zOrder: zOrder,
          geometryData: [margin, margin, sheet.width - margin, sheet.height - margin],
          text: t,
          color: 0xFF1A1A1A,
        );
    final chunks = paginateText(text, sheet.height - 2 * margin,
        (t) => SceneElementPainter.layOutText(typed(t, 0), width).height);
    if (chunks.isEmpty) {
      _toast('That file had no text to import.');
      return;
    }
    await _addPagesAsImport(
        chunks.length, (i) => _addOnNewPage((_, z) => typed(chunks[i], z)),
        sourceName: SceneImportService.importSourceNameOf(path));
  }

  /// Adds one page per image of a multi-page import (a PDF, a scan) — right
  /// after the page the user was on when [afterCurrent], else at the end — and
  /// starts reading the whole document for search.
  ///
  /// With [readNow] off the pages are only imported: each is read when it is
  /// opened with the AI panel, or by "Index all pages".
  Future<void> _addImportedPages(List<ImportedImage> pages,
          {required String sourceName,
          bool afterCurrent = true,
          bool readNow = true}) =>
      _addPagesAsImport(pages.length, (i) => _addImageOnNewPage(pages[i]),
          sourceName: sourceName, afterCurrent: afterCurrent, readNow: readNow);

  /// [_addImportedPages] for any page: [count] pages, each made by [addPage].
  Future<void> _addPagesAsImport(int count, Future<int?> Function(int i) addPage,
      {required String sourceName,
      bool afterCurrent = true,
      bool readNow = true}) async {
    final startedOn =
        ref.read(pageProvider(widget.notebookId)).currentPageIndex;
    // One id for the whole document, stamped on every page it becomes. This is
    // what later lets "the whole PDF" be a scope the AI features can name —
    // without it, a 40-page import is just 40 loose pages (see
    // features/ai/domain/ai_scope.dart).
    final groupId = SceneImportService.newImportGroupId();
    final repository = ref.read(pageRepositoryProvider);
    final createdPageIds = <int>[];

    for (var i = 0; i < count; i++) {
      final pageId = await addPage(i);
      if (!mounted) return;
      if (pageId == null) continue;
      await repository.tagImport(
        pageId,
        importGroupId: groupId,
        importSourceName: sourceName,
      );
      createdPageIds.add(pageId);
      if (!mounted) return;
    }
    if (afterCurrent) {
      await ref
          .read(pageProvider(widget.notebookId).notifier)
          .movePagesAfter(createdPageIds, afterIndex: startedOn);
      if (!mounted) return;
    }
    _toast('Imported $count page${count == 1 ? '' : 's'}.');

    // Read and embed the whole document NOW, rather than waiting for the user
    // to open each page. The live RagIndexScheduler is driven by the Context
    // Engine's per-page edit hook, so a page nobody opens is never indexed —
    // which used to make an imported PDF invisible to "Ask your notes" beyond
    // whichever single page happened to be on screen.
    if (readNow) _indexPages(createdPageIds, announce: false);
  }

  /// Kicks off a background bulk index of [pageIds] and reports the outcome.
  ///
  /// Fire-and-forget: reading 40 pages with the vision model takes far longer
  /// than anyone will hold an import dialog open for, and a page that fails to
  /// index costs only its own searchability. [announce] is off for the
  /// automatic post-import run (the import toast already fired) and on for the
  /// explicit "Index all pages" action, where silence would look like nothing
  /// happened.
  void _indexPages(List<int> pageIds, {required bool announce}) {
    if (pageIds.isEmpty) return;
    final notifier =
        ref.read(notebookIndexProvider(widget.notebookId).notifier);
    if (notifier.isRunning) {
      if (announce) _toast('Already indexing…');
      return;
    }
    if (announce) {
      _toast('Reading ${pageIds.length} page'
          '${pageIds.length == 1 ? '' : 's'} for search…');
    }
    unawaited(notifier.run(notebookId: widget.notebookId, pageIds: pageIds).then(
      (report) {
        if (!mounted || report == null) return;
        // The automatic run stays quiet unless something actually needs saying.
        if (!announce && report.isComplete && report.indexed == 0) return;
        _toast(NotebookIndexDone(report).message);
      },
    ));
  }

  /// Re-reads and embeds every page of the notebook — the retroactive path for
  /// notebooks imported before eager indexing existed, whose pages would
  /// otherwise stay permanently unsearchable.
  Future<void> _indexWholeNotebook() async {
    final pages = await ref
        .read(pageRepositoryProvider)
        .getPagesForNotebook(widget.notebookId);
    if (!mounted) return;
    _indexPages([for (final p in pages) p.id], announce: true);
  }

  /// Adds [images] to the current page and starts placing them: they arrive
  /// selected, on the Select tool, so the next drag moves them and a corner
  /// resizes them, with the placement bar offering Done / Own page / Remove.
  /// The tool the user had comes back when they finish (see [_endPlacement]).
  ///
  /// Each lands where [placeImageInView] puts it — in a clear part of what is on
  /// screen, never on top of writing when there is room — and several are kept
  /// clear of one another.
  void _placeOnPage(ScenePageKey key, List<ImportedImage> images) {
    final viewport = ref.read(viewportProvider);
    final canvasSize = ref.read(viewportProvider.notifier).viewportSize;
    if (canvasSize.isEmpty) return; // canvas hasn't laid out yet

    final sheet = _pageSheet;
    final page =
        _pageMode && sheet != null && !sheet.isEmpty ? Offset.zero & sheet : null;
    final visible = viewport.visibleSceneRect(canvasSize);
    final existing = <Rect>[
      for (final e in ref.read(sceneControllerProvider(key)))
        if (!(e is FreehandElement && e.isEraser) && !e.isLocked)
          ElementBounds.of(e),
    ]..removeWhere((r) => r.isEmpty);

    final scene = ref.read(sceneControllerProvider(key).notifier);
    var zOrder = scene.nextZOrder();
    final added = <ImageElement>[];
    for (final image in images) {
      final box = placeImageInView(
        source: image.pixelSize,
        visible: visible,
        page: page,
        existing: existing,
      );
      if (box.isEmpty) continue;
      existing.add(box);
      // Inline images are content the user will want to move and resize.
      added.add(_imageElement(image, box, zOrder++, locked: false));
    }
    if (added.isEmpty) {
      _toast("That image couldn't be measured.");
      return;
    }

    ref.read(historyProvider(key).notifier).push(AddElementsCommand(added));
    final toolCtl = ref.read(editorToolProvider.notifier);
    final previous = ref.read(editorToolProvider).tool;
    toolCtl.useTool(EditorTool.select);
    setState(() => _placing = (
          key: key,
          ids: {for (final e in added) e.id},
          images: [
            for (final image in images)
              if (added.any((e) => e.relativeImagePath == image.relativePath))
                image,
          ],
          previousTool: previous,
        ));
    ref.read(selectionProvider.notifier).selectMany(_placing!.ids);
  }

  /// Ends placing: called when the pictures stop being selected (a tap
  /// elsewhere, Done, a page turn) or the user picks another tool. Puts back
  /// the tool they had before, unless they have already chosen a new one.
  void _endPlacement() {
    final placing = _placing;
    if (placing == null) return;
    setState(() => _placing = null);
    if (ref.read(editorToolProvider).tool == EditorTool.select) {
      ref.read(editorToolProvider.notifier).useTool(placing.previousTool);
    }
  }

  /// Takes the pictures being placed back off the page (undoable).
  void _removePlaced() {
    final placing = _placing;
    if (placing == null) return;
    final current = [
      for (final e in ref.read(sceneControllerProvider(placing.key)))
        if (placing.ids.contains(e.id)) e,
    ];
    if (current.isNotEmpty) {
      ref
          .read(historyProvider(placing.key).notifier)
          .push(RemoveElementsCommand(current));
    }
    ref.read(selectionProvider.notifier).clear();
    _endPlacement();
  }

  /// Moves the pictures being placed onto pages of their own, one each.
  Future<void> _placedToOwnPages() async {
    final placing = _placing;
    if (placing == null) return;
    _removePlaced();
    final pageIds = <int>[];
    for (final image in placing.images) {
      final id = await _addImageOnNewPage(image);
      if (!mounted) return;
      if (id != null) pageIds.add(id);
    }
    _indexPages(pageIds, announce: false);
  }

  /// Appends a page and fills it with [imported], aspect-fitted to the sheet.
  /// Returns the new page's id (null when no page could be made), so the PDF
  /// import can tag it with its import group.
  ///
  /// The new page is claimed and loaded before anything is added to it: a
  /// freshly built page triggers [_ensureLoaded], and [SceneController.load]
  /// *replaces* the scene with whatever the store holds — so adding first and
  /// loading second would discard the image.
  Future<int?> _addImageOnNewPage(ImportedImage imported) =>
      _addOnNewPage((sheet, zOrder) {
        // A size we couldn't measure fills the sheet rather than failing.
        final source = imported.pixelSize.isEmpty ? sheet : imported.pixelSize;
        final box = fitCentred(source, Offset.zero & sheet);
        if (box.isEmpty) return null;
        // Locked: a page-sized import is the paper, not something on it.
        // Unlocked, the Select tool grabbed it from under the ink written
        // over it, so annotations could not be selected and the page slid
        // away. It is still selected by a tap (for Unlock / Extract text);
        // Unlock from the selection bar to move or resize it.
        return _imageElement(imported, box, zOrder, locked: true);
      });

  /// Appends a page holding the element [make] builds for the page's [sheet];
  /// returns the page's id, or null when no page could be made (or [make]
  /// gave nothing). See [_addImageOnNewPage] for why it loads first.
  Future<int?> _addOnNewPage(
      SceneElement? Function(Size sheet, int zOrder) make) async {
    final sheet = _pageSheet;
    if (sheet == null || sheet.isEmpty) return null;

    await ref.read(pageProvider(widget.notebookId).notifier).insertPage();
    if (!mounted) return null;

    final pages = ref.read(pageProvider(widget.notebookId)).pages;
    if (pages.isEmpty) return null;
    final key = (notebookId: widget.notebookId, pageId: pages.last.id);

    _loadedPages.add(key.pageId);
    await ref.read(sceneControllerProvider(key).notifier).load();
    if (!mounted) return null;

    final element = make(
        sheet, ref.read(sceneControllerProvider(key).notifier).nextZOrder());
    if (element == null) return null;
    ref.read(historyProvider(key).notifier).push(AddElementsCommand([element]));
    // The image is only in the page once its write has landed; the caller
    // reports the import as done after this returns.
    await SceneController.flushPage(key.pageId);
    return key.pageId;
  }

  ImageElement _imageElement(
    ImportedImage imported,
    Rect box,
    int zOrder, {
    required bool locked,
  }) =>
      ImageElement(
        id: '${DateTime.now().microsecondsSinceEpoch}_im${_noteSeq++}',
        zOrder: zOrder,
        geometryData: [box.left, box.top, box.right, box.bottom],
        relativeImagePath: imported.relativePath,
        sourceDescription: imported.description,
        isLocked: locked,
      );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Kicks off summarization at [choice]'s scope and shows the summary sheet.
  ///
  /// Page content is read through the AI platform's PageContentExtractor
  /// against the unified scene store — written through on every editor
  /// mutation, so no page, including the one on screen, needs special-casing.
  /// The scope is resolved fresh on every attempt so a notebook retry sees the
  /// latest pages; the selection is captured now (a retry summarizes the same
  /// items even if the user has since deselected them).
  void _summarizeScope(ScenePageKey key, SummarizeScopeChoice choice) {
    final settings = ref.read(settingsProvider);
    final pages = ref.read(pageRepositoryProvider);
    final selection = ref.read(selectionProvider);

    // Page sets come from the shared resolver, so "this PDF" and "the whole
    // notebook" mean exactly what they mean on the Ask surface. "This page"
    // stays hard-wired to the page on screen rather than going through the
    // resolver — there is nothing to resolve, and it must never pull a
    // neighbour in.
    final resolver = ref.read(aiScopeResolverProvider);

    Future<SummarizeScope> resolveScope() async {
      switch (choice) {
        case SummarizeScopeChoice.selection:
          return SelectionScope(pageId: key.pageId, elementIds: selection);
        case SummarizeScopeChoice.page:
          return PageScope(key.pageId);
        case SummarizeScopeChoice.importGroup:
          final scope = await resolver.resolve(
            kind: AiScopeKind.importGroup,
            notebookId: widget.notebookId,
            pageId: key.pageId,
          );
          // A page with no import group resolves back to itself — summarizing
          // "the whole PDF" of a hand-written page is the one page it is on.
          final groupId = scope.importGroupId;
          return groupId == null
              ? PageScope(key.pageId)
              : ImportGroupScope(scope.pageIds, importGroupId: groupId);
        case SummarizeScopeChoice.notebook:
          return NotebookScope([
            for (final page
                in await pages.getPagesForNotebook(widget.notebookId))
              page.id,
          ]);
      }
    }

    ref.read(summarizeNotifierProvider.notifier).run(SummarizeRequest(
          notebookId: widget.notebookId,
          resolveScope: resolveScope,
          languageCode: settings.recognitionLanguage,
          cloudEnabled: settings.cloudAiEnabled,
          preferCloud: settings.prefersCloud,
        ));
    showSummarySheet(context);
  }

  Future<void> _showBackgroundSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _BackgroundSheet(
        template: _template,
        notebookTemplate: _notebookTemplate,
        pageOnly: _pageHasOwnTemplate,
        paperColor: _paperColor,
        layoutMode: _layoutMode,
        pageSize: _pageKind,
        onTemplate: _setTemplate,
        onColor: _setPaperColor,
        onLayoutMode: _setLayoutMode,
        onPageSize: _setPageSize,
      ),
    );
  }

  void _setLayoutMode(int mode) {
    final nb = _notebook;
    if (nb == null) return;
    setState(() => nb.layoutMode = mode);
    unawaited(_save((r) => r.updateLayoutMode(widget.notebookId, mode)));
  }

  /// The paper the pages are laid out on. Writing stays where it is; only the
  /// page around it changes.
  void _setPageSize(PageSizeKind kind) {
    final nb = _notebook;
    if (nb == null) return;
    setState(() => nb.pageSize = kind.index);
    unawaited(_save((r) => r.updatePageSize(widget.notebookId, kind.index)));
  }

  bool get _pageHasOwnTemplate {
    final state = ref.read(pageProvider(widget.notebookId));
    if (state.pages.isEmpty) return false;
    final i = state.currentPageIndex.clamp(0, state.pages.length - 1);
    return state.pages[i].templateOverride >= 0;
  }

  /// [pageOnly] gives the current page its own paper; otherwise the notebook's
  /// paper changes and the page goes back to following it.
  void _setTemplate(TemplateType type, bool pageOnly) {
    final nb = _notebook;
    if (nb == null) return;
    final notifier = ref.read(pageProvider(widget.notebookId).notifier);
    final state = ref.read(pageProvider(widget.notebookId));
    final page = state.pages.isEmpty
        ? null
        : state.pages[
            state.currentPageIndex.clamp(0, state.pages.length - 1)];
    if (pageOnly) {
      if (page != null) unawaited(notifier.setPageTemplate(page.id, type.index));
      return;
    }
    if (page != null && page.templateOverride >= 0) {
      unawaited(notifier.setPageTemplate(page.id, kNotebookTemplate));
    }
    setState(() => nb.templateIndex = type.index);
    unawaited(
        _save((r) => r.updateTemplateIndex(widget.notebookId, type.index)));
  }

  void _setPaperColor(Color color) {
    final nb = _notebook;
    if (nb == null) return;
    final argb = color.toARGB32();
    setState(() => nb.backgroundColor = argb);
    unawaited(_save((r) => r.updateBackgroundColor(widget.notebookId, argb)));
  }

  /// Persists a renamed note, reflecting it in the app bar immediately.
  void _rename(String title) {
    final nb = _notebook;
    if (nb == null) return;
    setState(() => nb.title = title);
    unawaited(_save((r) => r.updateTitle(widget.notebookId, title)));
  }

  /// Writes a notebook setting the screen already shows, then refreshes the
  /// home list, which holds its own copies. A failed write reloads the notebook
  /// so the screen never shows a value that was not saved.
  Future<void> _save(Future<void> Function(NoteRepository repo) write) async {
    final repo = ref.read(noteRepositoryProvider);
    // Read before the await: the user may leave the editor mid-write.
    final home = ref.read(homeNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await write(repo);
    } catch (e) {
      debugPrint('Notebook save failed: $e');
      final nb = await repo.getNotebook(widget.notebookId);
      if (mounted) setState(() => _notebook = nb);
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't save that change.")));
      return;
    }
    await home.loadNotebooks();
  }
}
