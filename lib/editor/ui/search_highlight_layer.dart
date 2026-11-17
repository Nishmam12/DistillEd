// Tints the words a search found, on the page it was opened at from Find, with
// a chip that says how many and clears the tint: words on page pictures, and
// whole lines of handwriting (read again on the device when the tint is shown).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/geometry/search_matches.dart';
import '../../domain/geometry/word_geometry.dart';
import '../../domain/model/page_words.dart';
import '../../domain/model/scene_element.dart';
import '../../features/ai/domain/figure_locator.dart' show PageTextLine;
import '../../features/ai/presentation/ai_providers.dart'
    show handwritingRecognitionServiceProvider;
import '../../features/import/page_words_service.dart';
import '../state/scene_controller.dart';
import '../state/search_highlight.dart';
import '../state/viewport_controller.dart';

/// The page's handwriting, line by line, for tinting a search. Only read while
/// a tint is on the page; never fetches the reader's model, so with none on
/// the device the handwriting just isn't tinted.
final searchInkLinesProvider = FutureProvider.autoDispose
    .family<List<PageTextLine>, ScenePageKey>((ref, key) async {
  final ink = [
    for (final e in ref.watch(sceneControllerProvider(key)))
      if (e is FreehandElement && !e.isEraser && e.points.isNotEmpty) e,
  ];
  if (ink.isEmpty) return const [];
  final recognition = ref.read(handwritingRecognitionServiceProvider);
  final language = ref.read(settingsProvider).recognitionLanguage;
  try {
    if (!await recognition.isModelDownloaded(language)) return const [];
    return [
      for (final l in await recognition.recognizeInkLines(ink, language))
        if (l.text.trim().isNotEmpty) (bounds: l.bounds, text: l.text),
    ];
  } catch (_) {
    return const [];
  }
});

class SearchHighlightLayer extends ConsumerWidget {
  final ScenePageKey pageKey;
  const SearchHighlightLayer({super.key, required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hl = ref.watch(searchHighlightProvider);
    if (hl == null || hl.pageId != pageKey.pageId) {
      return const SizedBox.shrink();
    }
    final viewport = ref.watch(viewportProvider);
    final polygons = <List<Offset>>[];
    var matches = 0;
    for (final image
        in ref.watch(sceneControllerProvider(pageKey)).whereType<ImageElement>()) {
      final words =
          ref.watch(pageWordsProvider(image.relativeImagePath)).value;
      if (words == null || words.isEmpty) continue;
      final found = matchWords(words, hl.query);
      matches += found.matches;
      for (final i in found.indexes) {
        polygons.add([
          for (final c in cornersOnPage(words.words[i].box, image))
            viewport.toViewport(c),
        ]);
      }
    }
    // Handwriting: a line holding (part of) a match is tinted whole. Lines are
    // matched as one run of text, so a phrase written across two lines still
    // matches, as it does in Find.
    final lines = ref.watch(searchInkLinesProvider(pageKey)).value ?? const [];
    if (lines.isNotEmpty) {
      final found = matchWords(
        PageWords(source: PageWordsSource.ocr, words: [
          for (var i = 0; i < lines.length; i++)
            PageWord(text: lines[i].text, box: Rect.zero, line: i),
        ]),
        hl.query,
      );
      matches += found.matches;
      for (final i in found.indexes) {
        final b = lines[i].bounds.inflate(4);
        polygons.add([
          for (final c in [b.topLeft, b.topRight, b.bottomRight, b.bottomLeft])
            viewport.toViewport(c),
        ]);
      }
    }
    // Nothing found (a typed-text hit, or still reading): show nothing, not a
    // chip that says zero.
    if (matches == 0) return const SizedBox.shrink();

    final accent = context.colors.accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            key: const Key('searchHighlightPaint'),
            painter: _TintPainter(polygons, accent),
            size: Size.infinite,
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Material(
            key: const Key('searchHighlightChip'),
            elevation: 3,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(matches == 1 ? '1 match on this page' : '$matches matches on this page'),
                  IconButton(
                    key: const Key('searchHighlightClear'),
                    tooltip: 'Clear highlight',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        ref.read(searchHighlightProvider.notifier).state = null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TintPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final Color color;
  _TintPainter(this.polygons, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.32);
    for (final p in polygons) {
      canvas.drawPath(Path()..addPolygon(p, true), paint);
    }
  }

  @override
  bool shouldRepaint(_TintPainter old) =>
      old.color != color || old.polygons.length != polygons.length ||
      !identical(old.polygons, polygons);
}
