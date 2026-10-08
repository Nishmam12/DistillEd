import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/audio/data/edge_ai_speech.dart';
import 'package:inkflow/features/audio/presentation/speech_model_notifier.dart';

class _FakeInstaller implements SpeechModelInstaller {
  _FakeInstaller({this.installed = false});

  bool installed;
  Object? failWith;
  Completer<void>? gate;
  final percents = <int>[];
  int installs = 0;
  int uninstalls = 0;
  bool checkFails = false;

  @override
  Future<bool> isInstalled(SpeechModelSpec spec) async {
    if (checkFails) throw StateError('plugin not ready');
    return installed;
  }

  @override
  Future<void> install(
    SpeechModelSpec spec, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    installs++;
    for (final p in percents) {
      onProgress?.call(p);
    }
    await gate?.future;
    final f = failWith;
    if (f != null) throw f;
    installed = true;
  }

  @override
  Future<void> uninstall(SpeechModelSpec spec) async {
    uninstalls++;
    installed = false;
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('starts by finding out whether the model is there', () async {
    final notifier = SpeechModelNotifier(installer: _FakeInstaller(installed: true));
    expect(notifier.state.phase, SpeechModelPhase.unknown);

    await settle();

    expect(notifier.state.phase, SpeechModelPhase.ready);
  });

  test('a model that is not installed is "missing"', () async {
    final notifier = SpeechModelNotifier(installer: _FakeInstaller());
    await settle();

    expect(notifier.state.phase, SpeechModelPhase.missing);
  });

  test('a plugin that cannot say is "missing", not a crash', () async {
    final notifier =
        SpeechModelNotifier(installer: _FakeInstaller()..checkFails = true);
    await settle();

    expect(notifier.state.phase, SpeechModelPhase.missing);
  });

  test('downloading reports progress and ends ready', () async {
    final gate = Completer<void>();
    final installer = _FakeInstaller()
      ..percents.addAll([10, 55])
      ..gate = gate;
    final notifier = SpeechModelNotifier(installer: installer);
    await settle();

    final done = notifier.download();
    await settle();

    expect(notifier.state.phase, SpeechModelPhase.downloading);
    expect(notifier.state.percent, 55);

    gate.complete();
    await done;
    expect(notifier.state.phase, SpeechModelPhase.ready);
  });

  test('asking again while it downloads does not start a second download',
      () async {
    final gate = Completer<void>();
    final installer = _FakeInstaller()..gate = gate;
    final notifier = SpeechModelNotifier(installer: installer);
    await settle();

    final first = notifier.download();
    await notifier.download();
    gate.complete();
    await first;

    expect(installer.installs, 1);
  });

  test('a model that is already there is not downloaded again', () async {
    final installer = _FakeInstaller(installed: true);
    final notifier = SpeechModelNotifier(installer: installer);
    await settle();

    await notifier.download();

    expect(installer.installs, 0);
    expect(notifier.state.phase, SpeechModelPhase.ready);
  });

  test('a failed download says so, and can be tried again', () async {
    final installer = _FakeInstaller()..failWith = StateError('no network');
    final notifier = SpeechModelNotifier(installer: installer);
    await settle();

    await notifier.download();

    expect(notifier.state.phase, SpeechModelPhase.failed);
    expect(notifier.state.error, isNotEmpty);

    installer.failWith = null;
    await notifier.download();
    expect(notifier.state.phase, SpeechModelPhase.ready);
  });

  test('deleting frees the model', () async {
    final installer = _FakeInstaller(installed: true);
    final notifier = SpeechModelNotifier(installer: installer);
    await settle();

    await notifier.delete();

    expect(installer.uninstalls, 1);
    expect(notifier.state.phase, SpeechModelPhase.missing);
  });

  group('lectureTranscriptsSubtitle — what Settings says under the switch', () {
    test('off: what turning it on does, and what it costs', () {
      final text = lectureTranscriptsSubtitle(
          on: false, model: const SpeechModelState(SpeechModelPhase.missing));

      expect(text, contains('transcribed on this device'));
      expect(text, contains('2 MB a minute'));
    });

    test('on, model still to come: says it is downloading, with progress', () {
      final text = lectureTranscriptsSubtitle(
          on: true,
          model:
              const SpeechModelState(SpeechModelPhase.downloading, percent: 37));

      expect(text, contains('Downloading'));
      expect(text, contains('37%'));
    });

    test('on, model ready: says what happens after a recording', () {
      final text = lectureTranscriptsSubtitle(
          on: true, model: const SpeechModelState(SpeechModelPhase.ready));

      expect(text, contains('after you stop'));
    });

    test('on, download failed: says why and that a tap retries', () {
      final text = lectureTranscriptsSubtitle(
          on: true,
          model: const SpeechModelState(SpeechModelPhase.failed,
              error: "Couldn't download the speech model."));

      expect(text, contains("Couldn't download"));
      expect(text, contains('Tap'));
    });

    test('on, model not checked or missing yet: does not claim it is ready', () {
      for (final phase in [SpeechModelPhase.unknown, SpeechModelPhase.missing]) {
        final text = lectureTranscriptsSubtitle(
            on: true, model: SpeechModelState(phase));

        expect(text, isNot(contains('after you stop')), reason: '$phase');
      }
    });
  });
}
