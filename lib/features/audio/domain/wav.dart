// Reading 16 kHz mono WAV recordings (docs/AI_PIPELINE_PLAN.md, item 14).
//
// The speech models take raw 16 kHz mono 16-bit PCM — "not a WAV file", and
// nothing resamples or converts it — so a lecture is recorded as exactly that,
// in a WAV container `record` writes, and the samples are lifted out of it here.
//
// Tolerant on purpose. The encoder only comes back to fill in the sizes when the
// recording is stopped cleanly; a lecture that ends with the app killed has a
// header whose sizes still say zero and audio that is entirely intact, and
// refusing it would throw away an hour of someone's lecture.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// What a WAV header says about its samples.
class WavInfo {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  /// Where the samples start in the file.
  final int dataOffset;

  /// How many bytes of samples there are.
  final int dataLength;

  const WavInfo({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
  });

  /// 16 kHz, mono, 16-bit: the one format the speech models consume as it is.
  bool get isSpeechFormat =>
      sampleRate == 16000 && channels == 1 && bitsPerSample == 16;
}

/// Reads the header of a WAV file from its first bytes [head].
///
/// Walks the chunks to the `data` chunk rather than assuming it sits at byte 44
/// — a file with an extra `LIST` chunk puts it later. [fileLength] is the whole
/// file's size (defaults to [head]'s length) and bounds the sample count, so a
/// size that is zero (never filled in) or too large (file cut short) both mean
/// "the rest of the file".
///
/// Throws [FormatException] for anything that is not a WAV with a format chunk
/// and a data chunk.
WavInfo parseWavHeader(Uint8List head, {int? fileLength}) {
  final total = fileLength ?? head.length;
  if (head.length < 12 ||
      String.fromCharCodes(head, 0, 4) != 'RIFF' ||
      String.fromCharCodes(head, 8, 12) != 'WAVE') {
    throw const FormatException('Not a WAV file');
  }

  final view = ByteData.sublistView(head);
  int? sampleRate, channels, bits;
  var offset = 12;
  while (offset + 8 <= head.length) {
    final id = String.fromCharCodes(head, offset, offset + 4);
    final size = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;

    if (id == 'fmt ' && body + 16 <= head.length) {
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      bits = view.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (sampleRate == null || channels == null || bits == null) {
        throw const FormatException('WAV data before its format chunk');
      }
      final available = math.max(0, total - body);
      return WavInfo(
        sampleRate: sampleRate,
        channels: channels,
        bitsPerSample: bits,
        dataOffset: body,
        dataLength: size == 0 || size > available ? available : size,
      );
    }
    offset = body + size + (size & 1); // chunks are padded to an even size
  }
  throw const FormatException('WAV file has no data chunk');
}

/// A 16 kHz mono WAV file opened for reading windows of samples.
///
/// Reads only the window asked for, so an hour-long lecture (over 100 MB) is
/// never held in memory.
class WavSource {
  WavSource._(this._file, this.info);

  final RandomAccessFile _file;
  final WavInfo info;

  /// 16 kHz × 2 bytes: the number of bytes in one millisecond of audio.
  static const int _bytesPerMs = 32;

  /// Opens [path]. Throws [FormatException] when it is not a WAV in the speech
  /// format — misreading 44.1 kHz stereo as 16 kHz mono would play at the wrong
  /// speed and transcribe as noise, so it is refused up front.
  static Future<WavSource> open(String path) async {
    final file = await File(path).open();
    try {
      final length = await file.length();
      final head = await file.read(math.min(length, 4096));
      final info = parseWavHeader(head, fileLength: length);
      if (!info.isSpeechFormat) {
        throw FormatException('Not 16 kHz mono 16-bit: '
            '${info.sampleRate} Hz, ${info.channels} ch, ${info.bitsPerSample}-bit');
      }
      return WavSource._(file, info);
    } catch (_) {
      await file.close();
      rethrow;
    }
  }

  int get durationMs => info.dataLength ~/ _bytesPerMs;

  /// The samples of `[startMs, endMs)` as raw 16-bit little-endian PCM — cut to
  /// what the file holds, empty when the window is past its end.
  Future<Uint8List> readPcm({required int startMs, required int endMs}) async {
    final start = (startMs * _bytesPerMs).clamp(0, info.dataLength);
    final end = (endMs * _bytesPerMs).clamp(0, info.dataLength);
    if (end <= start) return Uint8List(0);
    await _file.setPosition(info.dataOffset + start);
    return _file.read(end - start);
  }

  Future<void> close() => _file.close();
}
