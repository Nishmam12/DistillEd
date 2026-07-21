import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/import/png_size.dart';

void main() {
  /// The first 24 bytes of a PNG declaring [width] x [height] — signature,
  /// IHDR length, "IHDR", then the two big-endian dimensions.
  Uint8List header(int width, int height, {List<int>? signature}) {
    final b = BytesBuilder()
      ..add(signature ?? const [137, 80, 78, 71, 13, 10, 26, 10])
      ..add(const [0, 0, 0, 13])
      ..add('IHDR'.codeUnits)
      ..add([
        (width >> 24) & 0xFF,
        (width >> 16) & 0xFF,
        (width >> 8) & 0xFF,
        width & 0xFF,
        (height >> 24) & 0xFF,
        (height >> 16) & 0xFF,
        (height >> 8) & 0xFF,
        height & 0xFF,
      ]);
    return b.toBytes();
  }

  group('pngPixelSize', () {
    test('reads the declared dimensions', () {
      expect(pngPixelSize(header(1240, 1754)), const Size(1240, 1754));
    });

    test('handles dimensions past one byte in every position', () {
      expect(pngPixelSize(header(0x01020304, 0x05060708)),
          const Size(16909060, 84281096));
    });

    test('trailing image data is ignored', () {
      final withBody = Uint8List.fromList(
          [...header(800, 600), ...List.filled(4096, 0x42)]);
      expect(pngPixelSize(withBody), const Size(800, 600));
    });

    test('a non-PNG signature is rejected', () {
      // A JPEG's opening bytes.
      final jpeg = header(100, 100,
          signature: const [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      expect(pngPixelSize(jpeg), isNull);
    });

    test('a PNG whose first chunk is not IHDR is rejected', () {
      final bytes = header(100, 100);
      bytes[12] = 0x66; // corrupt the "IHDR" tag
      expect(pngPixelSize(bytes), isNull);
    });

    test('a truncated header is rejected rather than read past the end', () {
      expect(pngPixelSize(header(100, 100).sublist(0, 23)), isNull);
      expect(pngPixelSize(Uint8List(0)), isNull);
    });

    test('a zero dimension is rejected', () {
      expect(pngPixelSize(header(0, 100)), isNull);
      expect(pngPixelSize(header(100, 0)), isNull);
    });
  });
}
