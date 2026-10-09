// The provider graph around lecture transcripts, with real providers and fake
// ends: that turning the setting on makes a recording WAV and sends it to the
// queue; that the lecture's language comes from the notes beside it; that a
// finished transcript is saved and the page re-indexed; and that transcription
// takes the same lock as the local language model.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/providers/search_providers.dart';
import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/data/persistence/lecture_recording_store.dart';
import 'package:inkflow/data/persistence/page_text_store.dart';
import 'package:inkflow/editor/state/scene_controller.dart' show appDocsPathProvider;
import 'package:inkflow/features/ai/data/providers/local_gemma_provider.dart';
import 'package:inkflow/features/ai/domain/language/language_detector.dart';
import 'package:inkflow/features/ai/domain/rag/bulk_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/rag_indexer.dart';
import 'package:inkflow/features/ai/domain/rag/page_chunker.dart'
    show kChunkOverlapWords, kChunkWords;
import 'package:inkflow/features/ai/domain/rag/prompt_contract.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/notebook_index_notifier.dart';
import 'package:inkflow/features/audio/data/transcript_store.dart';
import 'package:inkflow/features/audio/domain/audio_ports.dart';
import 'package:inkflow/features/audio/domain/lecture_recording.dart';
import 'package:inkflow/features/audio/domain/lecture_transcriber.dart';
import 'package:inkflow/features/audio/domain/transcript.dart';
import 'package:inkflow/features/audio/presentation/audio_providers.dart';
import 'package:inkflow/features/audio/presentation/lecture_transcription_notifier.dart';
import 'package:inkflow/features/audio/presentation/recording_notifier.dart';
import 'package:inkflow/features/audio/presentation/transcription_providers.dart';

import '../ai/data/providers/local_gemma_provider_test.dart' show StreamingFakeRuntime;
import 'lecture_recording_test.dart' show FakeCapture;
import 'recording_notifier_test.dart' show FakePlayback;

class _Speech implements SpeechToText {
  int closed = 0;
  @override
  Future<void> close() async => closed++;
  @override
  Future<String> transcribe(Uint8List pcm, {required String language}) async => '';
}

/// A transcriber that records the language it was asked for.
class _Transcriber extends LectureTranscriber {
  _Transcriber() : super(speech: _Speech(), modelId: 'm');
  final languages = <String>[];
  final paths = <String>[];

