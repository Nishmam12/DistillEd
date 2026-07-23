// The real notebook editor on the unified engine (Canvas 2.0). Opens a notebook
// by id, drives page navigation through the existing [pageProvider], and binds
// the unified [SceneCanvas] to the real Isar-backed scene store (so edits load
// and autosave through [SceneElementRecord]). Paper colour + template come from
// the [Notebook]. All chrome is shared with the dev playground.
//
// Reachable from Home when "Canvas 2.0" is enabled in Settings; the legacy
// editor stays intact and is removed only in a later, separately-approved phase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/settings_provider.dart';
import '../../domain/commands/scene_command.dart';
import '../../domain/geometry/element_bounds.dart';
import '../../domain/model/scene_element.dart';
import '../../features/ai/presentation/sidebar/ai_sidebar.dart';
import '../../features/editor/domain/models/template_type.dart';
import '../../features/import/pdf_service.dart' show ImportException;
import '../import/fit_image_rect.dart';
import '../import/scene_import_service.dart';
import '../../features/editor/presentation/page_notifier.dart';
import '../../features/home/data/repositories/note_repository.dart';
import '../../features/home/domain/models/notebook.dart';
import '../../features/summarize/presentation/summarize_notifier.dart';
import '../../features/summarize/presentation/widgets/summary_bottom_sheet.dart';
import '../../shared/isar/isar_service.dart';
import '../state/history_controller.dart';
import '../state/library_controller.dart';
import '../state/scene_controller.dart';
import '../state/selection_controller.dart';
import '../state/viewport_controller.dart';
import 'editor_controls.dart';
import 'scene_canvas.dart';

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

/// What the user picked from the import sheet.
enum _ImportSource { gallery, camera, pdf }

class NotebookEditorScreen extends ConsumerStatefulWidget {
  final int notebookId;
  const NotebookEditorScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookEditorScreen> createState() =>
      _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends ConsumerState<NotebookEditorScreen> {
  final Set<int> _loadedPages = {};
  Notebook? _notebook;

  /// Whether the docked AI panel is showing (wide screens only; on phones the
  /// AI action opens a bottom sheet instead and this stays false).
  bool _aiPanelOpen = false;

  /// The page's size in page mode, taken from the first layout of the canvas
  /// area and held for the rest of the session. See the [LayoutBuilder] in
  /// [build] for why it cannot live in the canvas.
  Size? _pageSheet;

  /// Disambiguates ids of AI-inserted notes and imported images created in the
  /// same microsecond.
  int _noteSeq = 0;

  final SceneImportService _import = SceneImportService();

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    await ref.read(pageProvider(widget.notebookId).notifier).initialize();
    final nb = await IsarService.instance.notebooks.get(widget.notebookId);
    await ref.read(libraryProvider.notifier).load();
    if (mounted) setState(() => _notebook = nb);
  }

  Color get _paperColor => Color(_notebook?.backgroundColor ?? 0xFFFFFDF7);

  TemplateType get _template {
    final i = _notebook?.templateIndex ?? 0;
    return (i >= 0 && i < TemplateType.values.length)
        ? TemplateType.values[i]
        : TemplateType.blank;
  }

  bool get _pageMode => (_notebook?.layoutMode ?? 0) == 1;

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
    final zoom = ref.watch(viewportProvider.select((v) => v.zoom));

