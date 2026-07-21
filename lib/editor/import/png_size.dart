// Reads a PNG's pixel dimensions straight out of its header.
//
// Imported pages need their aspect ratio to be fitted onto a sheet, but the PDF
// renderer hands back cached files rather than sizes. Fully decoding every page
// just to measure it would cost a bitmap per page; the dimensions are in the
// first 24 bytes, so read those instead.
//
// PNG layout (all big-endian): 8-byte signature, then the IHDR chunk —
// 4-byte length, 4-byte type "IHDR", 4-byte width, 4-byte height. The spec
// requires IHDR to be the first chunk, so the offsets are fixed.

import 'dart:typed_data';
import 'dart:ui';

const List<int> _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

/// The pixel size of the PNG in [bytes], or null when it isn't a PNG, is
/// truncated, or declares a zero dimension.
///
/// Null is a "measure it some other way" signal, not an error — callers fall
/// back rather than failing an import over a header they couldn't read.
Size? pngPixelSize(Uint8List bytes) {
  // 24 bytes: signature (8) + chunk length (4) + "IHDR" (4) + w (4) + h (4).
  if (bytes.length < 24) return null;
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) return null;
  }
  if (bytes[12] != 0x49 || // I
      bytes[13] != 0x48 || // H
      bytes[14] != 0x44 || // D
      bytes[15] != 0x52) {
    return null;
  }

  final width = _uint32(bytes, 16);
  final height = _uint32(bytes, 20);
  if (width == 0 || height == 0) return null;
  return Size(width.toDouble(), height.toDouble());
}

int _uint32(Uint8List b, int at) =>
    (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
