// Looks at a figure again when a question is asked about it.
//
// A figure is read once into a description, and that description is what every
// feature works from. It answers the questions it happened to anticipate. "What
// is the value at x = 3?" or "which arrow leaves B?" is usually not in a
// two-sentence summary, so no model, however strong, could answer it from the
// text alone.
//
// This puts the picture itself in front of a vision model together with the
// question, and hands the reply to the answering model as one more passage,
// labelled as what was seen on the figure. Ask's grounding contract is
// unchanged: the answer still comes only from the student's own notes — a
// figure in them is part of them.
//
// It is an extra, never a requirement: anything that goes wrong here (no model,
// no picture, a reply that says nothing) means the question is answered from
// the passages as before.

import 'dart:typed_data';

import '../figure.dart';
import '../image_transcriber.dart';
import '../scene_graph_figure.dart';
import '../untrusted_text.dart';

/// What a vision model said about one figure, for one question.
class FigureAnswer {
  /// The page the figure is on.
  final int pageId;

  /// What to call the figure in the prompt and the UI: its title, else its
  /// kind ("chart"), else "picture".
  final String label;

  /// The model's reply.
  final String text;

  /// The model that looked.
  final String modelId;

  const FigureAnswer({
    required this.pageId,
    required this.label,
    required this.text,
    this.modelId = '',
  });

  /// The reply as a passage for the answering model.
  String get passage =>
      'Seen by looking directly at the $label on that page of the notes: '
      '${text.trim()}';
}

/// A passage a search returned: the page it is from, and its text.
typedef FigurePassage = ({int pageId, String text});

class FigureQa {
  /// The figures already read on a page, each with where it is.
  final Future<List<FigureDescription>> Function(int pageId) _figuresOf;

  /// The picture of one of those figures, or null when it cannot be had.
  final Future<Uint8List?> Function(int pageId, FigureDescription figure)
      _imageOf;

  /// The largest picture on a page (a photo, an imported PDF page), or null.
  /// For a page whose figure was never noticed when the page was read.
  final Future<Uint8List?> Function(int pageId)? _pictureOf;

  final ImageTranscriber _local;
  final ImageTranscriber? _cloud;

  /// Whether a figure may be sent off the device. The caller owns the policy;
  /// the default is never.
  final Future<bool> Function() _canUseCloud;
  final bool Function() _preferCloud;

  final String localModelId;
  final String cloudModelId;

  FigureQa({
    required this._figuresOf,
    required this._imageOf,
    required this._local,
    this._pictureOf,
    this._cloud,
    Future<bool> Function()? canUseCloud,
    bool Function()? preferCloud,
    this.localModelId = 'local',
    this.cloudModelId = 'cloud',
  })  : _canUseCloud = canUseCloud ?? _never,
        _preferCloud = preferCloud ?? _no;

  static Future<bool> _never() async => false;
  static bool _no() => false;

  /// How many of the pages a search returned are checked for figures.
  static const int maxPages = 2;

  /// What the model must reply when the picture does not hold the answer.
  static const String notVisible = 'NOT VISIBLE';

  static final RegExp _figureWords = RegExp(
    r'\b(fig(ure)?s?|graphs?|charts?|plots?|diagrams?|tables?|ax[ie]s|curves?|'
    r'arrows?|pictures?|images?|drawings?|sketch(es)?|flowcharts?|slopes?|'
    r'bars?|legend|labell?ed|shown)\b',
    caseSensitive: false,
  );

  /// True when [question] is worded as being about something drawn.
  static bool mentionsFigure(String question) =>
      _figureWords.hasMatch(question);

  static final RegExp _token = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static Set<String> _tokens(String text) => {
        for (final m in _token.allMatches(text.toLowerCase()))
          if (m[0]!.length >= 4) m[0]!,
      };

