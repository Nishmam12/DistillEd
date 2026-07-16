import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/providers/local_gemma_provider.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';

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
  final sessions = <StreamingFakeSession>[];

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
    final session = StreamingFakeSession(this, () => openSessions--);
    sessions.add(session);
    return session;
  }
}

class StreamingFakeSession implements LlmSession {
  final StreamingFakeRuntime _runtime;
  final void Function() _onClose;
  bool closed = false;
  final turns = <(String, bool)>[];
  String? lastPrompt;

  StreamingFakeSession(this._runtime, this._onClose);

  @override
  Future<void> addTurn(String text, {required bool isUser}) async =>
      turns.add((text, isUser));

  @override
  Future<String> respond(String prompt) async =>
      (await respondStream(prompt).toList()).join();

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
  }) async {
    throw LlmNotReadyException();
  }
}

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
      expect(caps.supportsEmbeddings, isFalse);
      expect(caps.approxCostPerCallUsd, 0.0);
      expect(caps.modelId, LlmModelSpec.active.filename);
      expect(caps.contextWindowTokens, LlmModelSpec.active.maxTokens);
    });
  });
}