    if (pageState.pages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final index =
        pageState.currentPageIndex.clamp(0, pageState.pages.length - 1);
    final page = pageState.pages[index];
    final key = (notebookId: widget.notebookId, pageId: page.id);
    _ensureLoaded(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(_notebook?.title ?? 'Notebook'),
        actions: [
          IconButton(
            tooltip: 'Background & paper',
            icon: const Icon(Icons.wallpaper_outlined),
            onPressed: _notebook == null ? null : _showBackgroundSheet,
          ),
          IconButton(
            tooltip: 'Import',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () => _showImportSheet(key),
          ),
          IconButton(
            tooltip: 'Summarize',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () =>
                _summarizeScope(key, SummarizeScopeChoice.notebook),
          ),
          IconButton(
            tooltip: 'AI insights',
            isSelected: _aiPanelOpen,
            icon: const Icon(Icons.psychology_outlined),
            selectedIcon: const Icon(Icons.psychology),
            onPressed: () => _toggleAiPanel(key),
          ),
          IconButton(
            tooltip: 'Study plan',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push('/note2/${widget.notebookId}/plan'),
          ),
          IconButton(
            tooltip: 'Knowledge graph',
            icon: const Icon(Icons.hub_outlined),
            onPressed: () => context.push('/note2/${widget.notebookId}/graph'),
          ),
          IconButton(
            tooltip: 'Book view',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/note2/${widget.notebookId}/book'),
          ),
          Center(child: Text('${(zoom * 100).round()}%')),
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => ref.read(viewportProvider.notifier).reset(),
          ),
          EditorAppBarActions(
            pageKey: key,
            onChangeBackground: _notebook == null ? null : _showBackgroundSheet,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              // The page's size is latched here rather than inside the canvas,
              // because the canvas is keyed by page id and so is rebuilt from
              // scratch on every page turn — a latch living there would re-take
              // its size from whatever the canvas had shrunk to, and switching
              // pages with the AI panel open would leave the new page a narrow
              // sliver. This state outlives both.
              if (!constraints.biggest.isEmpty) {
                _pageSheet ??= constraints.biggest;
              }
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
                      pageSize: _pageSheet,
                    ),
                  ),
                  // Quick-access tool bar overlaid at the top with a translucent
                  // background, freeing the bottom for page navigation.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: EditorBottomBar(pageKey: key, floating: true),
                  ),
                ],
              );
            }),
          ),
          // Docked AI panel beside the canvas on wide screens; phones use the
          // bottom sheet from _toggleAiPanel instead.
          if (_aiPanelOpen &&
              MediaQuery.of(context).size.width >= kAiSidebarBreakpoint)
            AiSidebar(
              pageKey: key,
              onClose: () => setState(() => _aiPanelOpen = false),
              onSummarize: (choice) => _summarizeScope(key, choice),
              onInsertNote: (text) => _insertNote(key, text),
              // Docked beside the canvas: jumping just switches the page behind
              // the panel, which stays open.
              onJumpToSource: _jumpToSource,
            ),
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
      ),
    );
  }

  void _switchTo(int i) {
    ref.read(selectionProvider.notifier).clear();
    ref.read(pageProvider(widget.notebookId).notifier).switchPage(i);
  }

  /// Toggles the live AI insights surface. Wide screens dock it beside the
  /// canvas; phone-width screens open it as a bottom sheet so it never crowds
  /// the drawing area.
  void _toggleAiPanel(ScenePageKey key) {
    final wide = MediaQuery.of(context).size.width >= kAiSidebarBreakpoint;
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
  void _insertNote(ScenePageKey key, String text) {
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
          ),
        ]));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Added to the page'),
      duration: Duration(seconds: 1),
    ));
  }

  // ---- import ---------------------------------------------------------------

  /// Offers the import sources. PDFs always become new pages (one per PDF
  /// page); a photo asks, since either answer is reasonable — a diagram
  /// alongside your notes, or a whiteboard shot to annotate on its own sheet.
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
              onTap: () => Navigator.of(context).pop(_ImportSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(_ImportSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: const Text('One page per PDF page'),
              onTap: () => Navigator.of(context).pop(_ImportSource.pdf),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      switch (choice) {
        case _ImportSource.gallery:
          await _importPhoto(key, ImageSource.gallery);
        case _ImportSource.camera:
          await _importPhoto(key, ImageSource.camera);
        case _ImportSource.pdf:
          await _importPdf();
      }
    } on ImportException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _importPhoto(ScenePageKey key, ImageSource source) async {
    final imported = await _import.importPhoto(source, '${widget.notebookId}');
    if (imported == null || !mounted) return;

    final asPage = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Where should it go?'),
        content: const Text(
            'Add it to the page you are on, or give it a page of its own?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('This page'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('New page'),
          ),
        ],
      ),
    );
    if (asPage == null || !mounted) return;

    if (asPage) {
      await _addImageOnNewPage(imported);
    } else {
      _addImageInline(key, imported);
    }
  }

  Future<void> _importPdf() async {
    final path = await _import.pickPdfPath();
    if (path == null || !mounted) return;
    // Every page needs a sheet to be fitted to, so fail up front rather than
    // rendering the whole document and silently dropping each page.
    if (_pageSheet == null || _pageSheet!.isEmpty) {
      _toast('The page is still loading — try again in a moment.');
      return;
    }

    _toast('Importing…');
    final pages = await _import.importPdf(path, '${widget.notebookId}');
    if (!mounted) return;
    if (pages.isEmpty) {
      _toast('That PDF had no pages to import.');
      return;
    }

    for (final page in pages) {
      await _addImageOnNewPage(page);
      if (!mounted) return;
    }
    _toast('Imported ${pages.length} page${pages.length == 1 ? '' : 's'}.');
  }

  /// Drops [imported] onto the current page, sized against what's on screen and
  /// placed in the first clear slot — the same rules an inserted AI note uses.
  void _addImageInline(ScenePageKey key, ImportedImage imported) {
    final viewport = ref.read(viewportProvider);
    final canvasSize = ref.read(viewportProvider.notifier).viewportSize;
    if (canvasSize.isEmpty) return; // canvas hasn't laid out yet
    final visible = viewport.visibleSceneRect(canvasSize);

    // Sized in scene units against the visible area, so a photo occupies the
    // same share of the screen whatever the zoom.
    final size = inlineSize(imported.pixelSize, visible.size);
    if (size.isEmpty) {
      _toast("That image couldn't be measured.");
      return;
    }

    final existing = <Rect>[];
    for (final e in ref.read(sceneControllerProvider(key))) {
      if (e is FreehandElement && e.isEraser) continue;
      final r = ElementBounds.of(e);
      if (!r.isEmpty) existing.add(r);
    }

    final box = placeNoteSlot(
      bounds: visible,
      width: size.width,
      height: size.height,
      existing: existing,
    );
    if (box == null) {
      _toast('No empty space in view — scroll or zoom out to make room.');
      return;
    }

    ref.read(historyProvider(key).notifier).push(AddElementsCommand([
          _imageElement(
            imported,
            box,
            ref.read(sceneControllerProvider(key).notifier).nextZOrder(),
            // Inline images are content the user will want to move and resize.
            locked: false,
          ),
        ]));
    _toast('Added to the page');
  }

  /// Appends a page and fills it with [imported], aspect-fitted to the sheet.
  ///
  /// The new page is claimed and loaded before anything is added to it: a
  /// freshly built page triggers [_ensureLoaded], and [SceneController.load]
  /// *replaces* the scene with whatever the store holds — so adding first and
  /// loading second would discard the image.
  Future<void> _addImageOnNewPage(ImportedImage imported) async {
    final sheet = _pageSheet;
    if (sheet == null || sheet.isEmpty) return;

    await ref.read(pageProvider(widget.notebookId).notifier).insertPage();
    if (!mounted) return;

    final pages = ref.read(pageProvider(widget.notebookId)).pages;
    if (pages.isEmpty) return;
    final key = (notebookId: widget.notebookId, pageId: pages.last.id);

    _loadedPages.add(key.pageId);
    await ref.read(sceneControllerProvider(key).notifier).load();
    if (!mounted) return;

    // A size we couldn't measure fills the sheet rather than failing the import.
    final source =
        imported.pixelSize.isEmpty ? sheet : imported.pixelSize;
    final box = fitCentred(source, Offset.zero & sheet);
    if (box.isEmpty) return;

    ref.read(historyProvider(key).notifier).push(AddElementsCommand([
          _imageElement(
            imported,
            box,
            ref.read(sceneControllerProvider(key).notifier).nextZOrder(),
            // Imported unlocked, so it can be moved and resized straight away —
            // that turned out to matter more than protecting a backdrop from a
            // stray drag. Users who want it pinned can Lock it from the
            // selection bar; annotating with the pen never moves it regardless.
            locked: false,
          ),
        ]));
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

    Future<SummarizeScope> resolveScope() async {
      switch (choice) {
        case SummarizeScopeChoice.selection:
          return SelectionScope(pageId: key.pageId, elementIds: selection);
        case SummarizeScopeChoice.page:
          return PageScope(key.pageId);
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
        ));
    showSummarySheet(context);
  }

  Future<void> _showBackgroundSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _BackgroundSheet(
        template: _template,
        paperColor: _paperColor,
        pageMode: _pageMode,
        onTemplate: _setTemplate,
        onColor: _setPaperColor,
        onPageMode: _setLayoutMode,
      ),
    );
  }

  void _setLayoutMode(bool pageMode) {
    final nb = _notebook;
    if (nb == null) return;
    final mode = pageMode ? 1 : 0;
    setState(() => nb.layoutMode = mode);
    NoteRepository(IsarService.instance)
        .updateLayoutMode(widget.notebookId, mode);
  }

  void _setTemplate(TemplateType type) {
    final nb = _notebook;
    if (nb == null) return;
    setState(() => nb.templateIndex = type.index);
    NoteRepository(IsarService.instance)
        .updateTemplateIndex(widget.notebookId, type.index);
  }

  void _setPaperColor(Color color) {
    final nb = _notebook;
    if (nb == null) return;
    final argb = color.toARGB32();
    setState(() => nb.backgroundColor = argb);
    NoteRepository(IsarService.instance)
        .updateBackgroundColor(widget.notebookId, argb);
  }
}

