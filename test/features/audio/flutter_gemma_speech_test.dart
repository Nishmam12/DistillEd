// The speech model behind SpeechToText. The plugin needs a device, so the
// recogniser is opened through a seam and these run against a fake — what they
// pin is the decisions around it: one resident recogniser per job, and a missing
// model reported as "unavailable" rather than as a stray plugin error.

import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/audio/data/flutter_gemma_speech.dart';
import 'package:inkflow/features/audio/domain/lecture_transcriber.dart';

class _FakeRecognizer implements SpeechRecognizer {
  final languages = <String?>[];
  bool closed = false;
  Object? failWith;

  @override
  Future<String> transcribe(Uint8List pcm16kMono, {String? language}) async {
    languages.add(language);
    final f = failWith;
    if (f != null) throw f;
    return 'heard ${pcm16kMono.length} bytes';
  }

  @override
  String? language;

  @override
  void addCloseListener(void Function() listener) {}

  @override
  Future<void> close() async => closed = true;
}

void main() {
  final pcm = Uint8List(64);

  group('what counts as installed', () {
    final spec = SpeechModelSpec.whisperBase;

    Future<bool> installedWith(Set<String> files) => FlutterGemmaSpeechInstaller(
          isFileInstalled: (name) async => files.contains(name),
        ).isInstalled(spec);

    test('the filenames are the ones the plugin installs the model under', () {
      // The plugin answers "installed?" by the names its own installer records,
      // and since 1.5 the tokenizer's carries the model's id.
      final recorded = SttModelSpec(
        name: spec.modelFilename,
        modelSource: ModelSource.network(spec.modelUrl),
        tokenizerSource: ModelSource.network(spec.tokenizerUrl),
        sttModelType: SttModelType.whisper,
      ).files;

      expect(spec.modelFilename, recorded[0].filename);
      expect(spec.tokenizerFilename, recorded[1].filename);
    });

    test('the model with its tokenizer is installed', () async {
      expect(
          await installedWith({spec.modelFilename, spec.tokenizerFilename}),
          isTrue);
    });

    test('the model alone is not: without its tokenizer it cannot run',
        () async {
      // A download that dies between the two files leaves exactly this behind,
      // and "ready" here would never be put right.
      expect(await installedWith({spec.modelFilename}), isFalse);
    });

    test('the tokenizer alone is not either', () async {
      expect(await installedWith({spec.tokenizerFilename}), isFalse);
    });

    test('a tokenizer under its bare name is not the one the plugin uses',
        () async {
      expect(await installedWith({spec.modelFilename, 'tokenizer.json'}),
          isFalse);
    });
  });

  test('asks the model for the language it was told', () async {
    final recognizer = _FakeRecognizer();
    final speech = FlutterGemmaSpeechToText(open: () async => recognizer);

    final text = await speech.transcribe(pcm, language: 'bn');

    expect(text, 'heard 64 bytes');
    expect(recognizer.languages, ['bn']);
  });

  test('opens the model once for a whole job', () async {
    var opened = 0;
    final recognizer = _FakeRecognizer();
    final speech = FlutterGemmaSpeechToText(open: () async {
      opened++;
      return recognizer;
    });

    await speech.transcribe(pcm, language: 'en');
    await speech.transcribe(pcm, language: 'en');
    await speech.transcribe(pcm, language: 'en');

    expect(opened, 1);
  });

  test('two windows asked for at once still open it once', () async {
    var opened = 0;
    final speech = FlutterGemmaSpeechToText(open: () async {
      opened++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _FakeRecognizer();
    });

    await Future.wait([
      speech.transcribe(pcm, language: 'en'),
      speech.transcribe(pcm, language: 'en'),
    ]);

    expect(opened, 1);
  });

  test('closing frees the model, and the next call opens it again', () async {
    var opened = 0;
    final made = <_FakeRecognizer>[];
    final speech = FlutterGemmaSpeechToText(open: () async {
      opened++;
      final recognizer = _FakeRecognizer();
      made.add(recognizer);
      return recognizer;
    });

    await speech.transcribe(pcm, language: 'en');
    await speech.close();
    await speech.transcribe(pcm, language: 'en');

    expect(made.first.closed, isTrue);
    expect(opened, 2);
  });

  test('closing a model that was never opened is a no-op', () async {
    await FlutterGemmaSpeechToText(open: () async => _FakeRecognizer()).close();
  });

  test('no speech model installed is "unavailable"', () async {
    final speech = FlutterGemmaSpeechToText(
        open: () async => throw StateError('No active STT model set.'));

    await expectLater(speech.transcribe(pcm, language: 'en'),
        throwsA(isA<SpeechUnavailableException>()));
  });

  test('a native library that will not load is "unavailable" too', () async {
    // The speech runtime needs Android 11; below that the library fails to load
    // at runtime, whatever the build says.
    final speech = FlutterGemmaSpeechToText(
        open: () async => throw ArgumentError('Failed to load dynamic library'));

    await expectLater(speech.transcribe(pcm, language: 'en'),
        throwsA(isA<SpeechUnavailableException>()));
  });

  test('a failed open is retried next time, not remembered', () async {
    var attempts = 0;
    final speech = FlutterGemmaSpeechToText(open: () async {
      attempts++;
      if (attempts == 1) throw StateError('not yet');
      return _FakeRecognizer();
    });

    await expectLater(speech.transcribe(pcm, language: 'en'),
        throwsA(isA<SpeechUnavailableException>()));
    expect(await speech.transcribe(pcm, language: 'en'), 'heard 64 bytes');
  });

  test('an error while transcribing one window is the caller\'s to handle',
      () async {
    final recognizer = _FakeRecognizer()..failWith = StateError('bad window');
    final speech = FlutterGemmaSpeechToText(open: () async => recognizer);

    await expectLater(speech.transcribe(pcm, language: 'en'),
        throwsA(isA<StateError>()));
  });
}
