import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:distill_ed/data/persistence/lecture_recording_store.dart';
import 'package:distill_ed/editor/state/scene_controller.dart' show appDocsPathProvider;
import 'package:distill_ed/features/audio/data/transcript_store.dart';
import 'package:distill_ed/features/audio/domain/lecture_recording.dart';
import 'package:distill_ed/features/audio/domain/lecture_transcriber.dart';
import 'package:distill_ed/features/audio/domain/transcript.dart';
import 'package:distill_ed/features/audio/presentation/audio_providers.dart';
import 'package:distill_ed/features/audio/presentation/lecture_transcript_sheet.dart';
import 'package:distill_ed/features/audio/presentation/lecture_transcription_notifier.dart';
import 'package:distill_ed/features/audio/presentation/transcription_providers.dart';

import 'recording_notifier_test.dart' show FakePlayback;

class _Speech implements SpeechToText {
  @override
  Future<void> close() async {}
  @override
  Future<String> transcribe(Uint8List pcm, {required String language}) async => '';
}

/// A transcriber the test controls: it parks until released, so a recording can
/// be seen mid-transcription.
class _ParkedTranscriber extends LectureTranscriber {
  _ParkedTranscriber() : super(speech: _Speech(), modelId: 'm');
  /// Created on first use, INSIDE the test's fake-async zone: a Completer made
  /// in setUp would schedule its continuations outside it, and they would run
  /// only after the test's pumps had finished.
  late final Completer<void> gate = Completer<void>();
  double progress = 0.4;
  Object? failWith;
  int runs = 0;