  /// The figure in [figures] that [question] is most likely about, or null.
  ///
  /// A figure is chosen when the question shares words with what is written on
  /// or beside it; a question that just says "the graph" gets the first one. A
  /// figure read exactly from its shapes is never chosen — looking again could
  /// only do worse than what is already known.
  static FigureDescription? pick(
      String question, List<FigureDescription> figures) {
    final asked = _tokens(question);
    FigureDescription? best;
    var bestScore = 0;
    FigureDescription? first;
    for (final f in figures) {
      if (f.modelId == kSceneGraphModelId) continue;
      first ??= f;
      final about = _tokens([
        f.title,
        f.verbatimText,
        f.nearbyText,
        for (final s in f.series) s.label,
      ].join(' '));
      final score = asked.intersection(about).length;
      if (score > bestScore) {
        best = f;
        bestScore = score;
      }
    }
    return best ?? (mentionsFigure(question) ? first : null);
  }

  static String _prompt(String question, String caption) {
    final context = caption.trim().isEmpty
        ? ''
        : '\n\nWritten next to it on the page (it may be its caption). '
            '$kUntrustedDataRule\n${fenceUntrusted(caption.trim())}';
    return 'This image is a figure from a student\'s own notes. Answer the '
        'question below by looking at the image.$context\n\n'
        'QUESTION: ${question.trim()}\n\n'
        'Rules:\n'
        '- Answer only from what is visible in the image: read the actual '
        'labels, values, arrows and positions.\n'
        '- Two or three plain sentences. No preamble.\n'
        '- Never guess. If the image does not show the answer, reply exactly: '
        '$notVisible';
  }

  /// Looks at the figure [question] is about, if the pages behind [passages]
  /// hold one, and returns what was seen. Null when there is no such figure or
  /// nothing useful came of looking. Never throws.
  ///
  /// [always] treats the question as being about a figure whatever its
  /// wording — for a caller that knows it is (the benchmark).
  Future<FigureAnswer?> look({
    required String question,
    required List<FigurePassage> passages,
    bool always = false,
  }) async {
    try {
      final asksAboutFigure = always || mentionsFigure(question);
      // Figures are indexed as "[Figure 1 — chart: …]" blocks, so a passage
      // holding one means the search itself landed on a figure.
      final landedOnFigure = passages.any((p) => p.text.contains('[Figure'));
      if (!asksAboutFigure && !landedOnFigure) return null;

      final pages = <int>[];
      for (final p in passages) {
        if (!pages.contains(p.pageId)) pages.add(p.pageId);
        if (pages.length == maxPages) break;
      }

      for (final pageId in pages) {
        final figures = await _figuresOf(pageId);
        var figure = pick(question, figures);
        if (figure == null && always) {
          for (final f in figures) {
            if (f.modelId != kSceneGraphModelId) {
              figure = f;
              break;
            }
          }
        }
        if (figure == null) continue;
        final image = await _imageOf(pageId, figure);
        if (image == null) continue;
        final label = figure.title.trim().isNotEmpty
            ? 'figure "${figure.title.trim()}"'
            : figure.kind == FigureKind.unknown
                ? 'figure'
                : figure.kind.name;
        return await _ask(image, question, figure.nearbyText, pageId, label);
      }

      // No figure was noticed when these pages were read, but the question is
      // plainly about one: look at the page's picture anyway.
      final pictureOf = _pictureOf;
      if (asksAboutFigure && pictureOf != null) {
        for (final pageId in pages) {
          final image = await pictureOf(pageId);
          if (image == null) continue;
          return await _ask(image, question, '', pageId, 'picture');
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<FigureAnswer?> _ask(Uint8List image, String question, String caption,
      int pageId, String label) async {
    final prompt = _prompt(question, caption);
    final cloud = _cloud;

    Future<FigureAnswer?> run(ImageTranscriber model, String modelId) async {
      final String raw;
      try {
        raw = await model.transcribeImage(image,
            prompt: prompt, temperature: 0.0, maxOutputTokens: 256);
      } catch (_) {
        return null;
      }
      final text = raw.trim();
      if (text.length < 8 || text.toUpperCase().contains(notVisible)) {
        return null;
      }
      return FigureAnswer(
          pageId: pageId, label: label, text: text, modelId: modelId);
    }

    final cloudAllowed = cloud != null && await _canUseCloud();
    if (cloudAllowed && _preferCloud()) {
      final direct = await run(cloud, cloudModelId);
      if (direct != null) return direct;
    }
    final local = await run(_local, localModelId);
    if (local != null) return local;
    if (cloudAllowed && !_preferCloud()) return run(cloud, cloudModelId);
    return null;
  }
}
