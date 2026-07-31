// The merged image read: one vision call yielding both the transcription and
// the figure, instead of two calls over the same bytes.
//
// The call-count assertions are the point of the change; the `kind: none` and
// truncation cases are what stop it being a regression. A page of plain
// handwriting is the COMMON case and must still yield its transcription, and a
// clipped verbatim_text must never silently become the page's text.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/ocr/gemma_vision_ocr_service.dart';
import 'package:inkflow/features/ai/domain/figure_analyzer.dart';
import 'package:inkflow/features/ai/domain/image_transcriber.dart';

class ScriptedTranscriber implements ImageTranscriber {
  final List<String> replies;
  int calls = 0;

  ScriptedTranscriber(this.replies);

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    final reply = replies[calls.clamp(0, replies.length - 1)];
    calls++;
    return reply;
  }
}

const _chartReply = '''
{"kind":"chart","title":"Loss curve","summary":"Loss against model complexity.",
 "insight":"Loss falls then rises as complexity grows.",
 "verbatim_text":"Loss\\nmodel complexity","confidence":0.8}
''';

/// A page of plain handwriting: no figure, but the model still read the text.
const _noFigureReply = '''
{"kind":"none",
 "verbatim_text":"Softmax activation function converts the output layer values into probabilities."}
''';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  group('analyzeWithText', () {
    test('one call returns both the figure and its transcription', () async {
      final t = ScriptedTranscriber([_chartReply]);
      final analyzer = FigureAnalyzer(local: t);

      final result = await analyzer.analyzeWithText(bytes);

      expect(t.calls, 1, reason: 'the whole point: one vision pass, not two');
      expect(result.figure, isNotNull);
      expect(result.figure!.title, 'Loss curve');
      expect(result.verbatimText, contains('model complexity'));
    });

    test('a kind:none page still yields its transcription', () async {
      final t = ScriptedTranscriber([_noFigureReply]);
      final analyzer = FigureAnalyzer(local: t);

      final result = await analyzer.analyzeWithText(bytes);

      expect(result.figure, isNull, reason: 'there genuinely is no figure');
      expect(
        result.verbatimText,
        contains('Softmax activation function'),
        reason: 'discarding this would make the merge worthless on the pages '
            'students actually write',
      );
      expect(t.calls, 1);
    });

    test('an unparseable reply yields no text, sending the caller to OCR',
        () async {
      final t = ScriptedTranscriber(['I am afraid I cannot read that.']);
      final analyzer = FigureAnalyzer(local: t);

      final result = await analyzer.analyzeWithText(bytes);

      expect(result.verbatimText, isEmpty);
      expect(result.figure, isNull);
    });
  });

  group('verbatimTextOf', () {
    test('reads the field regardless of kind', () {
      expect(FigureAnalyzer.verbatimTextOf(_noFigureReply),
          contains('Softmax'));
      expect(FigureAnalyzer.verbatimTextOf(_chartReply), contains('Loss'));
    });

    test('empty for prose, fences, or a missing field', () {
      expect(FigureAnalyzer.verbatimTextOf('no json here'), isEmpty);
      expect(FigureAnalyzer.verbatimTextOf('{"kind":"none"}'), isEmpty);
    });
  });

  group('the OCR gate guards the merged text', () {
    // The extractor accepts verbatim_text only when this says so, then pays for
    // a dedicated OCR pass when it does not.
    final ocr = GemmaVisionOcrService(transcriber: ScriptedTranscriber(['']));

    test('accepts a real transcription', () {
      expect(ocr.accepts('Softmax converts the outputs into probabilities'),
          isTrue);
    });

    test('rejects empty, whitespace and symbol garbage', () {
      expect(ocr.accepts(''), isFalse);
      expect(ocr.accepts('   \n  '), isFalse);
      expect(ocr.accepts(r'### $$$ %%%'), isFalse);
    });

    test('rejects a single stray word — the shape a clipped field takes', () {
      expect(ocr.accepts('Softmax'), isFalse);
    });
  });
}
