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

import '../../core/constants/app_colors.dart';
import '../../core/providers/settings_provider.dart';
import '../../domain/commands/scene_command.dart';
import '../../domain/model/scene_element.dart';
import '../../features/ai/presentation/sidebar/ai_sidebar.dart';
import '../../features/editor/domain/models/template_type.dart';
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

  /// Disambiguates ids of AI-inserted notes created in the same microsecond.
  int _noteSeq = 0;

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
            child: Stack(
              children: [
                Positioned.fill(
                  child: SceneCanvas(
                    key: ValueKey(page.id),
                    notebookId: widget.notebookId,
                    pageId: page.id,
                    backgroundColor: _paperColor,
                    templateType: _template,
                    pageMode: _pageMode,
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
            ),
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
  /// visible viewport.
  void _insertNote(ScenePageKey key, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    const width = 360.0;
    const fontSize = 16.0;
    final painter = TextPainter(
      text: const TextSpan(text: 'x', style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    );
    painter.text =
        TextSpan(text: trimmed, style: const TextStyle(fontSize: fontSize));
    painter.layout(maxWidth: width);
    final height = painter.height + 16;

    final scene = ref.read(viewportProvider).toScene(const Offset(48, 120));
    final zOrder = ref.read(sceneControllerProvider(key).notifier).nextZOrder();

    ref.read(historyProvider(key).notifier).push(AddElementsCommand([
          TextElement(
            id: '${DateTime.now().microsecondsSinceEpoch}_ai${_noteSeq++}',
            zOrder: zOrder,
            geometryData: [
              scene.dx,
              scene.dy,
              scene.dx + width,
              scene.dy + height,
            ],
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
