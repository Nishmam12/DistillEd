// Reads a flowchart drawn with Margo's own shape tools straight from the
// shapes — no vision model, and nothing to get wrong.
//
// A diagram built from boxes, typed labels and arrows is already structured
// data: every node's text is known exactly and every arrow knows (or its
// endpoints show) which boxes it joins. Rendering that to pixels and asking a
// 2B model to read it back is the slow way to a worse answer. It also needs no
// model download, so it works on every device and on every kind of read.
//
// Deliberately narrow: it answers only when the shapes are the whole figure —
// every node labelled, at least one connection, no pen drawing mixed in.
// Anything else goes to the vision model as before.

import 'dart:ui';

import '../../../domain/geometry/element_bounds.dart';
import '../../../domain/model/scene_element.dart';
import 'figure.dart';
import 'figure_locator.dart';

/// The `modelId` of a figure read from the scene itself.
const String kSceneGraphModelId = 'scene-graph';

/// How far from a box an unattached arrow's end may be and still mean it.
const double _kAttachSlop = 14;

bool _isConnector(SceneShapeElement s) =>
    s.shapeType == ShapeType.arrow || s.shapeType == ShapeType.line;

/// [region] described exactly from its shapes, or null when the shapes are not
/// the whole story (see the header).
FigureDescription? describeSceneGraph(FigureRegion region) {
  // Pen strokes in the figure — a sketch, a hand-written label — are something
  // this cannot read.
  if (region.elements.any((e) => e is FreehandElement)) return null;

  final nodes = <SceneShapeElement>[];
  final connectors = <SceneShapeElement>[];
  final texts = <TextElement>[];
  for (final e in region.elements) {
    if (e is SceneShapeElement) {
      (_isConnector(e) ? connectors : nodes).add(e);
    } else if (e is TextElement && e.text.trim().isNotEmpty) {
      texts.add(e);
    }
  }
  if (nodes.length < 2 || connectors.isEmpty) return null;

  // Each node's label: text bound to it, else text sitting inside it.
  final labelOf = <String, String>{};
  for (final node in nodes) {
    final box = ElementBounds.of(node);
    final own = [
      for (final t in texts)
        if (t.containerId == node.id ||
            (t.containerId.isEmpty && box.contains(ElementBounds.of(t).center)))
          t.text.trim().replaceAll(RegExp(r'\s+'), ' '),
    ];
    if (own.isEmpty) return null; // an unlabelled node: not exact any more
    labelOf[node.id] = own.join(' ');
  }

  String? nodeAt(Offset p) {
    for (final node in nodes) {
      if (ElementBounds.of(node).inflate(_kAttachSlop).contains(p)) {
        return node.id;
      }
    }
    return null;
  }

  // (from, to, directed), in drawing order, without repeats.
  final edges = <(String, String, bool)>[];
  for (final c in connectors) {
    final g = c.geometryData;
    if (g.length < 4) continue;
    var from = labelOf.containsKey(c.startBindingId)
        ? c.startBindingId
        : nodeAt(Offset(g[0], g[1]));
    var to = labelOf.containsKey(c.endBindingId)
        ? c.endBindingId
        : nodeAt(Offset(g[g.length - 2], g[g.length - 1]));
    if (from == null || to == null || from == to) continue;

    final headAtEnd =
        c.shapeType == ShapeType.arrow && c.endArrowhead != Arrowhead.none;
    final headAtStart = c.startArrowhead != Arrowhead.none;
    if (headAtStart && !headAtEnd) (from, to) = (to, from);
    final edge = (from, to, headAtEnd || headAtStart);
    if (!edges.contains(edge)) edges.add(edge);
  }
  if (edges.isEmpty) return null;

  // Nodes in reading order.
  final ordered = [...nodes]..sort((a, b) {
      final ra = ElementBounds.of(a), rb = ElementBounds.of(b);
      final dy = ra.top.compareTo(rb.top);
      return dy != 0 ? dy : ra.left.compareTo(rb.left);
    });

  String describe((String, String, bool) e) =>
      '${labelOf[e.$1]} ${e.$3 ? '→' : '—'} ${labelOf[e.$2]}';

  final series = [
    for (final node in ordered)
      FigureSeries(
        label: labelOf[node.id]!,
        detail: [
          for (final e in edges)
            if (e.$1 == node.id)
              '${e.$3 ? 'leads to' : 'connected to'} ${labelOf[e.$2]}',
        ].join('; '),
      ),
  ];

  final links = edges.map(describe).join(', ');
  final arrows = edges.where((e) => e.$3).length;
  return FigureDescription(
    kind: FigureKind.diagram,
    summary: 'A diagram of ${nodes.length} labelled boxes joined by '
        '${edges.length} ${arrows == edges.length ? 'arrow' : 'connection'}'
        '${edges.length == 1 ? '' : 's'}: $links.',
    series: series,
    insight: _chain(edges, labelOf) ?? links,
    verbatimText: [for (final node in ordered) labelOf[node.id]!].join('\n'),
    confidence: 1.0,
    modelId: kSceneGraphModelId,
    grounding: 1.0,
    bounds: region.bounds,
    nearbyText: region.nearbyText,
  );
}

/// The edges as one `A → B → C` path when they form exactly that: every node
/// with at most one way in and one way out, all directed, one start. Null for a
/// branch, a merge, a loop or undirected links.
String? _chain(List<(String, String, bool)> edges, Map<String, String> labelOf) {
  if (edges.any((e) => !e.$3)) return null;
  final next = <String, String>{};
  final hasIncoming = <String>{};
  for (final e in edges) {
    if (next.containsKey(e.$1) || hasIncoming.contains(e.$2)) return null;
    next[e.$1] = e.$2;
    hasIncoming.add(e.$2);
  }
  final starts = next.keys.where((n) => !hasIncoming.contains(n)).toList();
  if (starts.length != 1) return null;
  final path = <String>[starts.single];
  while (next.containsKey(path.last)) {
    path.add(next[path.last]!);
    if (path.length > edges.length + 1) return null;
  }
  if (path.length != edges.length + 1) return null;
  return path.map((n) => labelOf[n]).join(' → ');
}
