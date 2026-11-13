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

import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'figure_detail.dart';

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

/// The `modelId` of a figure whose description the student wrote themselves.
const String kUserFigureModelId = 'user';

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

  /// Where the figure sits on the page, in scene units; null when unknown. Not
  /// part of what was read — the same drawing moved elsewhere is the same
  /// figure — so it is set by the page reader after the read, never cached.
  /// With it a feature can show "the AI is looking at this" and render the
  /// figure again to put the picture itself in front of a model.
  final Rect? bounds;

  /// The picture this figure was read from, relative to app documents, when it
  /// is a pasted image or an imported page; '' for something drawn on the page
  /// (which is re-rendered from [bounds] instead). Set like [bounds].
  final String imagePath;

  /// Writing found beside the figure — a caption, the sentence pointing at it —
  /// that was given to the model as context. '' when there was none.
  final String nearbyText;

  /// How much of what the description names was confirmed against text read
  /// independently of the vision model (typed labels, the PDF's own text,
  /// handwriting recognition): 0–1, or null when there was nothing to check
  /// against. A model's own [confidence] is a guess about itself; this is not.
  final double? grounding;

  /// Where a replacement reading of this figure is kept (see
  /// `PageContentExtractor.rereadFigure`): '' when it cannot be replaced —
  /// nothing is stored, or the figure was read exactly from its shapes. Set by
  /// the page reader, like [bounds].
  final String pinKey;

  /// An equation (or a derivation, one step per line) written out as LaTeX,
  /// without delimiters; '' when the figure is not mathematics or it could not
  /// be transcribed. See `figure_detail.dart`.
  final String latex;

  /// A table's own rows and columns; null when the figure is not a table or
  /// its grid could not be read reliably.
  final FigureTable? table;

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
    this.bounds,
    this.imagePath = '',
    this.nearbyText = '',
    this.grounding,
    this.pinKey = '',
    this.latex = '',
    this.table,
  });

  /// This figure as the student describes it. Their words replace the model's
  /// summary and the conclusion it drew; the labels read off the figure stay.
  /// Nothing about it is in doubt afterwards.
  FigureDescription correctedTo({required String title, required String summary}) =>
      FigureDescription(
        kind: kind,
        title: title.trim(),
        summary: summary.trim(),
        axes: axes,
        series: series,
        verbatimText: verbatimText,
        confidence: 1.0,
        modelId: kUserFigureModelId,
        bounds: bounds,
        imagePath: imagePath,
        nearbyText: nearbyText,
        pinKey: pinKey,
        latex: latex,
        table: table,
      );

  /// Below this share of confirmed labels a reading is treated as unconfirmed.
  static const double minGrounding = 0.34;

  /// True when the reading was checked against the page's own text and mostly
  /// failed: the model named things that are not written there. Kept (it may
  /// still be roughly right) but flagged, in prompts and in the UI.
  bool get isUncertain => grounding != null && grounding! < minGrounding;

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
    if (latex.isNotEmpty) {
      lines.add('Written out: '
          '${latex.split('\n').map((l) => '\$\$$l\$\$').join(' ')}');
    }
    if (table != null) lines.add('As a table:\n${table!.toMarkdown()}');
    if (isUncertain) {
      lines.add('Note: this reading could not be confirmed against the text on '
          'the page. Treat its details as approximate and say so if you use them.');
    }
    return lines.join('\n');
  }

  /// The figure as plain JSON, for the read cache. [fromJson] is its inverse.
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'title': title,
        'summary': summary,
        'axes': axes,
        'series': [
          for (final s in series) {'label': s.label, 'detail': s.detail},
        ],
        'insight': insight,
        'verbatimText': verbatimText,
        'confidence': confidence,
        'modelId': modelId,
        if (nearbyText.isNotEmpty) 'nearbyText': nearbyText,
        'grounding': ?grounding,
        if (latex.isNotEmpty) 'latex': latex,
        if (table != null) 'table': table!.toJson(),
      };

  /// Reads a figure back from [toJson]'s output, or null when [json] is not a
  /// usable figure — a cache entry must never be able to take a page read down
  /// with it, so damage reads as "nothing cached" rather than throwing.
  static FigureDescription? fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    if (summary is! String || summary.trim().isEmpty) return null;

    List<String> strings(Object? v) =>
        v is List ? [for (final e in v) if (e is String) e] : const [];

    final series = <FigureSeries>[];
    final rawSeries = json['series'];
    if (rawSeries is List) {
      for (final entry in rawSeries) {
        if (entry is Map && entry['label'] is String) {
          series.add(FigureSeries(
            label: entry['label'] as String,
            detail: entry['detail'] is String ? entry['detail'] as String : '',
          ));
        }
      }
    }

    final confidence = json['confidence'];
    return FigureDescription(
      kind: FigureKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => FigureKind.unknown,
      ),
      title: json['title'] is String ? json['title'] as String : '',
      summary: summary,
      axes: strings(json['axes']),
      series: series,
      insight: json['insight'] is String ? json['insight'] as String : '',
      verbatimText:
          json['verbatimText'] is String ? json['verbatimText'] as String : '',
      confidence: confidence is num ? confidence.toDouble() : 0.0,
      modelId: json['modelId'] is String ? json['modelId'] as String : '',
      nearbyText: json['nearbyText'] is String ? json['nearbyText'] as String : '',
      grounding: json['grounding'] is num
          ? (json['grounding'] as num).toDouble()
          : null,
      latex: json['latex'] is String ? json['latex'] as String : '',
      table: FigureTable.fromJson(json['table']),
    );
  }

  FigureDescription copyWith({
    double? confidence,
    String? modelId,
    Rect? bounds,
    String? imagePath,
    String? nearbyText,
    double? grounding,
    String? pinKey,
    String? latex,
    FigureTable? table,
  }) =>
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
        bounds: bounds ?? this.bounds,
        imagePath: imagePath ?? this.imagePath,
        nearbyText: nearbyText ?? this.nearbyText,
        grounding: grounding ?? this.grounding,
        pinKey: pinKey ?? this.pinKey,
        latex: latex ?? this.latex,
        table: table ?? this.table,
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
      other.modelId == modelId &&
      other.bounds == bounds &&
      other.imagePath == imagePath &&
      other.nearbyText == nearbyText &&
      other.grounding == grounding &&
      other.pinKey == pinKey &&
      other.latex == latex &&
      other.table == table;

  @override
  int get hashCode => Object.hash(kind, title, summary, Object.hashAll(axes),
      Object.hashAll(series), insight, verbatimText, confidence, modelId,
      bounds, imagePath, nearbyText, grounding, pinKey, latex, table);

  @override
  String toString() =>
      'FigureDescription(${kind.name}, "$summary", conf: $confidence, $modelId)';
}
