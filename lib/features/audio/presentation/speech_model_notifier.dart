// Whether the speech model is on the device, and downloading it — what the
// Settings row for lecture transcripts shows (docs/AI_PIPELINE_PLAN.md, item 14).
//
// The download is something the student asked for by turning transcripts on, so
// it starts from that tap and nowhere else; nothing here ever downloads on its
// own.

import 'package:flutter_riverpod/legacy.dart';

import '../data/edge_ai_speech.dart';

enum SpeechModelPhase { unknown, missing, downloading, ready, failed }

class SpeechModelState {
  final SpeechModelPhase phase;

  /// 0–100 while [SpeechModelPhase.downloading].
  final int percent;
  final String? error;

  const SpeechModelState(this.phase, {this.percent = 0, this.error});
}

class SpeechModelNotifier extends StateNotifier<SpeechModelState> {
  SpeechModelNotifier({
    required SpeechModelInstaller installer,
    SpeechModelSpec spec = SpeechModelSpec.active,
  })  : _installer = installer,
        _spec = spec,
        super(const SpeechModelState(SpeechModelPhase.unknown)) {
    refresh();
  }

  final SpeechModelInstaller _installer;
  final SpeechModelSpec _spec;

  /// Looks again at what is installed. A plugin that cannot answer is treated as
  /// "not installed" — the worst that costs is offering a download.
  Future<void> refresh() async {
    bool installed;
    try {
      installed = await _installer.isInstalled(_spec);
    } catch (_) {
      installed = false;
    }
    if (!mounted) return;
    state = SpeechModelState(
        installed ? SpeechModelPhase.ready : SpeechModelPhase.missing);
  }

  /// Downloads the model unless it is already there or already coming.
  Future<void> download() async {
    if (state.phase == SpeechModelPhase.downloading) return;
    if (state.phase == SpeechModelPhase.unknown) await refresh();
    if (state.phase == SpeechModelPhase.ready) return;

    state = const SpeechModelState(SpeechModelPhase.downloading);
    try {
      await _installer.install(
        _spec,
        onProgress: (p) {
          if (mounted) {
            state = SpeechModelState(SpeechModelPhase.downloading, percent: p);
          }
        },
      );
      if (mounted) state = const SpeechModelState(SpeechModelPhase.ready);
    } catch (_) {
      if (mounted) {
        state = const SpeechModelState(
          SpeechModelPhase.failed,
          error: "Couldn't download the speech model. Check your connection and "
              'try again.',
        );
      }
    }
  }

  Future<void> delete() async {
    try {
      await _installer.uninstall(_spec);
    } catch (_) {
      // Gone or never there; either way the answer is re-read below.
    }
    await refresh();
  }
}

/// A transcript is added to the page's text, so it travels with the notes: into
/// search and, like any note text, into AI prompts that cloud AI may handle.
const String _transcriptDisclosure =
    'The transcript becomes part of the page, so with cloud AI on it can be '
    'sent along with your notes.';

/// What Settings says under the "Transcribe lectures" switch, given the switch
/// and the state of the speech model.
String lectureTranscriptsSubtitle({
  required bool on,
  required SpeechModelState model,
}) {
  if (!on) {
    return 'Record lectures so they can be transcribed on this device. '
        'Recordings take about 2 MB a minute. $_transcriptDisclosure';
  }
  switch (model.phase) {
    case SpeechModelPhase.downloading:
      return 'Downloading the speech model… ${model.percent}%';
    case SpeechModelPhase.ready:
      return 'On — a lecture is transcribed after you stop recording. '
          '$_transcriptDisclosure';
    case SpeechModelPhase.failed:
      return '${model.error ?? "Couldn't download the speech model."} '
          'Tap to try again.';
    case SpeechModelPhase.unknown:
    case SpeechModelPhase.missing:
      return 'On — the speech model (about 80 MB) downloads first.';
  }
}
