import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/domain/context_engine/context_engine.dart';
import 'package:margo/features/ai/domain/context_engine/page_context.dart';

void main() {
  Map<String, dynamic>? parse(String raw) =>
      ContextEngine.tryExtractJsonObject(raw);

  test('a complete object parses as before', () {
    expect(parse('noise {"a": [1, 2]} tail'), {
      'a': [1, 2],
    });
  });

  test('a reply cut mid-string keeps the items that arrived whole', () {
    final json = parse('{"cards": [{"q": "one", "a": "1"}, {"q": "two", "a": "t');

    // The half-written second card may survive without its answer; callers
    // validate their items. The whole first one must.
    expect((json!['cards'] as List).first, {'q': 'one', 'a': '1'});
  });

  test('a reply cut after a complete item is closed as is', () {
    expect(parse('{"topic": "x", "concepts": ["a", "b"'), {
      'topic': 'x',
      'concepts': ['a', 'b'],
      kTruncatedJsonKey: true,
    });
  });

  test('a salvaged reply reads as a partial PageContext; a whole one does not',
      () {
    expect(
        PageContext.fromJson(parse('{"currentTopic": "x", "subtopics": ["a"')!)
            .partial,
        isTrue);
    expect(PageContext.fromJson(parse('{"currentTopic": "x"}')!).partial,
        isFalse);
  });

  test('text with no recoverable object is still null', () {
    expect(parse('no json here'), isNull);
    expect(parse('{"a": '), isNull);
  });
}
