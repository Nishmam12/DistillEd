import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/ocr/gemma_vision_ocr_service.dart';
import 'package:inkflow/features/ai/domain/ai_exception.dart';
import 'package:inkflow/features/ai/domain/image_transcriber.dart';

/// One entry per attempt: a String reply, or an Object to throw. The last entry
/// is reused if more attempts happen than scripted.
class ScriptedTranscriber implements ImageTranscriber {
  final List<Object> script;
  int calls = 0;
  final prompts = <String>[];
  final temperatures = <double>[];
  final seeds = <int?>[];

  ScriptedTranscriber(this.script);

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    prompts.add(prompt);
    temperatures.add(temperature);
    seeds.add(randomSeed);
    final item = calls < script.length ? script[calls] : script.last;
    calls++;
    if (item is String) return item;
    throw item;
  }
}

void main() {
  final bytes = Uint8List.fromList(const [0, 1, 2]);
  GemmaVisionOcrService service(ScriptedTranscriber t,
          {int Function()? seedSource}) =>
      GemmaVisionOcrService(transcriber: t, seedSource: seedSource);

  test('a plausible first read passes in one attempt', () async {
    final t = ScriptedTranscriber(['Sentence segmentation splits text.']);
    final result = await service(t).read(bytes);

    expect(result.passed, isTrue);
    expect(result.attempts, 1);
    expect(result.text, 'Sentence segmentation splits text.');
    expect(t.calls, 1, reason: 'a good read is not retried');
  });

  test('gibberish triggers one retry, sampling with a fresh prompt and seed',
      () async {
    final t = ScriptedTranscriber(['::: ??? %%%', 'A proper reading appears.']);
    final result = await service(t, seedSource: () => 7).read(bytes);

    expect(result.passed, isTrue);
    expect(result.attempts, 2);
    expect(result.text, 'A proper reading appears.');
    expect(t.temperatures, [0.0, 0.30],
        reason: 'first pass is deterministic; the retry samples');
    expect(t.seeds, [null, 7],
        reason: 'the deterministic pass takes no seed; the retry samples with one');
    expect(t.prompts[0], isNot(t.prompts[1]),
        reason: 'a different prompt gives the retry a real chance');
  });

  test('a normal read is deterministic on its first attempt (temp 0, no seed)',
      () async {
    final t = ScriptedTranscriber(['A clean faithful transcription here.']);
    await service(t).read(bytes);

    expect(t.temperatures.first, 0.0);
    expect(t.seeds.first, isNull);
  });

  test('a re-read (vary) samples from the first attempt with a fresh seed',
      () async {
    final t = ScriptedTranscriber(['A differently sampled reading now.']);
    final result = await service(t, seedSource: () => 42).read(bytes, vary: true);

    expect(result.passed, isTrue);
    expect(t.temperatures.first, greaterThan(0.0),
        reason: 're-read must sample so it can differ from the first pass');
    expect(t.seeds.first, 42, reason: 're-read seeds so the output can change');
  });

  test('successive re-reads draw different seeds — each reads afresh', () async {
    var n = 500;
    final t = ScriptedTranscriber(['same passing reading over and over now']);
    final svc = GemmaVisionOcrService(transcriber: t, seedSource: () => n++);

    await svc.read(bytes, vary: true);
    await svc.read(bytes, vary: true);

    expect(t.seeds[0], isNotNull);
    expect(t.seeds[0], isNot(t.seeds[1]),
        reason: 'a fresh seed per re-read is what makes it read differently');
  });

  test('two gibberish reads fail the gate but keep the best-effort text',
      () async {
    final t = ScriptedTranscriber(['::: ??? %%%', '### @@@ !!!']);
    final result = await service(t).read(bytes);

    expect(result.passed, isFalse);
    expect(result.attempts, 2);
    expect(result.text, '::: ??? %%%',
        reason: 'the first non-empty attempt is the backstop');
  });

  test('a missing model is rethrown (not swallowed as a failed read)', () {
    final t = ScriptedTranscriber(
        [const AiModelNotReadyException('not downloaded')]);
    expect(service(t).read(bytes),
        throwsA(isA<AiModelNotReadyException>()));
  });

  test('a generation error on the first attempt is retried', () async {
    final t = ScriptedTranscriber([
      const AiGenerationException('engine hiccup'),
      'The retry read the page fine.',
    ]);
    final result = await service(t).read(bytes);

    expect(result.passed, isTrue);
    expect(result.attempts, 2);
    expect(result.text, 'The retry read the page fine.');
  });

  test('both attempts erroring yields an empty, un-passed result', () async {
    final t = ScriptedTranscriber([
      const AiGenerationException('one'),
      const AiGenerationException('two'),
    ]);
    final result = await service(t).read(bytes);

    expect(result.passed, isFalse);
    expect(result.text, isEmpty);
    expect(result.attempts, 2);
  });
}
