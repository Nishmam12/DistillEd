// What each embedding model is fed (docs/TECH_MIGRATION_PLAN.md, phase 5.3).
// The 300M's plugin writes its prefixes, so the app adds only the title; for
// EmbeddingGemma 2 the app writes the Hugging Face card's format itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/domain/rag/prompt_contract.dart';

void main() {
  group('EmbeddingGemma 2', () {
    const contract = PromptContract.appGemma2;

    test('a document carries its title in the title slot', () {
      expect(
        contract.embeddingInput('Physics', 'Newton'),
        'title: Physics | text: Newton',
      );
    });

    test('a document with no title says none, as the card asks', () {
      expect(
        contract.embeddingInput(null, 'Newton'),
        'title: none | text: Newton',
      );
    });

    test('a query carries the search prefix', () {
      expect(
        contract.queryInput('what is force'),
        'task: search result | query: what is force',
      );
    });
  });

  group('EmbeddingGemma 300M', () {
    const contract = PromptContract.pluginGemma300m;

    test('the title rides at the front of the passage', () {
      expect(contract.embeddingInput('Physics', 'Newton'), 'Physics\n\nNewton');
    });

    test('a query is left to the plugin', () {
      expect(contract.queryInput('what is force'), 'what is force');
    });
  });
}