  @override
  Future<Transcript> transcribe(
    String wavPath, {
    required String language,
    void Function(double fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    runs++;
    onProgress?.call(progress);
    await gate.future;
    final f = failWith;
    if (f != null) throw f;
    return const Transcript(language: 'en', model: 'm', segments: [
      TranscriptSegment(startMs: 0, endMs: 5000, text: 'fresh words'),
    ]);
  }
}

LectureRecording _rec(int id, {String ext = 'wav', int durationMs = 90000}) =>
    LectureRecording(
        id: id,
        notebookId: 1,
        pageId: 7,
        relativePath: 'audio/n1_p7_$id.$ext',
        startedAt: DateTime(2026, 10, 12, 10, 5),
        durationMs: durationMs);

const _said = Transcript(language: 'en', model: 'm', segments: [
  TranscriptSegment(
      startMs: 0, endMs: 24000, text: 'Today we cover photosynthesis.'),
  TranscriptSegment(
      startMs: 83000, endMs: 90000, text: 'The light reactions come next.'),
]);

/// Lets the queue's async chain (transcribe → save → mark done) run to its end:
/// each hop needs a turn of the event loop, and one pump is not several.
Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late InMemoryLectureRecordingStore recordings;
  late InMemoryTranscriptStore transcripts;
  late FakePlayback playback;
  late _ParkedTranscriber transcriber;

  setUp(() {
    recordings = InMemoryLectureRecordingStore();
    transcripts = InMemoryTranscriptStore();
    playback = FakePlayback();
    transcriber = _ParkedTranscriber();
  });

  Future<ProviderContainer> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(retry: (_, _) => null, overrides: [
      appDocsPathProvider.overrideWithValue('/docs'),
      lectureRecordingStoreProvider.overrideWithValue(recordings),
      transcriptStoreProvider.overrideWithValue(transcripts),
      audioPlaybackProvider.overrideWithValue(playback),
      // The real queue over fakes: the sheet is what is under test, not the
      // provider wiring (see transcription_wiring_test.dart).
      lectureTranscriptionProvider.overrideWith((ref) =>
          LectureTranscriptionNotifier(
            transcriber: transcriber,
            speech: _Speech(),
            store: transcripts,
            appDocsPath: '/docs',
            languageFor: (_) async => 'en',
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: Scaffold(body: LectureTranscriptSheet(notebookId: 1, pageId: 7))),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a transcript is listed with its timestamps', (tester) async {
    final r = await recordings.insert(_rec(0));
    await transcripts.save(r, _said);

    await open(tester);

    expect(find.text('Mon, Oct 12 at 10:05'), findsOneWidget);
    expect(find.text('[0:00]'), findsOneWidget);
    expect(find.text('Today we cover photosynthesis.'), findsOneWidget);
    expect(find.text('[1:23]'), findsOneWidget);
    expect(find.text('The light reactions come next.'), findsOneWidget);
  });

  testWidgets('tapping a line plays the lecture from that moment',
      (tester) async {
    final r = await recordings.insert(_rec(0));
    await transcripts.save(r, _said);
    await open(tester);

    await tester.tap(find.text('The light reactions come next.'));
    await tester.pumpAndSettle();

    expect(playback.loaded, '/docs/${r.relativePath}');
    expect(playback.seeked, const Duration(milliseconds: 83000));
    expect(playback.playing, isTrue);
  });

  testWidgets('a lecture that has not been transcribed offers to', (tester) async {
    await recordings.insert(_rec(0));
    final container = await open(tester);

    expect(find.text('Not transcribed yet.'), findsOneWidget);
    await tester.tap(find.text('Transcribe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(transcriber.runs, 1);
    expect(container.read(lectureTranscriptionProvider).values.single.phase,
        TranscriptionPhase.running);
  });

  testWidgets('while it runs, the progress shows', (tester) async {
    final r = await recordings.insert(_rec(0));
    final container = await open(tester);
    container.read(lectureTranscriptionProvider.notifier).enqueue(r);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Transcribing'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Transcribe'), findsNothing);
  });

  testWidgets('when it finishes the transcript appears without reopening',
      (tester) async {
    final r = await recordings.insert(_rec(0));
    final container = await open(tester);
    container.read(lectureTranscriptionProvider.notifier).enqueue(r);
    await tester.pump(const Duration(milliseconds: 50));

    transcriber.gate.complete();
    await flush(tester);

    expect(find.text('fresh words'), findsOneWidget);
  });

  testWidgets('a failure says why, and can be tried again', (tester) async {
    final r = await recordings.insert(_rec(0));
    transcriber.failWith = const SpeechUnavailableException();
    final container = await open(tester);
    container.read(lectureTranscriptionProvider.notifier).enqueue(r);
    transcriber.gate.complete();
    await flush(tester);

    expect(find.textContaining("speech model isn't available"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a lecture with nothing said in it says so', (tester) async {
    final r = await recordings.insert(_rec(0));
    await transcripts.save(
        r, const Transcript(language: 'en', model: 'm', segments: []));

    await open(tester);

    expect(find.textContaining('Nothing was said'), findsOneWidget);
  });

  testWidgets('a compressed recording explains why it has no transcript',
      (tester) async {
    await recordings.insert(_rec(0, ext: 'm4a'));

    await open(tester);

    expect(find.textContaining('without transcripts'), findsOneWidget);
    expect(find.text('Transcribe'), findsNothing);
  });

  testWidgets('a page with no recordings says there are none', (tester) async {
    await open(tester);

    expect(find.textContaining('No lectures recorded'), findsOneWidget);
  });

  testWidgets('each recording gets its own section, oldest first',
      (tester) async {
    final a = await recordings.insert(LectureRecording(
        notebookId: 1,
        pageId: 7,
        relativePath: 'audio/n1_p7_1.wav',
        startedAt: DateTime(2026, 10, 12, 10, 5),
        durationMs: 60000));
    final b = await recordings.insert(LectureRecording(
        notebookId: 1,
        pageId: 7,
        relativePath: 'audio/n1_p7_2.wav',
        startedAt: DateTime(2026, 10, 14, 9, 0),
        durationMs: 60000));
    await transcripts.save(a, _said);
    await transcripts.save(
        b,
        const Transcript(language: 'en', model: 'm', segments: [
          TranscriptSegment(startMs: 0, endMs: 5000, text: 'second lecture words'),
        ]));

    await open(tester);

    expect(find.text('Mon, Oct 12 at 10:05'), findsOneWidget);
    expect(find.text('Wed, Oct 14 at 09:00'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Mon, Oct 12 at 10:05')).dy,
        lessThan(tester.getTopLeft(find.text('Wed, Oct 14 at 09:00')).dy));
  });
}
