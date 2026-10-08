import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart'
    show ModelFileType, ModelType;
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/providers/local_gemma_provider.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/compute_backend.dart';

/// Runtime whose sessions stream scripted chunks and record everything the
/// provider does with the seams.
class StreamingFakeRuntime implements LlmRuntime {
  final List<String> chunks;
  final Duration chunkDelay;
  final Object? streamError;

  int openCalls = 0;
  int openSessions = 0;
  int maxConcurrentSessions = 0;
  double? lastTemperature;
  int? lastTopK;
  double? lastTopP;
  int? lastMaxOutputTokens;
  String? lastSystemInstruction;
  int? lastRandomSeed;
  bool lastSupportImage = false;
  final sessions = <StreamingFakeSession>[];

  /// What the "plugin" reports once loaded; settable so a test can act as a
  /// device that fell back to the CPU.
  ComputeBackend? backend;

  /// When set, [releaseModel] starts (counting the call) but does not finish
  /// until this completes — a model that takes a while to tear down.
  Completer<void>? releaseGate;

  @override
  ComputeBackend? get activeBackend => backend;

  StreamingFakeRuntime(
    this.chunks, {
    this.chunkDelay = Duration.zero,
    this.streamError,
  });

  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
    String? systemInstruction,
    int? randomSeed,
    bool supportImage = false,
    int maxNumImages = 1,
  }) async {
    openCalls++;
    openSessions++;
    if (openSessions > maxConcurrentSessions) {
      maxConcurrentSessions = openSessions;
    }
    lastTemperature = temperature;
    lastTopK = topK;
    lastTopP = topP;
    lastMaxOutputTokens = maxOutputTokens;
    lastSystemInstruction = systemInstruction;
    lastRandomSeed = randomSeed;
    lastSupportImage = supportImage;
    final session = StreamingFakeSession(this, () => openSessions--);
    sessions.add(session);
    return session;
  }

  int releaseCalls = 0;

  @override
  Future<void> releaseModel() async {
    releaseCalls++;
    await releaseGate?.future;
  }
}

class StreamingFakeSession implements LlmSession {
  final StreamingFakeRuntime _runtime;
  final void Function() _onClose;
  bool closed = false;
  final turns = <(String, bool)>[];
  String? lastPrompt;
  String? lastImagePrompt;
  Uint8List? lastImageBytes;

  StreamingFakeSession(this._runtime, this._onClose);

  @override
  Future<void> addTurn(String text, {required bool isUser}) async =>
      turns.add((text, isUser));

  @override
  Future<String> respond(String prompt) async =>
      (await respondStream(prompt).toList()).join();

  @override
  Future<String> respondWithImage(String prompt, Uint8List imageBytes) async {
    lastImagePrompt = prompt;
    lastImageBytes = imageBytes;
    final error = _runtime.streamError;
    if (error != null) throw error;
    return _runtime.chunks.join();
  }

  @override
  Stream<String> respondStream(String prompt) async* {
    lastPrompt = prompt;
    for (final chunk in _runtime.chunks) {
      if (_runtime.chunkDelay > Duration.zero) {
        await Future<void>.delayed(_runtime.chunkDelay);
      }
      yield chunk;
    }
    final error = _runtime.streamError;
    if (error != null) throw error;
  }

  @override
  Future<void> close() async {
    closed = true;
    _onClose();
  }
}

class NotReadyRuntime implements LlmRuntime {
  @override
  Future<LlmSession> open({
    required LlmModelSpec spec,
    required double temperature,
    required int topK,
    required double topP,
    int? maxOutputTokens,
    String? systemInstruction,
    int? randomSeed,
    bool supportImage = false,
    int maxNumImages = 1,
  }) async {
    throw LlmNotReadyException();
  }

  @override
  Future<void> releaseModel() async {}

  @override
  ComputeBackend? get activeBackend => null;
}

LlmModelSpec _spec({bool shareVisionEngine = true}) => LlmModelSpec(
      displayName: 'Test',
      filename: 'test.litertlm',
      downloadUrl: 'https://example.com/test.litertlm',
      approxSizeBytes: 1,
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
      maxTokens: 4096,
      shareVisionEngine: shareVisionEngine,
    );