/// Bottom sheet to pick the page template and paper colour. Selections apply
/// live (the parent persists them and rebuilds the canvas) so the sheet can
/// stay open while the user tries combinations.
class _BackgroundSheet extends StatefulWidget {
  final TemplateType template;
  final Color paperColor;
  final bool pageMode;
  final ValueChanged<TemplateType> onTemplate;
  final ValueChanged<Color> onColor;
  final ValueChanged<bool> onPageMode;

  const _BackgroundSheet({
    required this.template,
    required this.paperColor,
    required this.pageMode,
    required this.onTemplate,
    required this.onColor,
    required this.onPageMode,
  });

  @override
  State<_BackgroundSheet> createState() => _BackgroundSheetState();
}

class _BackgroundSheetState extends State<_BackgroundSheet> {
  static const _papers = <Color>[
    AppColors.paperWhite,
    AppColors.paperCream,
    AppColors.paperBlush,
  ];

  late TemplateType _template = widget.template;
  late Color _color = widget.paperColor;
  late bool _pageMode = widget.pageMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Layout', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.all_out),
                  label: Text('Infinite'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.insert_drive_file_outlined),
                  label: Text('Single page'),
                ),
              ],
              selected: {_pageMode},
              onSelectionChanged: (s) {
                setState(() => _pageMode = s.first);
                widget.onPageMode(s.first);
              },
            ),
            const SizedBox(height: 20),
            Text('Paper template', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in TemplateType.values)
                  ChoiceChip(
                    avatar: Icon(t.iconData, size: 18),
                    label: Text(t.displayName),
                    selected: _template == t,
                    onSelected: (_) {
                      setState(() => _template = t);
                      widget.onTemplate(t);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Paper color', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final c in _papers)
                  GestureDetector(
                    onTap: () {
                      setState(() => _color = c);
                      widget.onColor(c);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color.toARGB32() == c.toARGB32()
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          width: _color.toARGB32() == c.toARGB32() ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageNavBar extends StatelessWidget {
  final int index;
  final int count;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onAdd;

  const _PageNavBar({
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
            ),
            Text('Page ${index + 1} / $count'),
            IconButton(
              tooltip: 'Next page',
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add page',
              icon: const Icon(Icons.add),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
