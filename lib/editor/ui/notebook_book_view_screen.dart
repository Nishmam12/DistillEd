// Read-only "book view" for the unified engine: swipe through page spreads with
// a thumbnail filmstrip, on the notebook's paper colour. Being a pure viewer, it
// has no draw input, so there is no swipe-vs-draw gesture conflict (the bug the
// legacy book view suffered). Each page is rendered from the real scene store via
// the same [SceneStaticLayer] the editor uses, fitted into the page rect.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/geometry/selection_bounds.dart';
import '../../domain/model/scene_element.dart';
import '../state/page_notifier.dart';
import '../../features/home/domain/models/notebook.dart';
import '../../shared/isar/isar_service.dart';
import '../render/scene_image_cache.dart';
import '../render/scene_static_layer.dart';
import '../state/scene_controller.dart';
import '../state/scene_image_cache_provider.dart';

class NotebookBookViewScreen extends ConsumerStatefulWidget {
  final int notebookId;
  const NotebookBookViewScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookBookViewScreen> createState() =>
      _NotebookBookViewScreenState();
}

class _NotebookBookViewScreenState
    extends ConsumerState<NotebookBookViewScreen> {
  final PageController _controller = PageController();
  final Map<int, List<SceneElement>> _byPage = {};
  late final SceneImageCache _imageCache;
  Color _paper = const Color(0xFFFFFDF7);
  List<int> _pageIds = const [];
  int _index = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _imageCache = ref.read(sceneImageCacheProvider);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(pageProvider(widget.notebookId).notifier).initialize();
    final nb = await IsarService.instance.notebooks.get(widget.notebookId);
    final pages = ref.read(pageProvider(widget.notebookId)).pages;
    final store = ref.read(sceneElementStoreProvider);
    for (final p in pages) {
      _byPage[p.id] = await store.loadForPage(p.id);
    }
    _imageCache.ensure([
      for (final els in _byPage.values)
        for (final e in els)
          if (e is ImageElement) e.relativeImagePath,
    ]);
    if (mounted) {
      setState(() {
        _pageIds = pages.map((p) => p.id).toList();
        _paper = Color(nb?.backgroundColor ?? 0xFFFFFDF7);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpTo(int i) {
    _controller.jumpToPage(i);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book view')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pageIds.isEmpty
              ? const Center(child: Text('No pages'))
              : Column(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _imageCache,
                        builder: (_, __) => PageView.builder(
                          controller: _controller,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemCount: _pageIds.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.all(16),
                            child: _BookPage(
                              elements: _byPage[_pageIds[i]] ?? const [],
                              paper: _paper,
                              imageCache: _imageCache,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Filmstrip(
                      count: _pageIds.length,
                      current: _index,
                      builder: (i) => _BookPage(
                        elements: _byPage[_pageIds[i]] ?? const [],
                        paper: _paper,
                        imageCache: _imageCache,
                      ),
                      onTap: _jumpTo,
                    ),
                  ],
                ),
    );
  }
}

class _BookPage extends StatelessWidget {
  final List<SceneElement> elements;
  final Color paper;
  final SceneImageCache imageCache;

  const _BookPage({
    required this.elements,
    required this.paper,
    required this.imageCache,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1.414, // A4 portrait
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paper,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: CustomPaint(
          painter: _BookPagePainter(
            elements: elements,
            imageCache: imageCache,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Paints a page's elements fitted (scaled + centred) into the available size.
class _BookPagePainter extends CustomPainter {
  final List<SceneElement> elements;
  final SceneImageCache imageCache;

  _BookPagePainter({required this.elements, required this.imageCache});

  @override
  void paint(Canvas canvas, Size size) {
    if (elements.isEmpty) return;
    final bounds = SelectionBounds.union(elements);
    if (bounds == null || bounds.isEmpty) return;

    const pad = 12.0;
    final sx = (size.width - pad * 2) / bounds.width;
    final sy = (size.height - pad * 2) / bounds.height;
    final scale = sx < sy ? sx : sy;
    final dx = (size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final dy = (size.height - bounds.height * scale) / 2 - bounds.top * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    SceneStaticLayer(
      elements: elements,
      imageResolver: imageCache.get,
      imageEpoch: imageCache.version,
    ).paint(canvas, bounds.size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BookPagePainter old) =>
      !identical(elements, old.elements) ||
      imageCache.version != old.imageCache.version;
}

class _Filmstrip extends StatelessWidget {
  final int count;
  final int current;
  final Widget Function(int) builder;
  final ValueChanged<int> onTap;

  const _Filmstrip({
    required this.count,
    required this.current,
    required this.builder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: count,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            width: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: i == current
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black26,
                width: i == current ? 2 : 1,
              ),
            ),
            child: IgnorePointer(child: builder(i)),
          ),
        ),
      ),
    );
  }
}
