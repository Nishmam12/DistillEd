import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/editor/render/scene_element_painter.dart';
import 'package:distill_ed/editor/render/scene_image_cache.dart';

// A real ui.Image made via the test engine's supported path (picture.toImage);
// the headless test engine does not decode PNG bytes via instantiateImageCodec,
// so the cache's decoder is injected for deterministic tests.
Future<ui.Image> _solidImage(int size) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  return recorder.endRecording().toImage(size, size);
}

final Uint8List _dummyBytes = Uint8List.fromList(const [1, 2, 3]);

void main() {
  group('resolvePath', () {
    test('joins base and relative path', () {
      expect(SceneImageCache.resolvePath('/docs', 'imports/a.png'),
          '/docs/imports/a.png');
    });
    test('does not double the separator', () {
      expect(SceneImageCache.resolvePath('/docs/', 'a.png'), '/docs/a.png');
    });
    test('returns the relative path unchanged when base is empty', () {
      expect(SceneImageCache.resolvePath('', 'a.png'), 'a.png');
    });
    test('leaves absolute and drive paths alone', () {
      expect(SceneImageCache.resolvePath('/docs', '/abs/x.png'), '/abs/x.png');
      expect(SceneImageCache.resolvePath('/docs', r'C:\x.png'), r'C:\x.png');
    });
  });

  testWidgets('ensure loads, get returns the image, version bumps + dedupes',
      (tester) async {
    await tester.runAsync(() async {
      var decodes = 0;
      final cache = SceneImageCache(
        baseDir: '/docs',
        readBytes: (_) async => _dummyBytes,
        decode: (_) async {
          decodes++;
          return _solidImage(8);
        },
      );
      addTearDown(cache.dispose);

      expect(cache.get('a.png'), isNull);
      expect(cache.version, 0);

      await cache.ensure(['a.png']);
      expect(cache.get('a.png'), isA<ui.Image>());
      expect(cache.version, 1);

      // Already loaded → no second decode, version unchanged.
      await cache.ensure(['a.png']);
      expect(cache.version, 1);
      expect(decodes, 1);
    });
  });

  testWidgets('keeps at most maxEntries bitmaps, dropping the least recent',
      (tester) async {
    await tester.runAsync(() async {
      final cache = SceneImageCache(
        baseDir: '/docs',
        readBytes: (_) async => _dummyBytes,
        decode: (_) => _solidImage(4),
      );
      addTearDown(cache.dispose);

      await cache.ensure(['p0.png']);
      for (var i = 1; i < SceneImageCache.maxEntries; i++) {
        await cache.ensure(['p$i.png']);
      }
      cache.get('p0.png'); // p0 is drawn again, so p1 is now the oldest
      await cache.ensure(['extra.png']);

      expect(cache.get('p0.png'), isNotNull);
      expect(cache.get('p1.png'), isNull);
      expect(cache.get('extra.png'), isNotNull);
    });
  });

  testWidgets('a failed load is not retried on every ensure', (tester) async {
    await tester.runAsync(() async {
      var reads = 0;
      final cache = SceneImageCache(
        baseDir: '/docs',
        readBytes: (_) async {
          reads++;
          throw const _LoadFailure();
        },
      );
      addTearDown(cache.dispose);

      await cache.ensure(['bad.png']);
      await cache.ensure(['bad.png']);

      expect(reads, 1);
    });
  });

  testWidgets('a decode finishing after dispose does not throw or leak',
      (tester) async {
    await tester.runAsync(() async {
      final cache = SceneImageCache(
        baseDir: '/docs',
        readBytes: (_) async => _dummyBytes,
        decode: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _solidImage(4);
        },
      );
      final pending = cache.ensure(['a.png']);
      cache.dispose();
      await pending; // must complete without "used after dispose"
    });
  });

  testWidgets('a failed load leaves the path unloaded (no throw)',
      (tester) async {
    await tester.runAsync(() async {
      final cache = SceneImageCache(
        baseDir: '/docs',
        readBytes: (_) async => throw const _LoadFailure(),
      );
      addTearDown(cache.dispose);
      await cache.ensure(['missing.png']);
      expect(cache.get('missing.png'), isNull);
      expect(cache.version, 0);
    });
  });

  testWidgets('painter draws a real bitmap for an ImageElement', (tester) async {
    await tester.runAsync(() async {
      final cache = SceneImageCache(
        baseDir: '',
        readBytes: (_) async => _dummyBytes,
        decode: (_) async => _solidImage(16),
      );
      addTearDown(cache.dispose);
      await cache.ensure(['pic.png']);
      expect(cache.get('pic.png'), isNotNull);

      const el = ImageElement(
        id: 'i',
        zOrder: 0,
        geometryData: [0, 0, 64, 64],
        relativeImagePath: 'pic.png',
      );

      final recorder = ui.PictureRecorder();
      SceneElementPainter.paint(Canvas(recorder), el,
          imageResolver: cache.get);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 64);
      expect(image.width, 64);
      image.dispose();
      picture.dispose();
    });
  });

  group('natural size', () {
    test('a picture that cannot be read has no size', () async {
      expect(
        await SceneImageCache.naturalSize('/no/such/picture.png'),
        isNull,
      );
    });
  });

  group('decode size', () {
    test('a picture larger than the limit is decoded smaller, keeping its shape',
        () {
      final size = SceneImageCache.decodeSize(4032, 3024, maxSide: 2048);

      expect(size.width, 2048);
      expect(size.height, 1536);
    });

    test('a picture within the limit is decoded at its own size', () {
      final size = SceneImageCache.decodeSize(300, 200, maxSide: 2048);

      expect(size.width, 300);
      expect(size.height, 200);
    });

    test('a very tall picture keeps its aspect and never reaches zero', () {
      final size = SceneImageCache.decodeSize(1, 100000, maxSide: 2048);

      expect(size.height, 2048);
      expect(size.width, 1);
    });
  });
}

class _LoadFailure implements Exception {
  const _LoadFailure();
}