void main() {
  group('LocalGemmaProvider — streaming contract', () {
    test('streams chunks that concatenate to the full reply, then unloads',
        () async {
      final runtime = StreamingFakeRuntime(['Hel', 'lo ', 'world']);
      final provider = LocalGemmaProvider(runtime: runtime);

      final chunks = await provider.generate(prompt: 'hi').toList();

      expect(chunks, ['Hel', 'lo ', 'world']);
      expect(runtime.sessions.single.closed, isTrue,
          reason: 'model must be unloaded after generation');
      expect(runtime.openSessions, 0);
      expect(runtime.sessions.single.lastPrompt, 'hi');
    });

    test('concurrent generate() calls serialize — one model in memory',
        () async {
      final runtime = StreamingFakeRuntime(['ok'],
          chunkDelay: const Duration(milliseconds: 15));
      final provider = LocalGemmaProvider(runtime: runtime);

      final results = await Future.wait([
        provider.generate(prompt: 'one').toList(),
        provider.generate(prompt: 'two').toList(),
      ]);

      expect(results, [
        ['ok'],
        ['ok'],
      ]);
      expect(runtime.maxConcurrentSessions, 1,
          reason: 'the mutex must keep at most one model loaded');
    });

    test('history turns are replayed, system turns filtered out', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(runtime: runtime);

      await provider.generate(
        prompt: 'now answer',
        systemPrompt: 'be brief',
        history: const [
          AiMessage.system('ignored — goes via systemInstruction'),
          AiMessage.user('earlier question'),
          AiMessage.assistant('earlier answer'),
        ],
      ).toList();

      expect(runtime.lastSystemInstruction, 'be brief');
      expect(runtime.sessions.single.turns, [
        ('earlier question', true),
        ('earlier answer', false),
      ]);
    });

    test('generation options map onto the session', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(runtime: runtime);

      await provider
          .generate(
            prompt: 'p',
            options: const AiGenerationOptions(
              temperature: 0.3,
              topK: 25,
              topP: 0.8,
              maxTokens: 128,
              seed: 42,
            ),
          )
          .toList();

      expect(runtime.lastTemperature, 0.3);
      expect(runtime.lastTopK, 25);
      expect(runtime.lastTopP, 0.8);
      expect(runtime.lastMaxOutputTokens, 128);
      expect(runtime.lastRandomSeed, 42);
    });

    test('precise preset (temperature 0) defaults to greedy top-k 1', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(runtime: runtime);

      await provider
          .generate(prompt: 'p', options: AiGenerationOptions.precise)
          .toList();

      expect(runtime.lastTopK, 1);
    });
  });

  group('LocalGemmaProvider — stop sequences', () {
    test('truncates at the first stop sequence, even across chunks', () async {
      // 'END' spans the 2nd/3rd chunks: 'partE' + 'ND rest'.
      final runtime = StreamingFakeRuntime(['keep ', 'partE', 'ND rest']);
      final provider = LocalGemmaProvider(runtime: runtime);

      final text = (await provider
              .generate(
                prompt: 'p',
                options: const AiGenerationOptions(stopSequences: ['END']),
              )
              .toList())
          .join();

      expect(text, 'keep part');
    });

    test('flushes the held-back tail when no stop sequence appears', () async {
      final runtime = StreamingFakeRuntime(['abc', 'def']);
      final provider = LocalGemmaProvider(runtime: runtime);

      final text = (await provider
              .generate(
                prompt: 'p',
                options: const AiGenerationOptions(stopSequences: ['XYZQ']),
              )
              .toList())
          .join();

      expect(text, 'abcdef');
    });
  });

  group('LocalGemmaProvider — failures', () {
    test('missing model surfaces as AiModelNotReadyException', () {
      final provider = LocalGemmaProvider(runtime: NotReadyRuntime());
      expect(
        provider.generate(prompt: 'x').toList(),
        throwsA(isA<AiModelNotReadyException>()),
      );
    });

    test('mid-stream failure surfaces as AiGenerationException and unloads',
        () async {
      final runtime = StreamingFakeRuntime(['ok '],
          streamError: LlmGenerationException('engine crash'));
      final provider = LocalGemmaProvider(runtime: runtime);

      await expectLater(
        provider.generate(prompt: 'x').toList(),
        throwsA(isA<AiGenerationException>()),
      );
      expect(runtime.sessions.single.closed, isTrue);
      expect(runtime.openSessions, 0);
    });

    test('a failed call does not deadlock later calls', () async {
      final provider = LocalGemmaProvider(runtime: NotReadyRuntime());
      await expectLater(
        provider.generate(prompt: 'boom').toList(),
        throwsA(isA<AiModelNotReadyException>()),
      );

      // Same provider instance, healthy runtime path — via a fresh provider
      // sharing nothing; the point is the first failure released its lock.
      await expectLater(
        provider.generate(prompt: 'boom again').toList(),
        throwsA(isA<AiModelNotReadyException>()),
      );
    });

    test('embed reports a typed unsupported-operation error', () {
      final provider =
          LocalGemmaProvider(runtime: StreamingFakeRuntime(const ['x']));
      expect(
        provider.embed('anything'),
        throwsA(isA<AiUnsupportedOperationException>()),
      );
    });
  });

  group('LocalGemmaProvider — capabilities', () {
    test('describes a local streaming provider bound to the active spec', () {
      final provider =
          LocalGemmaProvider(runtime: StreamingFakeRuntime(const ['x']));
      final caps = provider.capabilities;

      expect(caps.isLocal, isTrue);
      expect(caps.supportsStreaming, isTrue);
      expect(caps.supportsVision, isTrue,
          reason: 'Gemma E2B ships a vision encoder; transcribeImage uses it');
      expect(caps.supportsEmbeddings, isFalse);
      expect(caps.approxCostPerCallUsd, 0.0);
      expect(caps.modelId, LlmModelSpec.active.filename);
      expect(caps.contextWindowTokens, LlmModelSpec.active.maxTokens);
    });
  });

  group('LocalGemmaProvider — transcribeImage (vision)', () {
    final bytes = Uint8List.fromList(const [1, 2, 3, 4]);

    test('opens a vision session, returns the transcription, then unloads',
        () async {
      final runtime = StreamingFakeRuntime(['Sentence ', 'Segmentation']);
      final provider = LocalGemmaProvider(runtime: runtime);

      final text =
          await provider.transcribeImage(bytes, prompt: 'read this');

      expect(text, 'Sentence Segmentation');
      expect(runtime.lastSupportImage, isTrue,
          reason: 'the model must load its vision encoder');
      final session = runtime.sessions.single;
      expect(session.lastImagePrompt, 'read this');
      expect(session.lastImageBytes, bytes);
      expect(session.closed, isTrue, reason: 'model unloads after the read');
      expect(runtime.openSessions, 0);
    });

    test('temperature 0 decodes greedily (top-k 1); a bump samples', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(runtime: runtime);

      await provider.transcribeImage(bytes, prompt: 'p'); // default temp 0
      expect(runtime.lastTopK, 1);

      await provider.transcribeImage(bytes, prompt: 'p', temperature: 0.35);
      expect(runtime.lastTopK, 40);
    });

    test('missing model surfaces as AiModelNotReadyException', () {
      final provider = LocalGemmaProvider(runtime: NotReadyRuntime());
      expect(
        provider.transcribeImage(bytes, prompt: 'p'),
        throwsA(isA<AiModelNotReadyException>()),
      );
    });

    test('a read failure surfaces as AiGenerationException and still unloads',
        () async {
      final runtime = StreamingFakeRuntime(const [],
          streamError: LlmGenerationException('vision crash'));
      final provider = LocalGemmaProvider(runtime: runtime);

      await expectLater(
        provider.transcribeImage(bytes, prompt: 'p'),
        throwsA(isA<AiGenerationException>()),
      );
      expect(runtime.sessions.single.closed, isTrue);
      expect(runtime.openSessions, 0);
    });

    test('transcription and generation share the mutex — never overlap',
        () async {
      final runtime = StreamingFakeRuntime(['ok'],
          chunkDelay: const Duration(milliseconds: 15));
      final provider = LocalGemmaProvider(runtime: runtime);

      await Future.wait([
        provider.transcribeImage(bytes, prompt: 'p'),
        provider.generate(prompt: 'g').toList(),
      ]);

      expect(runtime.maxConcurrentSessions, 1,
          reason: 'vision and text load the SAME model — one at a time');
    });
  });

  group('LocalGemmaProvider — one shared engine', () {
    test('text generation loads the same configuration as vision', () async {
      // A deep page read alternates image reads and text analysis; if the two
      // asked the runtime for different configurations it would rebuild the
      // whole engine at every switch (3.6–17 s each, measured on a Pad 7).
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(runtime: runtime);

      await provider.generate(prompt: 'p').toList();
      expect(runtime.lastSupportImage, isTrue);

      await provider.transcribeImage(Uint8List(4), prompt: 'p');
      expect(runtime.lastSupportImage, isTrue);
    });

    test('a spec can opt out and load text-only sessions without the encoder',
        () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(
          spec: _spec(shareVisionEngine: false), runtime: runtime);

      await provider.generate(prompt: 'p').toList();
      expect(runtime.lastSupportImage, isFalse);
    });
  });

  group('LocalGemmaProvider — idle unload', () {
    const idle = Duration(milliseconds: 40);

    test('the model is released after the idle delay, not before', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(
          spec: _spec(), runtime: runtime, idleUnloadDelay: idle);

      await provider.generate(prompt: 'p').toList();
      expect(runtime.releaseCalls, 0, reason: 'resident right after the call');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(runtime.releaseCalls, 1);
    });

    test('a call inside the window keeps the model loaded', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(
          spec: _spec(),
          runtime: runtime,
          idleUnloadDelay: const Duration(milliseconds: 120));

      await provider.generate(prompt: 'one').toList();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await provider.generate(prompt: 'two').toList();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // 160 ms after the first call, whose timer would have fired at 120 ms.
      expect(runtime.releaseCalls, 0);
    });

    test('a call that arrives while the model is being released waits for it',
        () async {
      // The plugin hands back its cached instance until the old one has finished
      // closing, so opening in that window would wrap a model mid-teardown.
      final runtime = StreamingFakeRuntime(['x'])
        ..releaseGate = Completer<void>();
      final provider = LocalGemmaProvider(
          spec: _spec(), runtime: runtime, idleUnloadDelay: idle);

      await provider.generate(prompt: 'one').toList();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(runtime.releaseCalls, 1, reason: 'the idle release has begun');

      final second = provider.generate(prompt: 'two').toList();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(runtime.openCalls, 1, reason: 'must not open mid-teardown');

      runtime.releaseGate!.complete();
      await second;
      expect(runtime.openCalls, 2);
    });
  });

  group('LocalGemmaProvider — warmUp', () {
    test('loads the model ahead of the first call and leaves it resident',
        () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(spec: _spec(), runtime: runtime);

      await provider.warmUp();

      expect(runtime.openCalls, 1);
      expect(runtime.lastSupportImage, isTrue,
          reason: 'warmed in the configuration every call will ask for');
      expect(runtime.sessions.single.closed, isTrue,
          reason: 'only the load is wanted, not a conversation');
      expect(runtime.releaseCalls, 0, reason: 'the model must stay loaded');
    });

    test('the warmed model still unloads if nobody uses it', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(
          spec: _spec(),
          runtime: runtime,
          idleUnloadDelay: const Duration(milliseconds: 40));

      await provider.warmUp();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(runtime.releaseCalls, 1,
          reason: 'prewarming must not park 2.6 GB for an app nobody is using');
    });

    test('warming a model that is not downloaded is a silent no-op', () async {
      final provider = LocalGemmaProvider(runtime: NotReadyRuntime());

      await provider.warmUp(); // must not throw
    });

    test('warm-up waits its turn behind a running call', () async {
      final runtime = StreamingFakeRuntime(['ok'],
          chunkDelay: const Duration(milliseconds: 15));
      final provider = LocalGemmaProvider(spec: _spec(), runtime: runtime);

      await Future.wait([
        provider.generate(prompt: 'g').toList(),
        provider.warmUp(),
      ]);

      expect(runtime.maxConcurrentSessions, 1);
    });
  });

  group('LocalGemmaProvider — where the model runs', () {
    test('reports the backend after a load, and again only when it changes',
        () async {
      final runtime = StreamingFakeRuntime(['x'])
        ..backend = ComputeBackend.gpu;
      final seen = <ComputeBackend>[];
      final provider = LocalGemmaProvider(
          spec: _spec(), runtime: runtime, onBackendChanged: seen.add);

      await provider.generate(prompt: 'a').toList();
      await provider.generate(prompt: 'b').toList();
      expect(seen, [ComputeBackend.gpu]);

      runtime.backend = ComputeBackend.cpu;
      await provider.generate(prompt: 'c').toList();
      expect(seen, [ComputeBackend.gpu, ComputeBackend.cpu]);
      expect(provider.backend, ComputeBackend.cpu);
    });

    test('a listener that throws never breaks the call or leaks the session',
        () async {
      // The callback is the app's, not the provider's: if it fails (a disposed
      // Riverpod container, say) the read it was merely being told about must
      // still complete, and its session must still be closed.
      final runtime = StreamingFakeRuntime(['fine'])
        ..backend = ComputeBackend.gpu;
      final provider = LocalGemmaProvider(
        spec: _spec(),
        runtime: runtime,
        onBackendChanged: (_) => throw StateError('listener is gone'),
      );

      expect(await provider.generate(prompt: 'p').toList(), ['fine']);
      expect(runtime.sessions.single.closed, isTrue);

      final text = await provider.transcribeImage(Uint8List(4), prompt: 'p');
      expect(text, 'fine');
      expect(runtime.sessions.last.closed, isTrue);
    });

    test('a runtime that does not say reports nothing', () async {
      final seen = <ComputeBackend>[];
      final provider = LocalGemmaProvider(
          spec: _spec(),
          runtime: StreamingFakeRuntime(['x']),
          onBackendChanged: seen.add);

      await provider.generate(prompt: 'a').toList();
      expect(seen, isEmpty);
      expect(provider.backend, isNull);
    });

    test('on a slow backend a vision read cannot hold the model for minutes',
        () async {
      // Several times slower per token: a 1,024-token reply would sit at the
      // three-minute read timeout, and everything queued behind it with it.
      final runtime = StreamingFakeRuntime(['x'])
        ..backend = ComputeBackend.cpu;
      final provider = LocalGemmaProvider(spec: _spec(), runtime: runtime);

      await provider.transcribeImage(Uint8List(4),
          prompt: 'p', maxOutputTokens: 1024);
      expect(runtime.lastMaxOutputTokens, 384);

      await provider.transcribeImage(Uint8List(4),
          prompt: 'p', maxOutputTokens: 200);
      expect(runtime.lastMaxOutputTokens, 200,
          reason: 'a budget already under the cap is left alone');
    });

    test('on an accelerator the requested vision budget is untouched',
        () async {
      final runtime = StreamingFakeRuntime(['x'])
        ..backend = ComputeBackend.gpu;
      final provider = LocalGemmaProvider(spec: _spec(), runtime: runtime);

      await provider.transcribeImage(Uint8List(4),
          prompt: 'p', maxOutputTokens: 1024);
      expect(runtime.lastMaxOutputTokens, 1024);
    });
  });

  group('LocalGemmaProvider — exclusive (other local AI shares the model lock)',
      () {
    test('a job runs, and its result comes back', () async {
      final provider = LocalGemmaProvider(runtime: StreamingFakeRuntime(['x']));

      expect(await provider.exclusive(() async => 42), 42);
    });

    test('a generation that arrives while a job runs waits for it', () async {
      // Transcription must never be running while Gemma is answering.
      final runtime = StreamingFakeRuntime(['ok']);
      final provider = LocalGemmaProvider(runtime: runtime);
      final gate = Completer<void>();
      final order = <String>[];

      final job = provider.exclusive(() async {
        order.add('job start');
        await gate.future;
        order.add('job end');
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final answer = provider.generate(prompt: 'hi').toList().then((_) {
        order.add('answered');
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(runtime.openCalls, 0, reason: 'the model must not load mid-job');

      gate.complete();
      await Future.wait([job, answer]);

      expect(order, ['job start', 'job end', 'answered']);
    });

    test('a job that arrives while a generation runs waits for it', () async {
      final runtime = StreamingFakeRuntime(['a', 'b'],
          chunkDelay: const Duration(milliseconds: 20));
      final provider = LocalGemmaProvider(runtime: runtime);
      final order = <String>[];

      final answer = provider.generate(prompt: 'hi').toList().then((_) {
        order.add('answered');
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final job = provider.exclusive(() async => order.add('job'));

      await Future.wait([answer, job]);

      expect(order, ['answered', 'job']);
    });

    test('two jobs never overlap', () async {
      final provider = LocalGemmaProvider(runtime: StreamingFakeRuntime(['x']));
      var running = 0;
      var peak = 0;
      Future<void> job() => provider.exclusive(() async {
            running++;
            peak = running > peak ? running : peak;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            running--;
          });

      await Future.wait([job(), job(), job()]);

      expect(peak, 1);
    });

    test('a job that throws does not leave the lock held', () async {
      final provider = LocalGemmaProvider(runtime: StreamingFakeRuntime(['ok']));

      await expectLater(
          provider.exclusive(() async => throw StateError('boom')),
          throwsA(isA<StateError>()));

      expect(await provider.generate(prompt: 'hi').toList(), ['ok']);
    });

    test('does not load the model — it only holds the lock', () async {
      final runtime = StreamingFakeRuntime(['x']);
      final provider = LocalGemmaProvider(runtime: runtime);

      await provider.exclusive(() async {});

      expect(runtime.openCalls, 0);
    });
  });
}