  @override
  Future<Transcript> transcribe(
    String wavPath, {
    required String language,
    void Function(double fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    languages.add(language);
    paths.add(wavPath);
    return Transcript(language: language, model: 'm', segments: const [
      TranscriptSegment(startMs: 0, endMs: 5000, text: 'said something'),
    ]);
  }
}

/// A page-text store whose every read fails.
class _BrokenPageTexts extends InMemoryPageTextStore {
  @override
  Future<String> forPage(int pageId) async => throw StateError('db closed');
}

class _Detector implements LanguageDetector {
  _Detector(this.tag);
  final String? tag;
  @override
  Future<String?> identify(String text) async => tag;
}

class _NoEmbedder implements TextEmbedder {

  @override
  PromptContract get promptContract => PromptContract.pluginGemma300m;

  @override
  int get chunkWords => kChunkWords;

  @override
  int get chunkOverlapWords => kChunkOverlapWords;

  @override
  String get modelId => 'none';
  @override
  int get dimensions => 1;
  @override
  Future<List<double>> embedOne(String text, {required EmbedTaskType taskType}) async =>
      [0];
  @override
  Future<List<List<double>>> embedAll(List<String> texts,
          {required EmbedTaskType taskType}) async =>
      [for (final _ in texts) [0.0]];
}

/// An index notifier that records what it was asked to index.
class _RecordingIndex extends NotebookIndexNotifier {
  _RecordingIndex()
      : super(
            indexer: BulkRagIndexer(
          indexer: RagIndexer(
            embedder: _NoEmbedder(),
            saveChunks: (_, _) async {},
            deleteChunks: (_) async {},
            indexStateOf: (_, _) async => null,
          ),
          readPage: (_) async => '',
        ));

  final runs = <({int notebookId, List<int> pageIds})>[];

  @override
  Future<BulkIndexReport?> run(
      {required int notebookId, required List<int> pageIds}) async {
    runs.add((notebookId: notebookId, pageIds: pageIds));
    return null;
  }
}

LectureRecording _wav(int id, {int pageId = 7}) => LectureRecording(
    id: id,
    notebookId: 1,
    pageId: pageId,
    relativePath: 'audio/n1_p${pageId}_$id.wav',
    startedAt: DateTime(2026, 10, 12, 10, 5),
    durationMs: 60000);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late _Transcriber transcriber;
  late _Speech speech;
  late InMemoryTranscriptStore transcripts;
  late InMemoryPageTextStore pageTexts;
  late _RecordingIndex index;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('inkflow_wire_');
    transcriber = _Transcriber();
    speech = _Speech();
    transcripts = InMemoryTranscriptStore();
    pageTexts = InMemoryPageTextStore();
    index = _RecordingIndex();
  });
  tearDown(() => docs.deleteSync(recursive: true));

  ProviderContainer container({
    String? detectedLanguage,
    List<Override> extra = const [],
    InMemoryPageTextStore? pageStore,
  }) {
    final c = ProviderContainer(retry: (_, _) => null, overrides: [
      appDocsPathProvider.overrideWithValue(docs.path),
      lectureTranscriberProvider.overrideWithValue(transcriber),
      speechToTextProvider.overrideWithValue(speech),
      transcriptStoreProvider.overrideWithValue(transcripts),
      pageTextStoreProvider.overrideWithValue(pageStore ?? pageTexts),
      languageDetectorProvider.overrideWithValue(_Detector(detectedLanguage)),
      notebookIndexProvider(1).overrideWith((ref) => index),
      ...extra,
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('a finished transcript is saved, and the page is re-read and indexed',
      () async {
    final c = container();

    c.read(lectureTranscriptionProvider.notifier).enqueue(_wav(1));
    await settle();

    expect(c.read(lectureTranscriptionProvider)[1]!.phase,
        TranscriptionPhase.done);
    expect(await transcripts.exists(_wav(1)), isTrue);
    expect(index.runs.single.notebookId, 1);
    expect(index.runs.single.pageIds, [7]);
    expect(transcriber.paths.single, '${docs.path}/audio/n1_p7_1.wav');
    expect(speech.closed, 1);
  });

  test('the notes beside a lecture decide its language — over the setting',
      () async {
    // The setting says English; the page is Bangla, so the lecture is too —
    // asked for English on Bangla speech Whisper TRANSLATES.
    await pageTexts.save(
        notebookId: 1,
        pageId: 7,
        text: 'আজ আমরা সালোকসংশ্লেষণ পড়ব এবং আলোর বিক্রিয়া বুঝব');
    final c = container(detectedLanguage: 'bn');
    await settle(); // the settings finish restoring

    c.read(lectureTranscriptionProvider.notifier).enqueue(_wav(1));
    await settle();

    expect(transcriber.languages, ['bn']);
  });

  test('with no notes to read, the Handwriting Language setting is used',
      () async {
    SharedPreferences.setMockInitialValues({'ai.recognitionLanguage': 'bn'});
    final c = container(detectedLanguage: 'en');
    c.read(settingsProvider); // start restoring
    await settle();

    c.read(lectureTranscriptionProvider.notifier).enqueue(_wav(1));
    await settle();

    expect(transcriber.languages, ['bn']);
  });

  test('notes that cannot be read fall back to the setting — the lecture is '
      'still transcribed', () async {
    SharedPreferences.setMockInitialValues({'ai.recognitionLanguage': 'bn'});
    final c = container(pageStore: _BrokenPageTexts());
    c.read(settingsProvider);
    await settle();

    c.read(lectureTranscriptionProvider.notifier).enqueue(_wav(1));
    await settle();

    expect(c.read(lectureTranscriptionProvider)[1]!.phase,
        TranscriptionPhase.done);
    expect(transcriber.languages, ['bn']);
  });

  group('recording from the editor', () {
    ProviderContainer recordingContainer({required bool transcribe}) {
      SharedPreferences.setMockInitialValues(
          {'ai.transcribeLectures': transcribe});
      final capture = FakeCapture();
      final c = container(extra: [
        audioCaptureProvider.overrideWithValue(capture),
        audioPlaybackProvider.overrideWithValue(FakePlayback()),
        lectureRecordingStoreProvider
            .overrideWithValue(InMemoryLectureRecordingStore()),
      ]);
      c.read(settingsProvider);
      return c;
    }

    test('with the setting on, recording is WAV and the finished lecture goes '
        'to the transcription queue', () async {
      final c = recordingContainer(transcribe: true);
      await settle();
      final notifier = c.read(recordingNotifierProvider(1).notifier);

      await notifier.start(7);
      final capture = c.read(audioCaptureProvider) as FakeCapture;
      expect(capture.format, AudioFormat.speechWav);
      expect(capture.path, endsWith('.wav'));

      await notifier.stop(7);
      await settle();

      expect(c.read(lectureTranscriptionProvider), isNotEmpty);
      expect(transcriber.paths, hasLength(1));
    });

    test('with it off, recording is AAC and nothing is queued', () async {
      final c = recordingContainer(transcribe: false);
      await settle();
      final notifier = c.read(recordingNotifierProvider(1).notifier);

      await notifier.start(7);
      final capture = c.read(audioCaptureProvider) as FakeCapture;
      expect(capture.format, AudioFormat.aac);

      await notifier.stop(7);
      await settle();

      expect(c.read(lectureTranscriptionProvider), isEmpty);
      expect(transcriber.paths, isEmpty);
    });
  });

  group('sharing the device with the language model', () {
    test('with the local model, transcription takes ITS lock', () async {
      final runtime = StreamingFakeRuntime(['ok']);
      final local = LocalGemmaProvider(runtime: runtime);
      final c = container(extra: [localAiProvider.overrideWithValue(local)]);
      final gate = Completer<void>();
      final order = <String>[];

      final job = c.read(aiExclusiveProvider)(() async {
        order.add('transcribe start');
        await gate.future;
        order.add('transcribe end');
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final answer = local.generate(prompt: 'hi').toList().then((_) {
        order.add('answered');
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      await Future.wait([job, answer]);

      expect(order, ['transcribe start', 'transcribe end', 'answered']);
    });

    test('with no local model there is no lock to take — the job just runs',
        () async {
      final c = container();

      expect(await c.read(aiExclusiveProvider)(() async => 5), 5);
    });
  });
}
