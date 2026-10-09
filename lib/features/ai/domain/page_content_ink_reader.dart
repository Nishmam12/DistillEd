part of 'page_content_extractor.dart';

/// Handwriting and image-element reading, split out of [PageContentExtractor].
extension _InkReading on PageContentExtractor {
  /// Reads a page's handwriting.
  ///
  /// On a deep read (vision wired) the default is ML Kit FIRST: it reads the
  /// page line by line in milliseconds with no model load, and Gemma vision is
  /// sent only the lines ML Kit cannot be trusted on, cropped to those lines —
  /// so most handwritten pages never load the 2.6 GB model at all. A Re-read
  /// (vary) skips that and reads the whole page with Gemma, which is what asking
  /// to read it again means.
  ///
  /// Otherwise — flag off, Re-read, or ML Kit cannot carry the page — Gemma
  /// vision (rendered ink → transcription) is primary and ML Kit digital-ink the
  /// fallback, used when Gemma isn't available for this read or read the page
  /// poorly. Gemma's best-effort text is kept only when ML Kit turns up nothing.
  Future<({String text, double? score, bool plainText})> _readInk(
    List<SceneElement> inkElements,
    List<SceneElement> allElements,
    String languageCode,
    GemmaVisionOcrService? vision,
    bool vary,
  ) async {
    final render = _renderInk;
    if (vision != null && render != null) {
      if (_mlKitFirstInk && !vary) {
        final refined = await _readInkMlKitFirst(
            inkElements, languageCode, vision, render);
        if (refined != null) return refined;
        // null: ML Kit cannot carry this page (nothing read, or too much of it
        // is weak), so it goes to Gemma whole, below.
      }
      final png = await render(inkElements);
      if (png != null) {
        final cacheKey = _cacheOn
            ? _cacheKey('ink', png, GemmaVisionOcrService.cacheVersion)
            : null;
        final remembered = cacheKey == null
            ? null
            : await _remembered(cacheKey, vary: vary);
        if (remembered != null) {
          return (text: remembered.text, score: null, plainText: false);
        }

        final result = await vision.read(png, vary: vary);
        if (result.passed) {
          if (cacheKey != null) {
            await _remember(cacheKey, CachedRead(text: result.text));
          }
          return (text: result.text, score: null, plainText: false);
        }
        final ml = await _recognition.recognizeElements(allElements, languageCode);
        final mlText = ml.text.trim();
        return mlText.isNotEmpty
            ? (text: mlText, score: ml.topScore, plainText: false)
            : (text: result.text, score: null, plainText: false);
      }
    }
    final ml = await _recognition.recognizeElements(allElements, languageCode);
    return (text: ml.text, score: ml.topScore, plainText: false);
  }

  /// More separate regions than this and one whole-page read is cheaper than a
  /// model call apiece.
  static const int _maxRefineRegions = 3;

  /// Tokens a region read may use: a little headroom per line over what a line
  /// of handwriting needs, so a two-line crop is not allowed a page's worth.
  static int _regionTokens(int lineCount) =>
      (96 + 48 * lineCount).clamp(128, GemmaVisionOcrService.pageReadTokens);

