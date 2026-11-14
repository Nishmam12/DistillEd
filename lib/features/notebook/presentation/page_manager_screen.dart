// The page manager: every page of a notebook as a grid of thumbnails. Long-press
// a page and drag it to reorder; "Select" turns taps into a multi-select with
// duplicate, move and delete for the whole set. Tapping a page (outside select
// mode) opens it in the editor.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/model/page_size.dart';
import '../../../domain/model/scene_element.dart';
import '../../../editor/render/scene_image_cache.dart';
import '../../../editor/state/page_notifier.dart';
import '../../../editor/state/scene_controller.dart';
import '../../../editor/state/scene_image_cache_provider.dart';
import '../../home/presentation/home_notifier.dart';
import 'page_thumbnail.dart';

class PageManagerScreen extends ConsumerStatefulWidget {
  final int notebookId;
  const PageManagerScreen({super.key, required this.notebookId});

  @override
  ConsumerState<PageManagerScreen> createState() => _PageManagerScreenState();
}

class _PageManagerScreenState extends ConsumerState<PageManagerScreen> {
  final Map<int, List<SceneElement>> _byPage = {};
  late final SceneImageCache _imageCache;
  Color _paper = const Color(0xFFFFFDF7);
  double _aspect = 1 / 1.414;
  bool _selecting = false;
  final Set<int> _selected = {};
  bool _loading = true;

  PageNotifier get _pages =>
      ref.read(pageProvider(widget.notebookId).notifier);

  @override
  void initState() {
    super.initState();
    _imageCache = ref.read(sceneImageCacheProvider);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await _pages.initialize();
    final nb =
        await ref.read(noteRepositoryProvider).getNotebook(widget.notebookId);
    if (!mounted) return;
    _paper = Color(nb?.backgroundColor ?? 0xFFFFFDF7);
    _aspect = pageAspectOf(PageSizeKind.fromIndex(nb?.pageSize ?? 0));
    await _loadContent();
  }

  /// Reads the scene of any page not loaded yet. Copies get new ids, so a
  /// duplicate shows up here as a page with no content cached.
  Future<void> _loadContent() async {
    final pages = ref.read(pageProvider(widget.notebookId)).pages;
    final store = ref.read(sceneElementStoreProvider);
    for (final p in pages) {
      if (!_byPage.containsKey(p.id)) {
        _byPage[p.id] = await store.loadForPage(p.id);
      }
    }
    unawaited(_imageCache.ensure([
      for (final els in _byPage.values)
        for (final e in els)
          if (e is ImageElement) e.relativeImagePath,
    ]));
    if (mounted) setState(() => _loading = false);
  }

  void _toggle(int id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  void _setSelecting(bool on) => setState(() {
        _selecting = on;
        _selected.clear();
      });

  void _open(int index) {
    _pages.switchPage(index);
    Navigator.of(context).maybePop();
  }

  Future<void> _drop(int draggedId, int targetIndex) async {
    final ids = _selecting && _selected.contains(draggedId)
        ? _selected.toList()
        : [draggedId];
    await _pages.movePages(ids, targetIndex);
  }

  Future<void> _after(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    await _loadContent();
  }

  Future<void> _delete() async {
    final n = _selected.length;
    final total = ref.read(pageProvider(widget.notebookId)).pages.length;
    if (n == 0) return;
    if (n >= total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A notebook needs at least one page.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n == 1 ? 'Delete this page?' : 'Delete $n pages?'),
        content: const Text('Their writing is deleted too.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              key: const Key('pageManagerConfirmDelete'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _pages.deletePages(_selected.toList());
    if (!mounted) return;
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pageProvider(widget.notebookId));
    final pages = state.pages;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting
            ? '${_selected.length} selected'
            : 'Pages (${pages.length})'),
        actions: [
          if (_selecting)
            IconButton(
              key: const Key('pageManagerSelectAll'),
              tooltip: 'Select all',
              icon: const Icon(Icons.select_all),
              onPressed: () => setState(() {
                _selected
                  ..clear()
                  ..addAll(pages.map((p) => p.id));
              }),
            ),
          TextButton(
            key: const Key('pageManagerSelect'),
            onPressed: () => _setSelecting(!_selecting),
            child: Text(_selecting ? 'Done' : 'Select'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: _imageCache,
              builder: (_, _) => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: _aspect * 0.85,
                ),
                itemCount: pages.length,
                itemBuilder: (_, i) => _cell(
                  index: i,
                  id: pages[i].id,
                  current: i == state.currentPageIndex,
                  scheme: scheme,
                ),
              ),
            ),
      bottomNavigationBar: _selecting ? _selectionBar() : null,
    );
  }

  Widget _cell({
    required int index,
    required int id,
    required bool current,
    required ColorScheme scheme,
  }) {
    final picked = _selected.contains(id);
    Widget tile(bool ghost) => Opacity(
          opacity: ghost ? 0.35 : 1,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: picked || current
                              ? scheme.primary
                              : Colors.transparent,
                          width: picked ? 3 : 2,
                        ),
                      ),
                      child: IgnorePointer(
                        child: Center(
                          child: PageThumbnail(
                            elements: _byPage[id] ?? const [],
                            paper: _paper,
                            imageCache: _imageCache,
                            aspectRatio: _aspect,
                          ),
                        ),
                      ),
                    ),
                    if (_selecting)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          picked
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color:
                              picked ? scheme.primary : context.colors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('${index + 1}'),
            ],
          ),
        );

    return DragTarget<int>(
      key: Key('pageCell_$index'),
      onWillAcceptWithDetails: (d) => d.data != id,
      onAcceptWithDetails: (d) => _drop(d.data, index),
      builder: (_, candidate, _) => LongPressDraggable<int>(
        data: id,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
              width: 110, height: 110 / _aspect + 24, child: tile(false)),
        ),
        childWhenDragging: tile(true),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selecting ? _toggle(id) : _open(index),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color:
                      candidate.isEmpty ? Colors.transparent : scheme.primary,
                  width: 4,
                ),
              ),
            ),
            child: tile(false),
          ),
        ),
      ),
    );
  }

  Widget _selectionBar() {
    final has = _selected.isNotEmpty;
    final ids = _selected.toList();
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            key: const Key('pageManagerDuplicate'),
            tooltip: 'Duplicate',
            icon: const Icon(Icons.copy_outlined),
            onPressed:
                has ? () => _after(() => _pages.duplicatePages(ids)) : null,
          ),
          IconButton(
            key: const Key('pageManagerToStart'),
            tooltip: 'Move to start',
            icon: const Icon(Icons.vertical_align_top),
            onPressed: has ? () => _pages.movePages(ids, 0) : null,
          ),
          IconButton(
            key: const Key('pageManagerToEnd'),
            tooltip: 'Move to end',
            icon: const Icon(Icons.vertical_align_bottom),
            onPressed: has ? () => _pages.movePages(ids, 1 << 20) : null,
          ),
          IconButton(
            key: const Key('pageManagerDelete'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: has ? _delete : null,
          ),
        ],
      ),
    );
  }
}
