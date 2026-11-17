// The study summary made after a lecture is transcribed: on the device only,
// kept beside the transcript, and quietly skipped when it can't be trusted.

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/domain/quality/ai_quality_guard.dart';
import 'package:margo/features/audio/data/transcript_store.dart';
import 'package:margo/features/audio/domain/lecture_recording.dart';
import 'package:margo/features/audio/presentation/transcription_providers.dart';
import 'package:margo/features/summarize/domain/services/summarization_service.dart';

import '../summarize/presentation/summarize_notifier_test.dart'
    show ScriptedService;

class _Recording extends ScriptedService {
  _Recording(super.script);
  bool? localOnly;
  bool? cloudEnabled;
  SummarizeScope? scope;

  @override
  Future<SummarizationResult> summarizeScope({
    required int notebookId,
    required SummarizeScope scope,
    required String languageCode,
    required bool cloudEnabled,
    bool localOnly = false,
    bool preferCloud = false,
    void Function(SummarizeStage stage)? onStage,
    Future<bool> Function()? confirmSend,
  }) {
    this.localOnly = localOnly;
    this.cloudEnabled = cloudEnabled;
    this.scope = scope;
    return script[calls++](onStage);
  }
}

final _lecture = LectureRecording(
  id: 3,
  notebookId: 1,
  pageId: 10,
  relativePath: 'audio/n1_p10_1.wav',
  startedAt: DateTime(2026, 11, 17),
  durationMs: 60000,
);

SummarizationResult _result(String text, {AnswerTier tier = AnswerTier.local}) =>
    SummarizationResult(
        summary: text, recognizedText: '', modelUsed: 'local', tier: tier);

void main() {
  test('summarises the page on the device and keeps it beside the transcript',
      () async {
    final service = _Recording([(_) async => _result('  Key points.  ')]);
    final store = InMemoryTranscriptStore();

    await summarizeLecturePage(
        recording: _lecture, service: service, store: store, languageCode: 'en');

    expect(service.localOnly, isTrue);
    expect(service.cloudEnabled, isFalse);
    expect((service.scope as PageScope).pageId, 10);
    expect(await store.loadSummary(_lecture), 'Key points.');
  });

  test('an unreliable recap is not kept', () async {
    final store = InMemoryTranscriptStore();
    await summarizeLecturePage(
      recording: _lecture,
      service: _Recording([
        (_) async => _result('loop loop loop', tier: AnswerTier.localLowConfidence),
      ]),
      store: store,
      languageCode: 'en',
    );
    expect(await store.loadSummary(_lecture), isNull);
  });

  test('no on-device model is no summary, not an error', () async {
    final store = InMemoryTranscriptStore();
    await summarizeLecturePage(
      recording: _lecture,
      service: _Recording([(_) async => throw LocalModelRequiredException(offline: false)]),
      store: store,
      languageCode: 'en',
    );
    expect(await store.loadSummary(_lecture), isNull);
  });
}