  /// The ML-Kit-first read: one pass over the page's lines, then Gemma for the
  /// lines that need it. Returns null when ML Kit cannot carry the page, which
  /// sends the caller to the whole-page Gemma read.
  Future<({String text, double? score, bool plainText})?> _readInkMlKitFirst(
    List<SceneElement> inkElements,
    String languageCode,
    GemmaVisionOcrService vision,
    InkImageRenderer render,
  ) async {
    final lines =
        await _recognition.recognizeInkLines(inkElements, languageCode);
    final withText = [
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line,
    ];
    // Not a doodle: if NO line reads, ML Kit is the wrong tool for this
    // handwriting and the page must not come back empty.
    if (withText.isEmpty) return null;

    final median = _medianLineHeight(withText);
    final weak = <int>[
      for (var i = 0; i < lines.length; i++)
        if (inkLineNeedsVision(
          text: lines[i].text,
          score: lines[i].score,
          lineHeight: lines[i].bounds.height,
          medianLineHeight: median,
        ))
          i,
    ];

    final regions = _runsOf(weak);
    // Mostly weak, or many separate regions: ML Kit is struggling with this
    // hand, and one page read beats a handful of small ones.
    if (weak.length * 2 > withText.length || regions.length > _maxRefineRegions) {
      return null;
    }

    // Each weak region is read by Gemma from a crop of just its strokes.
    final elementOf = Map<List<StrokePoint>, FreehandElement>.identity();
    for (final e in inkElements) {
      if (e is FreehandElement) elementOf[e.points] = e;
    }
    final replacement = <int, String>{}; // a region's first line → its text
    final kept = <RecognizedInkLine>[]; // lines whose ML Kit text stands
    final inRegion = <int>{};
    for (final region in regions) {
      inRegion.addAll(region);
      final regionLines = [for (final i in region) lines[i]];
      final mlText = regionLines
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n');

      final png = await render([
        for (final line in regionLines)
          for (final stroke in line.strokes) elementOf[stroke]!,
      ]);

      // Keyed by the crop itself, so the same handwriting is never sent twice
      // — and moving it on the page does not matter, since the crop is tight.
      final cacheKey = _cacheOn && png != null
          ? _cacheKey('ink', png, GemmaVisionOcrService.cacheVersion)
          : null;
      final remembered =
          cacheKey == null ? null : await _remembered(cacheKey, vary: false);

      GemmaOcrResult? read;
      if (remembered == null && png != null) {
        read = await vision.read(png,
            maxOutputTokens: _regionTokens(regionLines.length));
        if (read.passed && cacheKey != null) {
          await _remember(cacheKey, CachedRead(text: read.text));
        }
      }

      if (remembered != null) {
        replacement[region.first] = remembered.text;
      } else if (read != null && read.passed) {
        replacement[region.first] = read.text;
      } else {
        // Gemma failed the gate, or the crop could not be drawn: ML Kit's
        // reading, however poor, beats losing the lines. (A weak line always
        // HAS ML Kit text — a line that read as nothing is never "weak" — so
        // there is something to keep.)
        replacement[region.first] = mlText;
        kept.addAll(regionLines);
      }
    }

    final parts = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (inRegion.contains(i)) {
        final text = replacement[i]; // only a region's first line carries it
        if (text != null && text.trim().isNotEmpty) parts.add(text.trim());
      } else if (lines[i].text.trim().isNotEmpty) {
        parts.add(lines[i].text.trim());
        kept.add(lines[i]);
      }
    }

    final scores = [for (final line in kept) ...line.segmentScores];
    return (
      text: parts.join('\n'),
      score: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      // Every stroke read as text and none of it needed the model: this is
      // handwriting, not a drawing.
      plainText: regions.isEmpty && withText.length == lines.length,
    );
  }

  /// The page's typical line height — what "unusually tall" is measured against.
  static double _medianLineHeight(List<RecognizedInkLine> lines) {
    final heights = [for (final line in lines) line.bounds.height]..sort();
    return heights[heights.length ~/ 2];
  }

  /// Groups consecutive indexes into runs: [1, 2, 4] → [[1, 2], [4]].
  static List<List<int>> _runsOf(List<int> indexes) {
    final runs = <List<int>>[];
    for (final i in indexes) {
      if (runs.isNotEmpty && runs.last.last == i - 1) {
        runs.last.add(i);
      } else {
        runs.add([i]);
      }
    }
    return runs;
  }

  /// Reads one image element. Gemma vision is primary when wired; ML Kit OCR
  /// backstops a poor Gemma read, and Gemma's best-effort text is kept only when
  /// ML Kit finds nothing.
  ///
  /// [bytes] is the already-loaded image (null when it couldn't be read or no
  /// loader is wired), passed in so the OCR and figure passes decode the file
  /// once between them rather than once each.
  Future<String> _readImageElement(ImageElement e, Uint8List? bytes,
      GemmaVisionOcrService? vision, bool vary) async {
    if (e.relativeImagePath.isEmpty) return '';

    if (vision != null && bytes != null) {
      final GemmaOcrResult result;
      try {
        result = await vision.read(bytes, vary: vary);
      } on AiModelNotReadyException {
        rethrow; // the UI turns this into the "download the model" offer
      } catch (_) {
        // One image the model chokes on must not cost the page every other
        // image's text; it is read by ML Kit instead, and flagged unread if
        // that finds nothing either.
        return _readImageTextOrEmpty(e.relativeImagePath);
      }
      if (result.passed) return result.text;
      final ml = await _readImageTextOrEmpty(e.relativeImagePath);
      return ml.isNotEmpty ? ml : result.text;
    }
    return _readImageTextOrEmpty(e.relativeImagePath);
  }

  /// ML Kit's reading of an image, or '' when there is none — including when
  /// what it read is not any language. That is what its Latin recogniser makes of
  /// Bengali script, and kept it would be stored and indexed as the page's text;
  /// dropped, the image is honestly "not read" (a deep read has Gemma for it, and
  /// beats this noise as the fallback too).
  Future<String> _readImageTextOrEmpty(String relativeImagePath) async {
    final reader = _readImageText;
    if (reader == null) return '';
    final text = (await reader(relativeImagePath)).trim();
    final detector = _languageDetector;
    if (detector != null && await isUnreadable(text, detector)) return '';
    return text;
  }
}
