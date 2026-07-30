// A non-textual visual — chart, diagram, flowchart, equation, table — that the
// AI read off a page, described in structured form.
//
// Why this is NOT just more text: the OCR path ([GemmaVisionOcrService]) answers
// "what words are printed here". A bar chart answers that with its axis labels
// and nothing else — "Sales Q1 Q2 Q3" — which is why diagrams historically
// vanished from summaries. A figure answers a different question: "what does
// this picture SAY". Keeping the two apart means:
//   * the quality bar can differ (a figure with 3 words can be a perfect read;
//     a transcription with 3 words is usually a failed one),
//   * downstream prompts can label it ("[Figure 1 — bar chart] …") so the model
//     knows it is reasoning about a picture the student drew, not prose they
//     wrote,
//   * escalation to a stronger model can be decided per-figure.

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// What kind of visual this is. Drives how [FigureDescription.toPromptBlock]
/// labels it, and lets features filter (e.g. a quiz generator may want charts
/// but not decorative sketches).
enum FigureKind {
  /// Bar/line/pie/scatter — data plotted against axes.
  chart,

  /// Boxes-and-arrows: flowchart, mind map, org chart, state machine.
  diagram,

  /// Rows and columns of values.
  table,

  /// A mathematical expression or derivation drawn rather than typed.
  equation,

  /// Anatomical/geometric/scientific labelled drawing.
  illustration,

  /// Read as visual content, but not confidently one of the above.
  unknown;

  static FigureKind parse(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    return FigureKind.values.firstWhere(
      (k) => k.name == v,
      orElse: () => switch (v) {
        'graph' || 'plot' || 'barchart' || 'bar chart' || 'histogram' =>
          FigureKind.chart,
        'flowchart' || 'mindmap' || 'mind map' || 'schematic' || 'tree' =>
          FigureKind.diagram,
        'formula' || 'expression' || 'math' => FigureKind.equation,
        'drawing' || 'sketch' || 'figure' => FigureKind.illustration,
        _ => FigureKind.unknown,
      },
    );
  }
}

/// One labelled data series or one named node/part within a figure.
@immutable
class FigureSeries {
  /// The series/node label as written on the page, e.g. 'Revenue' or 'Mitosis'.
  final String label;

  /// What this series does or holds, in the model's words — 'rises from 2 to
  /// 9 across the four quarters', 'feeds into Anaphase'. Empty when the model
  /// only managed to read the label.
  final String detail;

  const FigureSeries({required this.label, this.detail = ''});

  @override
  bool operator ==(Object other) =>
      other is FigureSeries && other.label == label && other.detail == detail;

  @override
  int get hashCode => Object.hash(label, detail);

  @override
  String toString() => detail.isEmpty ? label : '$label: $detail';
}

/// A structured reading of one figure.
///
/// Every field except [kind] and [summary] is best-effort: a hand-drawn mind map
/// has no axes, an equation has no series. Absent parts are empty, never
/// placeholder text, so [toPromptBlock] can simply omit them.
@immutable
class FigureDescription {
  final FigureKind kind;

  /// The figure's own title/caption if it has one, else ''.
  final String title;

  /// One or two sentences on what the figure shows — the load-bearing field,
  /// and the only one a downstream summary strictly needs.
  final String summary;

  /// Axis descriptions for charts, e.g. ['x: quarter (Q1–Q4)', 'y: revenue in
  /// thousands']. Empty for non-axial figures.
  final List<String> axes;

  /// Data series (charts) or named nodes/parts (diagrams, illustrations).
  final List<FigureSeries> series;

  /// The relationship or trend the figure exists to communicate — 'revenue
  /// roughly triples over the year', 'glycolysis precedes the Krebs cycle'.
  /// This is what a student would be asked about in an exam.
  final String insight;

  /// Text read verbatim off the figure (labels, values, annotations). Kept so
  /// nothing the OCR path would have caught is lost by routing through here.
  final String verbatimText;

  /// The model's own confidence, 0–1. Used to decide escalation to a stronger
  /// tier and to drop reads too poor to be worth showing.
  final double confidence;

  /// Machine id of the model that produced this, e.g. 'gemma-4-e2b-local' or
  /// 'cloud-gateway-cloud-mid' — surfaced in "which model read this" UI and
  /// invaluable when a bad description needs tracing.
  final String modelId;

  const FigureDescription({
    required this.kind,
    required this.summary,
    this.title = '',
    this.axes = const [],
    this.series = const [],
    this.insight = '',
    this.verbatimText = '',
    this.confidence = 0.0,
    this.modelId = '',
  });

  /// True when this read carries actual meaning rather than a shrug. A model
  /// that answers "a diagram" with no series, no insight and no title has told
  /// us nothing a bounding box didn't already say.
  bool get isInformative =>
      summary.trim().length >= 15 &&
      (series.isNotEmpty || insight.trim().isNotEmpty || title.trim().isNotEmpty);

  /// Renders the figure for an LLM prompt. Explicitly fenced and labelled so the
  /// downstream model treats it as a described picture — it must not quote this
  /// as if the student had written the words.
  ///
  /// [index] is 1-based; pass null for an unnumbered single figure.
  String toPromptBlock({int? index}) {
    final label = index == null ? 'Figure' : 'Figure $index';
    final heading =
        title.trim().isEmpty ? '[$label — ${kind.name}]' : '[$label — ${kind.name}: ${title.trim()}]';

    final lines = <String>[heading, summary.trim()];
    if (axes.isNotEmpty) lines.add('Axes: ${axes.join('; ')}');
    if (series.isNotEmpty) {
      lines.add('Series: ${series.map((s) => s.toString()).join('; ')}');
    }
    if (insight.trim().isNotEmpty) lines.add('Shows: ${insight.trim()}');
    if (verbatimText.trim().isNotEmpty) {
      lines.add('Labels on the figure: ${verbatimText.trim().replaceAll('\n', ' / ')}');
    }
    return lines.join('\n');
  }

  FigureDescription copyWith({double? confidence, String? modelId}) =>
      FigureDescription(
        kind: kind,
        title: title,
        summary: summary,
        axes: axes,
        series: series,
        insight: insight,
        verbatimText: verbatimText,
        confidence: confidence ?? this.confidence,
        modelId: modelId ?? this.modelId,
      );

  @override
  bool operator ==(Object other) =>
      other is FigureDescription &&
      other.kind == kind &&
      other.title == title &&
      other.summary == summary &&
      listEquals(other.axes, axes) &&
      listEquals(other.series, series) &&
      other.insight == insight &&
      other.verbatimText == verbatimText &&
      other.confidence == confidence &&
      other.modelId == modelId;

  @override
  int get hashCode => Object.hash(kind, title, summary, Object.hashAll(axes),
      Object.hashAll(series), insight, verbatimText, confidence, modelId);

  @override
  String toString() =>
      'FigureDescription(${kind.name}, "$summary", conf: $confidence, $modelId)';
}
