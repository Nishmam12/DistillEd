// Reads charts, diagrams, tables and equations off a page image — the pass that
// makes drawn graphs visible to every AI feature.
//
// This is a SECOND, separate vision call from [GemmaVisionOcrService], not a
// replacement for it. OCR asks "what words are here" and is gated on looking
// like prose; a figure asks "what does this picture mean" and is gated on
// carrying an actual insight. Running them apart is what lets a bar chart with
// four words survive a quality bar that would (correctly) reject a four-word
// handwriting transcription as a failed read.
//
// Tiering, per the product rule "use the offline model when it is capable
// enough, the cloud when it is not":
//   1. the on-device VLM (Gemma 4 E2B, vision encoder) always reads first;
//   2. its answer is judged — parseable? informative? confident enough?;
//   3. only a read that FAILS that judgement escalates to the cloud tier, and
//      only when the caller says escalation is permitted (user cloud opt-in +
//      online, decided by the caller — this class never inspects settings).
// A page that reads well locally therefore never leaves the device, which keeps
// the privacy default intact while still fixing the hard figures.

import 'dart:convert';
import 'dart:typed_data';

import 'ai_exception.dart';
import 'figure.dart';
import 'image_transcriber.dart';

/// Decides whether a local read is good enough to keep, or whether the cloud
/// should be asked instead. Separated from the analyzer so the bar is tunable
/// and testable without a model.
class FigureQualityBar {
  /// Below this self-reported confidence a local read is treated as shaky.
  final double minConfidence;

  const FigureQualityBar({this.minConfidence = 0.55});

  /// True when [figure] is worth keeping without asking a stronger model.
  bool accepts(FigureDescription? figure) =>
      figure != null && figure.isInformative && figure.confidence >= minConfidence;
}

class FigureAnalyzer {
  /// The on-device VLM. Always tried first.
  final ImageTranscriber _local;

  /// A stronger vision backend used ONLY when the local read misses the bar and
  /// the caller permits escalation. Null on builds/tests with no cloud wiring —
  /// the analyzer then simply keeps or drops the local read.
  final ImageTranscriber? _cloud;

  /// Asked before every escalation. The caller owns the policy (cloud opt-in,
  /// reachability, per-day budget); this class only obeys it. Defaults to
  /// "never escalate" so a misconfigured wiring cannot leak a page to the
  /// network.
  final Future<bool> Function() _canEscalate;

  final FigureQualityBar _bar;

  /// Machine ids recorded on the produced description, for "which model read
  /// this" surfacing.
  final String localModelId;
  final String cloudModelId;

  FigureAnalyzer({
    required ImageTranscriber local,
    ImageTranscriber? cloud,
    Future<bool> Function()? canEscalate,
    FigureQualityBar bar = const FigureQualityBar(),
    this.localModelId = 'local',
    this.cloudModelId = 'cloud',
  })  : _local = local,
        _cloud = cloud,
        _canEscalate = canEscalate ?? _never,
        _bar = bar;

  static Future<bool> _never() async => false;

  /// Asks for a strict JSON object. Gemma-class models comply far more reliably
  /// when the schema is shown literally and the "no prose" rule is repeated at
  /// the end, which is why the shape is spelled out rather than described.
  ///
  /// The `"kind": "none"` escape is load-bearing: it is how a plain page of
  /// handwriting — which this pass also gets pointed at — reports "there is no
  /// figure here" instead of inventing one.
  static const String _prompt = '''
You are analysing an image from a student's notebook page. Decide whether it contains a CHART, DIAGRAM, TABLE, EQUATION or labelled ILLUSTRATION.

If it contains ONLY prose, handwriting, or plain text with no such visual, reply exactly:
{"kind": "none"}

Otherwise reply with ONLY this JSON object:
{
  "kind": "chart|diagram|table|equation|illustration",
  "title": "the figure's caption or title, or empty string",
  "summary": "one or two sentences on what this figure shows",
  "axes": ["x: what it measures and its range", "y: what it measures and its range"],
  "series": [{"label": "name as written", "detail": "what it does across the figure"}],
  "insight": "the single relationship, trend or process the figure communicates",
  "verbatim_text": "every label, number and annotation you can read, newline separated",
  "confidence": 0.0
}

Rules:
- "axes" only for charts; use [] otherwise.
- "series" holds plotted series for charts, or the named boxes/nodes/parts for diagrams and illustrations.
- Read actual values and labels off the image. Never invent data you cannot see.
- "confidence" is your own honest 0.0-1.0 rating of how well you could read it.
- Output the JSON object and nothing else. No markdown fences, no commentary.''';

  /// A blunter retry for the escalated call — a stronger model needs less
  /// coaxing on format, so this spends its words on reading accuracy instead.
  static const String _cloudPrompt = '''
Analyse this image from a student's notebook and describe the chart, diagram, table, equation or labelled illustration it contains.

Reply with ONLY a JSON object with keys: kind (chart|diagram|table|equation|illustration|none), title, summary, axes (array of strings), series (array of {label, detail}), insight, verbatim_text, confidence (0.0-1.0).

Read the real values, labels and relationships off the image — precision matters more than completeness. If the image holds no such visual, reply {"kind": "none"}. No markdown fences, no commentary.''';

