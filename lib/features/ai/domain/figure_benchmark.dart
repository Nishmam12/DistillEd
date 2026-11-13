// Measures how well figures are understood, on real pages, so decisions about
// models and thresholds rest on numbers rather than impressions.
//
// The benchmark set is an ordinary notebook. Each page holds a figure (drawn,
// pasted or an imported PDF page) and one or more typed text boxes of the form
//
//     Q: What is the value in Q3?
//     A: 40
//
// A box may hold several Q/A pairs. `A:` may list alternatives with `|`
// ("40 | forty"). The boxes are taken off the page before it is read, so the
// answer is never in front of the model.
//
// Every question is then answered three ways and timed:
//   * from the description — the text every AI feature works from today;
//   * by looking, on the device — the figure and the question to the local VLM;
//   * by looking, in the cloud — the same, to the stronger model (when allowed).
// The gap between the first and second says what looking again buys; between
// the second and third, what the cloud buys.
//
// Pure, with the models and the page reader behind functions.

import 'dart:typed_data';

import '../../../domain/model/scene_element.dart';
import 'features/figure_qa.dart';
import 'figure.dart';
import 'image_transcriber.dart';
import 'page_content.dart';

/// One question about one page, with the answer a correct reply must contain.
class BenchQuestion {
  final String question;

  /// Acceptable answers; a reply matching any one is correct.
  final List<String> accepted;

  const BenchQuestion(this.question, this.accepted);
}

final RegExp _qa = RegExp(r'^\s*([QA])\s*[:.)]\s*(.*)$', caseSensitive: false);

/// The questions written on a page, and the ids of the text boxes holding
/// them (to be left out of the read).
({List<BenchQuestion> questions, Set<String> boxIds}) benchQuestionsOf(
    List<SceneElement> elements) {
  final questions = <BenchQuestion>[];
  final boxIds = <String>{};
  for (final e in elements) {
    if (e is! TextElement) continue;
    String? pending;
    var found = false;
    for (final line in e.text.split('\n')) {
      final m = _qa.firstMatch(line);
      if (m == null) continue;
      final body = m[2]!.trim();
      if (m[1]!.toUpperCase() == 'Q') {
        pending = body;
      } else if (pending != null && pending.isNotEmpty && body.isNotEmpty) {
        questions.add(BenchQuestion(pending, [
          for (final a in body.split('|'))
            if (a.trim().isNotEmpty) a.trim(),
        ]));
        pending = null;
        found = true;
      }
    }
    if (found) boxIds.add(e.id);
  }
  return (questions: questions, boxIds: boxIds);
}

final RegExp _benchToken = RegExp(r'[\p{L}]+|\d+(?:\.\d+)?', unicode: true);

List<String> _benchTokens(String text) => [
      for (final m in _benchToken.allMatches(text.toLowerCase().replaceAll(',', '')))
        // "40.0" and "40" are the same number.
        double.tryParse(m[0]!) != null
            ? double.parse(m[0]!).toString()
            : m[0]!,
    ];

/// True when [reply] contains every word and number of one of [accepted].
/// Deliberately strict about numbers and forgiving about wording: "It reaches
/// 40 in the third quarter" matches "40"; "about 45" does not. A word matches
/// its plural ("arrow" / "arrows").
bool benchAnswerMatches(String reply, List<String> accepted) {
  final said = _benchTokens(reply);
  bool has(String want) => said.any((s) =>
      s == want ||
      (want.length >= 4 &&
          double.tryParse(want) == null &&
          (s.startsWith(want) || want.startsWith(s)) &&
          (s.length - want.length).abs() <= 2 &&
          s.length >= 4));
  for (final answer in accepted) {
    final wanted = _benchTokens(answer);
    if (wanted.isNotEmpty && wanted.every(has)) return true;
  }
  return false;
}

enum BenchTier {
  description('From the description'),
  lookLocal('Looking, on device'),
  lookCloud('Looking, cloud');

  const BenchTier(this.label);
  final String label;
}

/// One question answered one way.
class BenchResult {
  final int pageNumber;
  final BenchQuestion question;
  final BenchTier tier;

  /// What came back; '' when nothing did.
  final String reply;
  final bool correct;
  final Duration time;

  const BenchResult({
    required this.pageNumber,
    required this.question,
    required this.tier,
    required this.reply,
    required this.correct,
    required this.time,
  });
}

/// How one page was read before its questions were asked.
class BenchPageRead {
  final int pageNumber;
  final int figures;
  final int uncertain;
  final Duration time;
  final String? error;

  const BenchPageRead({
    required this.pageNumber,
    required this.figures,
    required this.uncertain,
    required this.time,
    this.error,
  });
}

class BenchReport {
  final List<BenchPageRead> pages;
  final List<BenchResult> results;
  final List<BenchTier> tiers;

  const BenchReport(
      {required this.pages, required this.results, required this.tiers});

  List<BenchResult> of(BenchTier tier) =>
      [for (final r in results) if (r.tier == tier) r];

  int correct(BenchTier tier) => of(tier).where((r) => r.correct).length;

  /// The middle time for [tier], or zero with no results.
  Duration median(BenchTier tier) {
    final times = [for (final r in of(tier)) r.time]..sort();
    return times.isEmpty ? Duration.zero : times[times.length ~/ 2];
  }

