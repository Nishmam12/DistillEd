// What makes two reads "the same read": the exact image sent, what kind of read
// it was, which prompt wrote it and which model answered. If any of those is
// left out of the key, a cache hit can serve a reading that the current prompt
// or model would not have produced — silently, and for ever.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/figure.dart';
import 'package:inkflow/features/ai/domain/read_cache.dart';

void main() {
  final bytes = Uint8List.fromList(const [1, 2, 3, 4]);

  String key({
    String kind = 'img',
    Uint8List? content,
    String version = 'ocr1',
    String model = 'gemma-local',
  }) =>
      readCacheKey(
          kind: kind,
          content: content ?? bytes,
          version: version,
          modelId: model);

  group('readCacheKey', () {
    test('the same read always has the same key', () {
      expect(key(), key());
      expect(key(content: Uint8List.fromList(const [1, 2, 3, 4])), key(),
          reason: 'content is hashed by value, not identity');
    });

    test('a different picture is a different read', () {
      expect(key(content: Uint8List.fromList(const [1, 2, 3, 5])), isNot(key()));
    });

    test('a different kind of read of the same bytes is a different read', () {
      // The same pixels asked "what text is here" and "what does this figure
      // show" are different questions with different answers.
      expect(key(kind: 'ink'), isNot(key()));
    });

    test('a new prompt version reads afresh', () {
      expect(key(version: 'ocr2'), isNot(key()));
    });

    test('a different model reads afresh', () {
      expect(key(model: 'cloud-mid'), isNot(key()));
    });

    test('the key does not carry the content itself', () {
      // What the student wrote must not be recoverable from a key.
      final k = key(content: Uint8List.fromList('my secret notes'.codeUnits));
      expect(k, isNot(contains('secret')));
      expect(k.length, lessThan(120));
    });
  });

  group('InMemoryReadCache', () {
    test('finds what was saved, text and figure both', () async {
      final cache = InMemoryReadCache();
      const figure = FigureDescription(
          kind: FigureKind.chart, summary: 'A chart of revenue by quarter.');

      await cache.save('k', const CachedRead(text: 'hello', figure: figure));

      final hit = await cache.find('k');
      expect(hit!.text, 'hello');
      expect(hit.figure, figure);
    });

    test('a read with no figure is remembered as such', () async {
      final cache = InMemoryReadCache();
      await cache.save('k', const CachedRead(text: 'just words'));

      expect((await cache.find('k'))!.figure, isNull);
    });

    test('saving under a key again replaces the old read', () async {
      final cache = InMemoryReadCache();
      await cache.save('k', const CachedRead(text: 'old'));
      await cache.save('k', const CachedRead(text: 'new'));

      expect((await cache.find('k'))!.text, 'new');
    });

    test('an unknown key finds nothing', () async {
      expect(await InMemoryReadCache().find('missing'), isNull);
    });
  });
}
