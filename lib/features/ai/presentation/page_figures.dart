// The figures the AI has read on each page, for the sidebar to show.
//
// Kept for the session, by page, like the page's analysed context: closing the
// panel and opening it again shows what was already read instead of nothing.

import 'package:flutter_riverpod/legacy.dart';

import '../domain/figure.dart';
import '../domain/scene_graph_figure.dart';

/// The figures last read on a page (by page id). Empty until a read finds some.
final pageFiguresProvider =
    StateProvider.family<List<FigureDescription>, int>((ref, pageId) => const []);

/// The figures to show after a read that found [current], given that
/// [previous] were showing.
///
/// A [deep] read looked at everything, so what it found is the answer. A light
/// read — the one that follows each writing pause — runs no vision model: it
/// still reads shape-built diagrams exactly, but says nothing either way about
/// drawings and pictures. Those are carried over from [previous] rather than
/// blinking out every time the student pauses; the next deep read (opening the
/// panel, Re-read) settles what is really there.
List<FigureDescription> carryFigures(
  List<FigureDescription> previous,
  List<FigureDescription> current, {
  required bool deep,
}) {
  if (deep) return current;
  return [
    ...current,
    for (final f in previous)
      if (f.modelId != kSceneGraphModelId && !current.contains(f)) f,
  ];
}
