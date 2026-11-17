// Wiring for lecture transcripts (docs/AI_PIPELINE_PLAN.md, item 14): the speech
// model, the transcriber, and the one queue that runs them.
//
// Lives apart from `audio_providers.dart` because it reaches into the AI side —
// the lock it shares with Gemma, the language detector, the indexer — and the
// recording side must not depend on that.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/error_log.dart';
import '../../../data/persistence/page_text_store.dart';
import '../../ai/domain/quality/ai_quality_guard.dart' show AnswerTier;
import '../../summarize/domain/services/summarization_service.dart';
import '../../summarize/presentation/summarize_providers.dart'
    show summarizationServiceProvider;
import '../data/transcript_store.dart';
import '../domain/lecture_recording.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../editor/state/scene_controller.dart' show appDocsPathProvider;
import '../../ai/data/providers/local_gemma_provider.dart';
import '../../ai/presentation/ai_providers.dart';
import '../data/edge_ai_speech.dart';
import '../domain/lecture_language.dart';
import '../domain/lecture_transcriber.dart';
import 'audio_providers.dart';
import 'lecture_transcription_notifier.dart';
import 'speech_model_notifier.dart';

final speechModelInstallerProvider =
    Provider<SpeechModelInstaller>((ref) => EdgeAiSpeechInstaller());

/// Whether the speech model is on the device, and downloading it.
final speechModelProvider =
    StateNotifierProvider<SpeechModelNotifier, SpeechModelState>((ref) {
  return SpeechModelNotifier(installer: ref.watch(speechModelInstallerProvider));
});

final speechToTextProvider = Provider<SpeechToText>((ref) {
  final speech = EdgeAiSpeechToText();
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
    // The language the student chose when the lecture started. Whisper translates
    // rather than detects, so this has to be right. A recording made before the
    // choice existed falls back to the notes beside it, then the setting.
    languageFor: (recording) async {
      // Notes that cannot be read cost the detection, not the lecture.
      var pageText = '';
      try {
        pageText = await ref.read(pageTextStoreProvider).forPage(recording.pageId);
      } catch (_) {}
      return transcriptionLanguage(
        relativePath: recording.relativePath,
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
          .runWhenFree(notebookId: recording.notebookId, pageIds: [recording.pageId]);
      // A study summary of the page, lecture now included, waiting in the
      // transcript sheet. Not awaited: the next lecture's transcript must not
      // wait on it.
      if (ref.read(settingsProvider).summarizeLectures) {
        unawaited(summarizeLecturePage(
          recording: recording,
          service: ref.read(summarizationServiceProvider),
          store: ref.read(transcriptStoreProvider),
          languageCode: ref.read(settingsProvider).recognitionLanguage,
        ));
      }
    },
  );
});

/// Summarises [recording]'s page on the device and keeps the summary beside
/// its transcript. Quietly does nothing when there is no on-device model, the
/// page is not worth summarising, or the recap came out unreliable: this runs
/// with nobody waiting, so a failure is just no summary.
Future<void> summarizeLecturePage({
  required LectureRecording recording,
  required SummarizationService service,
  required TranscriptStore store,
  required String languageCode,
}) async {
  try {
    final result = await service.summarizeScope(
      notebookId: recording.notebookId,
      scope: PageScope(recording.pageId),
      languageCode: languageCode,
      cloudEnabled: false,
      localOnly: true,
    );
    if (result.tier == AnswerTier.localLowConfidence) return;
    final summary = result.summary.trim();
    if (summary.isNotEmpty) await store.saveSummary(recording, summary);
  } on SummarizeException {
    // No model, nothing meaningful, or cancelled: no summary.
  } catch (e, st) {
    await ErrorLog.record(e, st);
  }
}
