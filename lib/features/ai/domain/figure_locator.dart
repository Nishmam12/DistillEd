// Finds the figures drawn on a page, so each can be read on its own.
//
// The figure pass used to be handed the whole drawn layer as one picture. A
// small diagram on a full page then reached the model as a few dozen pixels,
// and two diagrams on one page came back as one muddled description — with no
// record of where on the page either was.
//
// A figure here is a cluster of things that are DRAWN rather than written:
// shapes and arrows, and ink the handwriting recogniser did not read as text.
// Writing and typed labels that sit inside a cluster belong to it (they are its
// labels); text just outside it is kept as context (it is usually the caption).
//
// Pure geometry: no model, no rendering. The caller renders each region's
// elements and sends that crop to the vision model.

import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/geometry/element_bounds.dart';
import '../../../domain/model/scene_element.dart';

/// A line of text on the page and where it is: typed text, or a line of
/// handwriting as ML Kit read it.
typedef PageTextLine = ({Rect bounds, String text});

class FigureRegion {
  /// The figure's extent in scene units, with a little margin.
  final Rect bounds;

  /// Everything to draw to show the figure, in the page's z-order: the drawn
  /// elements and any labels inside them.
  final List<SceneElement> elements;

  /// The elements that made this a figure: shapes, arrows and non-writing ink.
  final List<SceneElement> seeds;

  /// Text inside the figure, exactly as typed or as ML Kit read it — the
  /// figure's labels, known without asking the vision model.
  final String labelText;

  /// Text just outside the figure: a caption, or the sentence pointing at it.
  final String nearbyText;

  const FigureRegion({
    required this.bounds,
    required this.elements,
    required this.seeds,
    this.labelText = '',
    this.nearbyText = '',
  });
}

/// More separate figures than this on one page and they are read as a single
/// picture: a page of scattered doodles is not worth a model call apiece.
const int kMaxFigureRegions = 4;

/// A lone piece of ink smaller than this on both sides is a stray mark.
const double _kMinFigureSide = 24;

/// How far outside a figure text still counts as "beside" it.
const double _kNearbyMargin = 72;

/// The figures among [elements] (one page, or a selection).
///
/// [writingIds] are the freehand strokes known to be handwriting — read
/// confidently as text. Pass null when that is not known (the page's ink was
/// read whole by the vision model, or not read at all): the drawn layer is then
/// one region, as it always was, because ink cannot be told from drawing.
///
/// [textLines] are the page's lines of text with their positions; typed text
/// elements are added to them automatically.
List<FigureRegion> locateFigures(
  List<SceneElement> elements, {
  required Set<String>? writingIds,
  List<PageTextLine> textLines = const [],
  int maxRegions = kMaxFigureRegions,
}) {
  final drawn = [
    for (final e in elements)
      if (e is! ImageElement &&
          !(e is FreehandElement && (e.isEraser || e.points.isEmpty)))
        e,
  ];
  final lines = <PageTextLine>[
    ...textLines,
    for (final e in drawn)
      if (e is TextElement && e.text.trim().isNotEmpty)
        (bounds: ElementBounds.of(e), text: e.text.trim()),
  ];

  bool isSeed(SceneElement e) =>
      e is SceneShapeElement ||
      (e is FreehandElement &&
          (writingIds == null || !writingIds.contains(e.id)));

  final seeds = [for (final e in drawn) if (isSeed(e)) e];
  if (seeds.isEmpty) return const [];

  if (writingIds == null) {
    return [_region(seeds, drawn, lines, wholeLayer: true)];
  }

  // Join seeds that touch, nearly touch, or are tied by an arrow binding.
  final bounds = [for (final s in seeds) ElementBounds.of(s)];
  final sizes = [for (final b in bounds) math.max(b.width, b.height)]..sort();
  final gap = (sizes[sizes.length ~/ 2] * 0.25).clamp(16.0, 80.0);
  final parent = [for (var i = 0; i < seeds.length; i++) i];
  int find(int i) => parent[i] == i ? i : parent[i] = find(parent[i]);
  void join(int a, int b) => parent[find(a)] = find(b);

  final indexOf = {for (var i = 0; i < seeds.length; i++) seeds[i].id: i};
  for (var i = 0; i < seeds.length; i++) {
    final inflated = bounds[i].inflate(gap);
    for (var j = i + 1; j < seeds.length; j++) {
      if (inflated.overlaps(bounds[j])) join(i, j);
    }
    final s = seeds[i];
    if (s is SceneShapeElement) {
      for (final id in [s.startBindingId, s.endBindingId]) {
        final j = indexOf[id];
        if (j != null) join(i, j);
      }
    }
  }

  final clusters = <int, List<SceneElement>>{};
  for (var i = 0; i < seeds.length; i++) {
    clusters.putIfAbsent(find(i), () => []).add(seeds[i]);
  }

  final kept = <List<SceneElement>>[];
  for (final cluster in clusters.values) {
    final hasShape = cluster.any((e) => e is SceneShapeElement);
    if (!hasShape) {
      final b = _union(cluster);
      // A dot, a tick, a comma the recogniser did not attach to a line.
      if (b.width < _kMinFigureSide && b.height < _kMinFigureSide) continue;
    }
    kept.add(cluster);
  }
  if (kept.isEmpty) return const [];

  if (kept.length > maxRegions) {
    return [
      _region([for (final c in kept) ...c], drawn, lines, wholeLayer: false),
    ];
  }

  final regions = [for (final c in kept) _region(c, drawn, lines)]
    ..sort((a, b) {
      final dy = a.bounds.top.compareTo(b.bounds.top);
      return dy != 0 ? dy : a.bounds.left.compareTo(b.bounds.left);
    });
  return regions;
}

Rect _union(Iterable<SceneElement> elements) {
  Rect? u;
  for (final e in elements) {
    final b = ElementBounds.of(e);
    u = u == null ? b : u.expandToInclude(b);
  }
  return u ?? Rect.zero;
}

FigureRegion _region(
  List<SceneElement> seeds,
  List<SceneElement> drawn,
  List<PageTextLine> lines, {
  bool wholeLayer = false,
}) {
  final seedIds = {for (final s in seeds) s.id};
  final core = wholeLayer ? _union(drawn) : _union(seeds);
  final bounds = core.inflate(16);

  // Labels: anything else drawn whose centre is inside the figure.
  final members = [
    for (final e in drawn)
      if (wholeLayer ||
          seedIds.contains(e.id) ||
          bounds.contains(ElementBounds.of(e).center))
        e,
  ];

  final inside = <String>[];
  final beside = <String>[];
  final reach = bounds.inflate(_kNearbyMargin);
  for (final line in lines) {
    if (line.text.trim().isEmpty) continue;
    if (bounds.contains(line.bounds.center)) {
      inside.add(line.text.trim());
    } else if (!wholeLayer && reach.overlaps(line.bounds)) {
      beside.add(line.text.trim());
    }
  }

  return FigureRegion(
    bounds: bounds,
    elements: members,
    seeds: seeds,
    labelText: inside.join('\n'),
    nearbyText: beside.join('\n'),
  );
}
