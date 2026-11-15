// The continuous layout's pages above and below the current one: paper,
// template and saved content, drawn read-only one page and a gap beyond the
// current page's edges, moving with the same view. Writing happens on the
// current page; a touch on one of these makes it current (see SceneCanvas).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/scene_element.dart';
import '../../domain/model/template_type.dart';
import '../render/background_layer.dart';
import '../render/scene_static_layer.dart';
import '../state/scene_controller.dart';
import '../state/scene_image_cache_provider.dart';
import '../state/viewport_controller.dart';

class NeighbourPagesLayer extends ConsumerWidget {
  final int notebookId;

  /// The page above the current one, or null on the first page.
  final int? abovePageId;

  /// The page below the current one, or null on the last page.
  final int? belowPageId;

  /// Every page's size, in scene units.
  final Size sheet;
  final Color paperColor;
  final TemplateType template;

  /// The paper of the page above / below when it has its own; [template]
  /// otherwise.
  final TemplateType? aboveTemplate;
  final TemplateType? belowTemplate;

  const NeighbourPagesLayer({
    super.key,
    required this.notebookId,
    required this.abovePageId,
    required this.belowPageId,
    required this.sheet,
    required this.paperColor,
    required this.template,
    this.aboveTemplate,
    this.belowTemplate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = ref.watch(viewportProvider);
    final step = sheet.height + ViewportController.pageGap;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (abovePageId case final id?)
            _NeighbourPage(
                key: ValueKey('neighbourPage_$id'),
                pageKey: (notebookId: notebookId, pageId: id),
                offsetY: -step,
                sheet: sheet,
                viewport: viewport,
                paperColor: paperColor,
                template: aboveTemplate ?? template),
          if (belowPageId case final id?)
            _NeighbourPage(
                key: ValueKey('neighbourPage_$id'),
                pageKey: (notebookId: notebookId, pageId: id),
                offsetY: step,
                sheet: sheet,
                viewport: viewport,
                paperColor: paperColor,
                template: belowTemplate ?? template),
        ],
      ),
    );
  }
}

class _NeighbourPage extends ConsumerWidget {
  final ScenePageKey pageKey;
  final double offsetY;
  final Size sheet;
  final ViewportState viewport;
  final Color paperColor;
  final TemplateType template;

  const _NeighbourPage({
    super.key,
    required this.pageKey,
    required this.offsetY,
    required this.sheet,
    required this.viewport,
    required this.paperColor,
    required this.template,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elements = ref.watch(sceneControllerProvider(pageKey));
    final images = ref.watch(sceneImageCacheProvider);
    images.ensure([
      for (final e in elements)
        if (e is ImageElement) e.relativeImagePath,
    ]);
    final page = Rect.fromLTWH(0, offsetY, sheet.width, sheet.height);
    final pageScreen = viewport.toViewportRect(page);
    final matrix = viewport.toMatrix4()..translateByDouble(0.0, offsetY, 0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: BackgroundLayer(
            backgroundColor: paperColor,
            deskColor: Colors.transparent,
            templateType: template,
            scrollX: viewport.scrollX,
            scrollY: viewport.scrollY,
            zoom: viewport.zoom,
            pageRect: page,
          ),
          size: Size.infinite,
        ),
        ClipRect(
          clipper: _ScreenRectClipper(pageScreen),
          child: Transform(
            transform: matrix,
            child: AnimatedBuilder(
              animation: images,
              builder: (_, _) => CustomPaint(
                painter: SceneStaticLayer(
                  elements: elements,
                  imageResolver: images.get,
                  imageEpoch: images.version,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenRectClipper extends CustomClipper<Rect> {
  final Rect rect;
  const _ScreenRectClipper(this.rect);

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_ScreenRectClipper old) => rect != old.rect;
}
