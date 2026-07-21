// The Knowledge Graph screen (Phase 2, Loop 2.4): a notebook's concepts drawn
// as a map, coloured and sized by how well the learner knows each one, with the
// relationships the Context Engine inferred as edges.
//
// A dedicated screen (not the sidebar) reached from the editor. The layout and
// graph assembly are pure and unit-tested (`domain/knowledge_graph/`); this file
// is only painting + pan/zoom + the loading/empty/error surfaces.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/knowledge_graph/graph_layout.dart';
import '../../domain/knowledge_graph/knowledge_graph.dart';
import '../../domain/memory/concept_mastery.dart';
import '../ai_providers.dart';

/// Mastery → colour. A clear progression the legend explains: not-studied grey,
/// learning honey, practiced coral, mastered green.
Color masteryColor(MasteryLevel level) => switch (level) {
      MasteryLevel.unseen => AppColors.textMuted,
      MasteryLevel.learning => AppColors.accentYellow,
      MasteryLevel.practiced => AppColors.accent,
      MasteryLevel.mastered => AppColors.accentGreen,
    };

class KnowledgeGraphScreen extends ConsumerWidget {
  final int notebookId;
  const KnowledgeGraphScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graphAsync = ref.watch(knowledgeGraphProvider(notebookId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Knowledge graph'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(knowledgeGraphProvider(notebookId)),
          ),
        ],
      ),
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.error_outline,
          title: "Couldn't build the graph",
          subtitle: '$e',
        ),
        data: (graph) => graph.isEmpty
            ? const _Message(
                icon: Icons.hub_outlined,
                title: 'No concepts yet',
                subtitle: 'As the AI reads your notes it learns the concepts '
                    'and how they connect. Write and open the AI sidebar on a '
                    'few pages, then come back.',
              )
            : _GraphView(graph: graph),
      ),
    );
  }
}

class _GraphView extends StatefulWidget {
  final KnowledgeGraph graph;
  const _GraphView({required this.graph});

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> {
  late Map<String, Offset> _layout = computeGraphLayout(widget.graph);

  @override
  void didUpdateWidget(_GraphView old) {
    super.didUpdateWidget(old);
    // Recompute only when the graph itself changed (a refresh), not on every
    // rebuild — the layout pass is the one non-trivial cost here.
    if (!identical(old.graph, widget.graph)) {
      _layout = computeGraphLayout(widget.graph);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 0.4,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(80),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.biggest.shortestSide.clamp(280.0, 2000.0);
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: CustomPaint(
                      painter: _GraphPainter(
                        graph: widget.graph,
                        layout: _layout,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const _Legend(),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  final KnowledgeGraph graph;
  final Map<String, Offset> layout;
  final TextDirection textDirection;

  _GraphPainter({
    required this.graph,
    required this.layout,
    required this.textDirection,
  });

  static const _pad = 40.0;

  Offset _at(String key, Size size) {
    final p = layout[key] ?? const Offset(0.5, 0.5);
    return Offset(
      _pad + p.dx * (size.width - 2 * _pad),
      _pad + p.dy * (size.height - 2 * _pad),
    );
  }

  double _radius(int degree) => (8 + degree * 2.5).clamp(8.0, 22.0).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Edges first, so nodes sit on top.
    for (final e in graph.edges) {
      final from = _at(e.fromKey, size);
      final to = _at(e.toKey, size);
      final toNode = graph.nodeFor(e.toKey);
      final end = _shortenToEdge(from, to, _radius(toNode?.degree ?? 0));
      canvas.drawLine(from, end, edgePaint);
      _drawArrowhead(canvas, from, end, edgePaint);
    }

    // Nodes + labels.
    for (final node in graph.nodes) {
      final center = _at(node.key, size);
      final r = _radius(node.degree);
      final color = masteryColor(node.level);

      canvas.drawCircle(center, r, Paint()..color = color);
      if (node.referencedOnly) {
        // "Mentioned, not explained": filled like any other node — it IS part
        // of the notes' concept web — but ringed so a concept the notebook
        // gestures at without ever covering still reads at a glance. This used
        // to draw a grey *hollow* ring, which read as an uncoloured/broken node
        // rather than a deliberate signal.
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = AppColors.textSecondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      _drawLabel(canvas, node.name, center, r);
    }
  }

  /// Pulls the line endpoint back to the target node's rim so the arrowhead
  /// isn't buried under the circle.
  Offset _shortenToEdge(Offset from, Offset to, double targetRadius) {
    final d = to - from;
    final len = d.distance;
    if (len <= targetRadius) return to;
    return from + d * ((len - targetRadius) / len);
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final dir = d / len;
    const size = 6.0;
    final normal = Offset(-dir.dy, dir.dx);
    final base = to - dir * size;
    canvas.drawLine(to, base + normal * (size * 0.6), paint);
    canvas.drawLine(to, base - normal * (size * 0.6), paint);
  }

  void _drawLabel(Canvas canvas, String text, Offset center, double r) {
    final tp = TextPainter(
      text: TextSpan(
        text: text.length > 22 ? '${text.substring(0, 22)}…' : text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.1,
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: textDirection,
      maxLines: 2,
      ellipsis: '…',
      textAlign: TextAlign.center,
    )..layout(maxWidth: 90);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + r + 3));
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      !identical(old.graph, graph) || !identical(old.layout, layout);
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final level in MasteryLevel.values)
            _Swatch(color: masteryColor(level), label: _levelLabel(level)),
          _Swatch(
            color: masteryColor(MasteryLevel.learning),
            label: 'Mentioned, not explained',
            ringed: true,
          ),
        ],
      ),
    );
  }

  static String _levelLabel(MasteryLevel level) => switch (level) {
        MasteryLevel.unseen => 'Not studied',
        MasteryLevel.learning => 'Learning',
        MasteryLevel.practiced => 'Practiced',
        MasteryLevel.mastered => 'Mastered',
      };
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;

  /// Filled *and* outlined — mirrors how the painter marks a
  /// "mentioned, not explained" node.
  final bool ringed;
  const _Swatch({required this.color, required this.label, this.ringed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: ringed
                ? Border.all(color: AppColors.textSecondary, width: 2)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.accentSoft),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