  static String _secs(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';

  /// The whole run as plain text, to copy out of the app.
  String toText() {
    final out = StringBuffer('Margo figure benchmark\n');
    final readTimes = [for (final p in pages) p.time]..sort();
    out.writeln('Pages: ${pages.length}, questions: '
        '${tiers.isEmpty ? 0 : of(tiers.first).length}, figures found: '
        '${pages.fold<int>(0, (n, p) => n + p.figures)} '
        '(${pages.fold<int>(0, (n, p) => n + p.uncertain)} not confirmed)');
    if (readTimes.isNotEmpty) {
      out.writeln('Page read, median: ${_secs(readTimes[readTimes.length ~/ 2])} '
          '(near zero when a page was read before and is remembered)');
    }
    out.writeln();
    for (final tier in tiers) {
      final all = of(tier);
      out.writeln('${tier.label}: ${correct(tier)}/${all.length} correct, '
          'median ${_secs(median(tier))}');
    }
    for (final p in pages) {
      out.writeln('\nPage ${p.pageNumber}: ${p.figures} figure(s), read in '
          '${_secs(p.time)}${p.error == null ? '' : ' — ${p.error}'}');
      for (final r in results.where((r) => r.pageNumber == p.pageNumber)) {
        out.writeln('  [${r.correct ? 'ok' : 'XX'}] ${r.tier.label} '
            '(${_secs(r.time)})');
        out.writeln('       Q: ${r.question.question}');
        out.writeln('       want: ${r.question.accepted.join(' | ')}');
        out.writeln('       got: '
            '${r.reply.trim().isEmpty ? '(nothing)' : r.reply.trim().replaceAll('\n', ' ')}');
      }
    }
    return out.toString();
  }
}

class FigureBenchmark {
  final Future<List<SceneElement>> Function(int pageId) loadElements;

  /// A deep read of the given elements (the page without its Q/A boxes).
  final Future<PageContent> Function(List<SceneElement> elements) readPage;

  /// The picture of a figure found among those elements, and the largest
  /// picture among them — see `PageContentExtractor.figureImageFrom`.
  final Future<Uint8List?> Function(
      List<SceneElement> elements, FigureDescription figure) imageOf;
  final Future<Uint8List?> Function(List<SceneElement> elements) pictureOf;

  /// Answers [question] from [notes] alone, with the text model.
  final Future<String> Function(String notes, String question) answerFromText;

  final ImageTranscriber local;

  /// Null leaves the cloud tier out.
  final ImageTranscriber? cloud;

  const FigureBenchmark({
    required this.loadElements,
    required this.readPage,
    required this.imageOf,
    required this.pictureOf,
    required this.answerFromText,
    required this.local,
    this.cloud,
  });

  List<BenchTier> get tiers => [
        BenchTier.description,
        BenchTier.lookLocal,
        if (cloud != null) BenchTier.lookCloud,
      ];

  /// Runs every question on [pageIds] (in order; page numbers are 1-based
  /// positions in that list). [onProgress] gets a line as each step starts.
  /// [isCancelled] is checked between steps. Never throws: a page or a
  /// question that fails is recorded as failed.
  Future<BenchReport> run(
    List<int> pageIds, {
    void Function(String status)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final pages = <BenchPageRead>[];
    final results = <BenchResult>[];
    bool stop() => isCancelled?.call() ?? false;

    for (var i = 0; i < pageIds.length && !stop(); i++) {
      final number = i + 1;
      List<SceneElement> rest;
      List<BenchQuestion> questions;
      try {
        final all = await loadElements(pageIds[i]);
        final found = benchQuestionsOf(all);
        questions = found.questions;
        rest = [for (final e in all) if (!found.boxIds.contains(e.id)) e];
      } catch (e) {
        continue;
      }
      if (questions.isEmpty) continue; // not a benchmark page

      onProgress?.call('Page $number: reading');
      final watch = Stopwatch()..start();
      PageContent content;
      String? error;
      try {
        content = await readPage(rest);
      } catch (e) {
        content = PageContent.empty;
        error = '$e';
      }
      pages.add(BenchPageRead(
        pageNumber: number,
        figures: content.figures.length,
        uncertain: content.figures.where((f) => f.isUncertain).length,
        time: watch.elapsed,
        error: error,
      ));

      for (final q in questions) {
        if (stop()) break;
        for (final tier in tiers) {
          if (stop()) break;
          onProgress?.call('Page $number: ${tier.label.toLowerCase()} — '
              '${q.question}');
          final t = Stopwatch()..start();
          var reply = '';
          try {
            reply = switch (tier) {
              BenchTier.description => await answerFromText(
                  content.combinedTextWithFigures, q.question),
              BenchTier.lookLocal =>
                await _look(local, rest, content, q.question),
              BenchTier.lookCloud =>
                await _look(cloud!, rest, content, q.question),
            };
          } catch (_) {
            // Recorded as no reply.
          }
          results.add(BenchResult(
            pageNumber: number,
            question: q,
            tier: tier,
            reply: reply,
            correct: benchAnswerMatches(reply, q.accepted),
            time: t.elapsed,
          ));
        }
      }
    }
    return BenchReport(pages: pages, results: results, tiers: tiers);
  }

  /// The product's own "look at the figure" path, pointed at one model.
  Future<String> _look(ImageTranscriber model, List<SceneElement> elements,
      PageContent content, String question) async {
    final qa = FigureQa(
      figuresOf: (_) async => content.figures,
      imageOf: (_, figure) => imageOf(elements, figure),
      pictureOf: (_) => pictureOf(elements),
      local: model,
    );
    // Every benchmark question is about the figure, whatever its wording.
    final seen = await qa.look(
      question: question,
      passages: const [(pageId: 0, text: '[Figure')],
      always: true,
    );
    return seen?.text ?? '';
  }
}
