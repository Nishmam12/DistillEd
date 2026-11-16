// Links of an imported PDF page, tappable while the hand tool, or the select
// tool's Text mode, is in use.
//
// Drawn as a layer over the page rather than handled in the pointer pipeline:
// each link is a translucent tap target, so the pen, panning and palm
// rejection underneath see every touch exactly as before. The pen never
// follows a link: nothing is shown or tappable in any drawing tool.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/geometry/word_geometry.dart';
import '../../domain/model/page_links.dart';
import '../../domain/model/scene_element.dart';
import '../../features/import/page_links_service.dart';
import '../state/editor_tool_controller.dart';
import '../state/scene_controller.dart';
import '../state/viewport_controller.dart';

/// Smallest a tap target is made, on screen, so a thin line of link text can
/// be hit with a finger.
const double kLinkMinTarget = 32;

class PdfLinkLayer extends ConsumerWidget {
  final ScenePageKey pageKey;

  /// Called with the link tapped and the picture it is on.
  final void Function(PageLink link, String imagePath) onFollow;

  const PdfLinkLayer({super.key, required this.pageKey, required this.onFollow});

  /// Whether the tool in use is one that follows links.
  static bool followsLinks(EditorToolState tool) =>
      tool.tool == EditorTool.hand ||
      (tool.tool == EditorTool.select && tool.selectText);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!followsLinks(ref.watch(editorToolProvider))) {
      return const SizedBox.shrink();
    }
    final viewport = ref.watch(viewportProvider);
    final elements = ref.watch(sceneControllerProvider(pageKey));
    final targets = <Widget>[];
    for (final image in elements.whereType<ImageElement>()) {
      // Only pictures of PDF pages can have links.
      if (siblingPdfPagePath(image.relativeImagePath, 1) == null) continue;
      final links = ref.watch(pageLinksProvider(image.relativeImagePath));
      for (final link in links.value?.links ?? const <PageLink>[]) {
        final corners = cornersOnPage(link.rect, image)
            .map(viewport.toViewport)
            .toList();
        var box = Rect.fromPoints(corners[0], corners[2]);
        for (final c in corners) {
          box = box.expandToInclude(Rect.fromPoints(c, c));
        }
        final grown = Rect.fromCenter(
          center: box.center,
          width: box.width < kLinkMinTarget ? kLinkMinTarget : box.width,
          height: box.height < kLinkMinTarget ? kLinkMinTarget : box.height,
        );
        targets.add(Positioned.fromRect(
          rect: grown,
          child: GestureDetector(
            key: Key('pdfLink_${targets.length}'),
            // Translucent: the canvas underneath still gets the touch.
            behavior: HitTestBehavior.translucent,
            onTap: () => onFollow(link, image.relativeImagePath),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: box.width / grown.width,
                child: Container(
                  height: 2,
                  color: context.colors.accent.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ));
      }
    }
    if (targets.isEmpty) return const SizedBox.shrink();
    return Stack(fit: StackFit.expand, children: targets);
  }
}
