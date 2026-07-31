// Provenance stamping: does the panel's badge say where the analysis ACTUALLY
// ran?
//
// The property under test is that the stamp follows the provider and the
// guard's tier, never the user's settings. Reporting "Cloud" for a page the
// on-device model read perfectly well is precisely the confusion this feature
// exists to remove, and settings-derived attribution would do exactly that.

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/ai_provenance.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/context_engine/context_engine.dart';
import 'package:inkflow/features/ai/domain/context_engine/page_context.dart';
import 'package:inkflow/features/ai/domain/page_content.dart';

/// Enough of a page that the meaningfulness gate lets it through.
const _richText = '''
Softmax activation function converts the output layer values into
probabilities. Regularization techniques include L2 ridge regression and L1
lasso regression. Cosine similarity measures the angle between two vectors.
''';

const _validJson = '''
{"currentTopic":"Softmax","keyConcepts":["Softmax"],"confidence":0.8}
''';

class StubProvider implements AiProvider {
  final bool isLocal;
  final String reply;
  int calls = 0;

  StubProvider({required this.isLocal, this.reply = _validJson});

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: isLocal ? 'local-model' : 'cloud-model',
        displayName: isLocal ? 'Local' : 'Cloud',
        contextWindowTokens: 4096,
        supportsStreaming: true,
        supportsVision: true,
        supportsEmbeddings: false,
        isLocal: isLocal,
        approxCostPerCallUsd: 0.0,
      );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    calls++;
    yield reply;
  }

  @override
  Future<List<double>> embed(String text) async =>
      throw UnimplementedError();
}

void main() {
  final content = PageContent(recognizedInkText: _richText, typedText: '');

  group('AiRanOn', () {
    test('only on-device keeps content on the device', () {
      expect(AiRanOn.onDevice.leftDevice, isFalse);
      expect(AiRanOn.cloudPreferred.leftDevice, isTrue);
      expect(AiRanOn.cloudEscalated.leftDevice, isTrue);
    });

    test('both cloud reasons label as Cloud but explain differently', () {
      expect(AiRanOn.cloudPreferred.label, 'Cloud');
      expect(AiRanOn.cloudEscalated.label, 'Cloud');
      expect(
        AiRanOn.cloudPreferred.explanation,
        isNot(AiRanOn.cloudEscalated.explanation),
        reason: 'the student should learn WHY it went to the cloud',
      );
    });
  });

  group('ContextEngine stamps where it ran', () {
    test('a local provider stamps onDevice', () async {
      final engine = ContextEngine(provider: StubProvider(isLocal: true));

      final result = await engine.analyze(content);

      expect(result.ranOn, AiRanOn.onDevice);
      expect(result.ranOn.leftDevice, isFalse);
    });

    test('a cloud provider stamps cloudPreferred', () async {
      final engine = ContextEngine(provider: StubProvider(isLocal: false));

      final result = await engine.analyze(content);

      expect(result.ranOn, AiRanOn.cloudPreferred);
      expect(result.ranOn.leftDevice, isTrue);
    });

    test('a page too sparse to analyse stays empty and claims nothing',
        () async {
      final provider = StubProvider(isLocal: true);
      final engine = ContextEngine(provider: provider);

      final result = await engine.analyze(PageContent(recognizedInkText: 'hi', typedText: ''));

      expect(result.isEmpty, isTrue);
      expect(provider.calls, 0, reason: 'no model ran, so nothing was sent');
      expect(result.ranOn, AiRanOn.onDevice);
    });
  });

  group('PageContext.withRanOn', () {
    test('restamps without disturbing the analysis', () {
      const base = PageContext(
        currentTopic: 'Softmax',
        keyConcepts: ['a', 'b'],
        confidence: 0.7,
      );

      final stamped = base.withRanOn(AiRanOn.cloudEscalated);

      expect(stamped.ranOn, AiRanOn.cloudEscalated);
      expect(stamped.currentTopic, base.currentTopic);
      expect(stamped.keyConcepts, base.keyConcepts);
      expect(stamped.confidence, base.confidence);
    });

    test('defaults to onDevice — the safe claim when nothing stamped it', () {
      expect(const PageContext(currentTopic: 'x').ranOn, AiRanOn.onDevice);
      expect(PageContext.empty.ranOn, AiRanOn.onDevice);
    });
  });

  test('RAG retrieval is on-device by construction', () {
    // A constant, not a runtime check: the embedder provider is hardcoded to
    // the local model and CloudGatewayProvider.embed throws. If a cloud
    // embedder is ever wired, this promise must be revisited deliberately.
    expect(kRagRetrievalIsAlwaysOnDevice, isTrue);
  });
}