  /// Analyses [imageBytes], returning null when the image holds no figure, when
  /// every attempt failed to produce a usable reading, or when a read too poor
  /// to be worth showing could not be escalated.
  ///
  /// Rethrows [AiModelNotReadyException] from the LOCAL model so the caller can
  /// offer the download — the same contract [GemmaVisionOcrService] follows. A
  /// cloud failure is never fatal: it degrades to the local read.
  Future<FigureDescription?> analyze(Uint8List imageBytes) async {
    final local = await _readLocal(imageBytes);
    if (_bar.accepts(local)) return local;

    // The local model either produced nothing, produced a shrug, or told us it
    // was unsure. That is exactly the case the cloud tier exists for.
    if (_cloud != null && await _canEscalate()) {
      final escalated = await _readCloud(imageBytes);
      if (escalated != null && escalated.isInformative) return escalated;
    }

    // No cloud available or it did no better. Keep a merely-unconfident local
    // read if it still says something real; drop an uninformative one rather
    // than polluting a summary with "this is a diagram".
    return (local != null && local.isInformative) ? local : null;
  }

  Future<FigureDescription?> _readLocal(Uint8List imageBytes) async {
    final String raw;
    try {
      raw = await _local.transcribeImage(
        imageBytes,
        prompt: _prompt,
        // Deterministic: this is an extraction task, and sampling mostly buys
        // malformed JSON.
        temperature: 0.0,
        maxOutputTokens: 1024,
      );
    } on AiModelNotReadyException {
      rethrow;
    } on AiException {
      return null; // a failed local run is an escalation trigger, not an error
    }
    return parseFigureJson(raw, modelId: localModelId);
  }

  Future<FigureDescription?> _readCloud(Uint8List imageBytes) async {
    final cloud = _cloud;
    if (cloud == null) return null;
    try {
      final raw = await cloud.transcribeImage(
        imageBytes,
        prompt: _cloudPrompt,
        temperature: 0.0,
        maxOutputTokens: 1536,
      );
      return parseFigureJson(raw, modelId: cloudModelId);
    } on AiException {
      // Offline, rate-limited, gateway down — the local read stands.
      return null;
    }
  }

  /// Parses a model's raw reply into a [FigureDescription], or null when it
  /// declared no figure ("kind": "none") or emitted something unusable.
  ///
  /// Public and static so the prompt/parse contract can be tested without a
  /// model, and so the cloud client can reuse the exact same leniency.
  static FigureDescription? parseFigureJson(String raw, {String modelId = ''}) {
    final json = _extractJsonObject(raw);
    if (json == null) return null;

    final kindRaw = (json['kind'] as Object?)?.toString().trim().toLowerCase();
    if (kindRaw == null || kindRaw.isEmpty || kindRaw == 'none' || kindRaw == 'null') {
      return null;
    }

    final summary = _str(json['summary']);
    final insight = _str(json['insight']);
    final title = _str(json['title']);
    // A reply with no prose at all is a failed parse dressed as a success.
    if (summary.isEmpty && insight.isEmpty && title.isEmpty) return null;

    return FigureDescription(
      kind: FigureKind.parse(kindRaw),
      title: title,
      summary: summary,
      axes: _strList(json['axes']),
      series: _seriesList(json['series']),
      insight: insight,
      verbatimText: _str(json['verbatim_text']),
      confidence: _confidence(json['confidence']),
      modelId: modelId,
    );
  }

  /// Pulls the first balanced `{...}` out of [raw]. Models wrap JSON in
  /// ```json fences, prefix it with "Here is the analysis:", or append a
  /// trailing note — brace matching survives all three, where a plain
  /// `jsonDecode` of the whole reply does not. String-aware so a brace inside a
  /// label ("cost {USD}") cannot end the scan early.
  static Map<String, dynamic>? _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < raw.length; i++) {
      final c = raw[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == r'\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          try {
            final decoded = jsonDecode(raw.substring(start, i + 1));
            return decoded is Map<String, dynamic> ? decoded : null;
          } on FormatException {
            return null;
          }
        }
      }
    }
    return null;
  }

  static String _str(Object? v) => v == null ? '' : v.toString().trim();

  static List<String> _strList(Object? v) {
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (_str(e).isNotEmpty) _str(e),
    ];
  }

  static List<FigureSeries> _seriesList(Object? v) {
    if (v is! List) return const [];
    final out = <FigureSeries>[];
    for (final e in v) {
      if (e is Map) {
        final label = _str(e['label']);
        // Models sometimes emit {"name": ...} or a bare string despite the
        // schema; take what is there rather than dropping a real series.
        final fallback = _str(e['name']);
        final resolved = label.isNotEmpty ? label : fallback;
        if (resolved.isEmpty) continue;
        out.add(FigureSeries(label: resolved, detail: _str(e['detail'])));
      } else {
        final label = _str(e);
        if (label.isNotEmpty) out.add(FigureSeries(label: label));
      }
    }
    return out;
  }

  /// Accepts 0–1 floats, ints, percentages ("85") and strings. Anything
  /// unparseable becomes 0.5 — neutral, so a model that simply omits the field
  /// is not punished into a needless cloud call.
  static double _confidence(Object? v) {
    if (v == null) return 0.5;
    final parsed = v is num ? v.toDouble() : double.tryParse(v.toString().trim());
    if (parsed == null) return 0.5;
    if (parsed > 1.0) return (parsed / 100.0).clamp(0.0, 1.0);
    return parsed.clamp(0.0, 1.0);
  }
}
