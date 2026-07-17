// A force-directed layout for the Knowledge Graph — pure, deterministic, and
// dependency-free (no `graphview` package: a notebook graph is dozens of nodes,
// and a self-contained ~Fruchterman–Reingold pass is smaller, fully testable,
// and never breaks on a package bump).
//
// Deterministic on purpose: nodes seed on a circle by index (no RNG), so the
// same graph always lays out the same way — a stable picture the learner can
// build a mental map of, and a layout a test can assert on.
//
// Positions come back normalized to the unit square [0,1]²; the painter scales
// them to whatever canvas it has.

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'knowledge_graph.dart';

/// Computes a position in [0,1]² for every node key in [graph].
///
/// [iterations] trades settle quality for time (200 is ample at notebook
/// scale). An empty or single-node graph is handled without iterating.
Map<String, Offset> computeGraphLayout(
  KnowledgeGraph graph, {
  int iterations = 200,
}) {
  final nodes = graph.nodes;
  final n = nodes.length;
  if (n == 0) return const {};
  if (n == 1) return {nodes.first.key: const Offset(0.5, 0.5)};

  // Seed on a circle, keyed by index → deterministic, symmetry broken by a
  // per-node radius wobble derived from the key (still no RNG).
  final pos = <String, _V>{};
  for (var i = 0; i < n; i++) {
    final angle = 2 * math.pi * i / n;
    final wobble = 0.85 + 0.3 * _unitHash(nodes[i].key);
    pos[nodes[i].key] = _V(
      0.5 + 0.4 * wobble * math.cos(angle),
      0.5 + 0.4 * wobble * math.sin(angle),
    );
  }

  // Ideal edge length for a unit square holding n nodes.
  final k = math.sqrt(1.0 / n);
  var temperature = 0.1; // max node displacement per step, cooled each pass

  for (var step = 0; step < iterations; step++) {
    final disp = {for (final node in nodes) node.key: const _V(0, 0)};

    // Repulsion between every pair (n is small, so O(n²) is fine).
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        final ka = nodes[a].key;
        final kb = nodes[b].key;
        var delta = pos[ka]! - pos[kb]!;
        var dist = delta.length;
        if (dist < 1e-4) {
          // Coincident nodes: nudge apart deterministically so the force is
          // defined.
          delta = _V(1e-3 * (a + 1), 1e-3 * (b + 1));
          dist = delta.length;
        }
        final force = (k * k) / dist;
        final push = delta / dist * force;
        disp[ka] = disp[ka]! + push;
        disp[kb] = disp[kb]! - push;
      }
    }

    // Attraction along edges.
    for (final e in graph.edges) {
      final pf = pos[e.fromKey];
      final pt = pos[e.toKey];
      if (pf == null || pt == null) continue;
      var delta = pf - pt;
      final dist = delta.length;
      if (dist < 1e-4) continue;
      final force = (dist * dist) / k;
      final pull = delta / dist * force;
      disp[e.fromKey] = disp[e.fromKey]! - pull;
      disp[e.toKey] = disp[e.toKey]! + pull;
    }

    // Apply, capped by temperature, then keep inside the unit square.
    for (final node in nodes) {
      final d = disp[node.key]!;
      final dist = d.length;
      if (dist > 1e-9) {
        final limited = d / dist * math.min(dist, temperature);
        pos[node.key] = (pos[node.key]! + limited).clampUnit();
      }
    }
    temperature = math.max(0.01, temperature * 0.97); // cool
  }

  return {for (final e in pos.entries) e.key: Offset(e.value.x, e.value.y)};
}

/// A key → a stable value in [0,1), so symmetry-breaking needs no RNG.
double _unitHash(String key) {
  var h = 2166136261; // FNV-1a
  for (final unit in key.codeUnits) {
    h = (h ^ unit) * 16777619 & 0xFFFFFFFF;
  }
  return (h & 0xFFFF) / 0x10000;
}

/// Tiny mutable 2-vector — a local helper so the layout math reads cleanly
/// without allocating an [Offset] per operation.
class _V {
  final double x;
  final double y;
  const _V(this.x, this.y);

  _V operator +(_V o) => _V(x + o.x, y + o.y);
  _V operator -(_V o) => _V(x - o.x, y - o.y);
  _V operator *(double s) => _V(x * s, y * s);
  _V operator /(double s) => _V(x / s, y / s);
  double get length => math.sqrt(x * x + y * y);

  /// Keep a little margin so nodes never sit on the very edge.
  _V clampUnit() =>
      _V(x.clamp(0.03, 0.97).toDouble(), y.clamp(0.03, 0.97).toDouble());
}
