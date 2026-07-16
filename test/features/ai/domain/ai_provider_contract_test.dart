import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';

/// A trivial in-file provider proving the [AiProvider] contract is implementable
/// and exercising the streaming shape. It echoes the prompt back word by word,
/// stands in for a real backend, and has no embedding support — the same shape a
/// local runtime without embeddings will take in Loop 0.2.
class _EchoProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
        modelId: 'echo-test',
        displayName: 'Echo (test)',
        contextWindowTokens: 8192,
        isLocal: true,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    for (final word in prompt.split(' ')) {
      yield '$word ';
    }
  }

  @override
  Future<List<double>> embed(String text) async =>
      throw const AiUnsupportedOperationException(
        'echo provider has no embedding support',
      );
}

void main() {
  group('AiProvider contract', () {
    late _EchoProvider provider;
    setUp(() => provider = _EchoProvider());

    test('generate streams chunks that concatenate to the full reply', () async {
      final chunks = await provider.generate(prompt: 'hello there world').toList();
      expect(chunks, hasLength(3));
      expect(chunks.join().trim(), 'hello there world');
    });

    test('capabilities describe a local, streaming, embedding-less provider', () {
      expect(provider.capabilities.isLocal, isTrue);
      expect(provider.capabilities.supportsStreaming, isTrue);
      expect(provider.capabilities.supportsEmbeddings, isFalse);
      expect(provider.capabilities.approxCostPerCallUsd, 0.0);
    });

    test('embed reports a typed AiException when unsupported', () {
      expect(
        provider.embed('anything'),
        throwsA(isA<AiUnsupportedOperationException>()),
      );
    });

    test('AiException hierarchy is sealed under a common base', () {
      const err = AiModelNotReadyException('not downloaded');
      expect(err, isA<AiException>());
      expect(err.toString(), contains('not downloaded'));
    });
  });
}
