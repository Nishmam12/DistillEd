// Wiring for lecture transcripts (docs/AI_PIPELINE_PLAN.md, item 14): the speech
// model, the transcriber, and the one queue that runs them.
//
// Lives apart from `audio_providers.dart` because it reaches into the AI side —
// the lock it shares with Gemma, the language detector, the indexer — and the
// recording side must not depend on that.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/search_providers.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../editor/state/scene_controller.dart' show appDocsPathProvider;
import '../../ai/data/providers/local_gemma_provider.dart';
import '../../ai/presentation/ai_providers.dart';
import '../data/flutter_gemma_speech.dart';
import '../domain/lecture_language.dart';
import '../domain/lecture_transcriber.dart';
import 'audio_providers.dart';
import 'lecture_transcription_notifier.dart';
import 'speech_model_notifier.dart';

final speechModelInstallerProvider =
    Provider<SpeechModelInstaller>((ref) => FlutterGemmaSpeechInstaller());

/// Whether the speech model is on the device, and downloading it.
final speechModelProvider =
    StateNotifierProvider<SpeechModelNotifier, SpeechModelState>((ref) {
  return SpeechModelNotifier(installer: ref.watch(speechModelInstallerProvider));
});

final speechToTextProvider = Provider<SpeechToText>((ref) {
  final speech = FlutterGemmaSpeechToText();
  ref.onDispose(speech.close);
  return speech;
});

/// The lock transcription shares with the on-device language model, so the two
/// never run at once. A device whose AI is not the local Gemma (a test double,
/// say) has no such lock and runs the job straight away.
final aiExclusiveProvider = Provider<Exclusive>((ref) {
  final ai = ref.watch(localAiProvider);
  return ai is LocalGemmaProvider
      ? ai.exclusive
      : <T>(Future<T> Function() job) => job();
});

final lectureTranscriberProvider = Provider<LectureTranscriber>((ref) {
  return LectureTranscriber(
    speech: ref.watch(speechToTextProvider),
    modelId: SpeechModelSpec.active.modelId,
    exclusive: ref.watch(aiExclusiveProvider),
  );
});

/// The one transcription queue: one lecture at a time across every notebook,
/// and a status per recording id for the UI to show.
final lectureTranscriptionProvider = StateNotifierProvider<
    LectureTranscriptionNotifier, Map<int, TranscriptionStatus>>((ref) {
  return LectureTranscriptionNotifier(
    transcriber: ref.watch(lectureTranscriberProvider),
    speech: ref.watch(speechToTextProvider),
    store: ref.watch(transcriptStoreProvider),
    appDocsPath: ref.watch(appDocsPathProvider),
    // The notes beside a lecture say what language it is in; the setting is the
    // fallback. Whisper translates rather than detects, so this has to be right.
    languageFor: (recording) async {
      // Notes that cannot be read cost the detection, not the lecture.
      var pageText = '';
      try {
        pageText = await ref.read(pageTextStoreProvider).forPage(recording.pageId);
      } catch (_) {}
      return lectureLanguage(
        pageText: pageText,
        setting: ref.read(settingsProvider).recognitionLanguage,
        detector: ref.read(languageDetectorProvider),
      );
    },
    // What was said is now part of the page: read it again and index it, so the
    // lecture is searchable and answerable without anyone opening the page.
    onTranscribed: (recording) async {
      await ref
          .read(notebookIndexProvider(recording.notebookId).notifier)
          .run(notebookId: recording.notebookId, pageIds: [recording.pageId]);
    },
  );
});
