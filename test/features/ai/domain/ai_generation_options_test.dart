import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/ai_generation_options.dart';

void main() {
  group('AiGenerationOptions', () {
    test('defaults are sensible and stop sequences default to empty', () {
      const options = AiGenerationOptions();
      expect(options.temperature, 0.7);
      expect(options.maxTokens, isNull);
      expect(options.stopSequences, isEmpty);
      expect(options.topP, isNull);
    });

    test('precise preset is deterministic', () {
      expect(AiGenerationOptions.precise.temperature, 0.0);
    });

    test('copyWith overrides only the given fields', () {
      const base = AiGenerationOptions(temperature: 0.5, maxTokens: 128);
      final tweaked = base.copyWith(temperature: 0.2);
      expect(tweaked.temperature, 0.2);
      expect(tweaked.maxTokens, 128); // preserved
      expect(base.temperature, 0.5); // original untouched
    });

    test('equality compares stop sequences by value', () {
      expect(
        const AiGenerationOptions(stopSequences: ['END']),
        const AiGenerationOptions(stopSequences: ['END']),
      );
      expect(
        const AiGenerationOptions(stopSequences: ['END']),
        isNot(const AiGenerationOptions(stopSequences: ['STOP'])),
      );
    });
  });
}
