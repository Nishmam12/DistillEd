import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/audio/domain/wav.dart';

/// A WAV file of [samples] 16-bit samples, with the header `record` writes — or
/// a tolerant variation of it.
Uint8List wavBytes(
  List<int> samples, {
  int sampleRate = 16000,
  int channels = 1,
  int bits = 16,
  bool zeroSizes = false,
  bool withListChunk = false,
}) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  final list = withListChunk
      ? (BytesBuilder()
            ..add('LIST'.codeUnits)
            ..add((ByteData(4)..setUint32(0, 5, Endian.little)).buffer.asUint8List())
            ..add([1, 2, 3, 4, 5])
            ..add([0])) // chunks are padded to an even size
          .toBytes()
      : Uint8List(0);

  final header = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  final dataSize = zeroSizes ? 0 : data.lengthInBytes;
  ascii(0, 'RIFF');
  header.setUint32(4, zeroSizes ? 0 : 36 + list.length + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * bits ~/ 8, Endian.little);
  header.setUint16(32, channels * bits ~/ 8, Endian.little);
  header.setUint16(34, bits, Endian.little);
  // The 'data' chunk header goes AFTER any extra chunk.
  final out = BytesBuilder()
    ..add(header.buffer.asUint8List(0, 36))
    ..add(list)
    ..add('data'.codeUnits)
    ..add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List())
    ..add(data.buffer.asUint8List());
  return out.toBytes();
}

void main() {
  group('parseWavHeader', () {
    test('reads the format and finds the samples', () {
      final info = parseWavHeader(wavBytes([1, 2, 3, 4]));

      expect(info.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.dataOffset, 44);
      expect(info.dataLength, 8);
    });

    test('is 16 kHz mono 16-bit — what speech models take', () {
      expect(parseWavHeader(wavBytes([0])).isSpeechFormat, isTrue);
      expect(parseWavHeader(wavBytes([0], sampleRate: 44100)).isSpeechFormat,
          isFalse);
      expect(parseWavHeader(wavBytes([0], channels: 2)).isSpeechFormat, isFalse);
    });

    test('takes the samples from the data chunk, not byte 44', () {
      // The header is not always 44 bytes; an extra chunk shifts the data.
      final info = parseWavHeader(wavBytes([5, 6, 7], withListChunk: true));

      expect(info.dataOffset, 36 + 8 + 6 + 8);
      expect(info.dataLength, 6);
    });

    test('a recording cut off mid-write (sizes still zero) uses the rest of '
        'the file', () {
      // If the app is killed while recording, the encoder never came back to
      // fill the sizes in; the audio is all there.
      final bytes = wavBytes([1, 2, 3, 4, 5], zeroSizes: true);

      final info = parseWavHeader(bytes);

      expect(info.dataLength, bytes.length - 44);
    });

    test('a data size that overruns the file is clamped to the file', () {
      final bytes = wavBytes([1, 2, 3]);
      final cut = Uint8List.sublistView(bytes, 0, bytes.length - 2);

      expect(parseWavHeader(cut).dataLength, cut.length - 44);
    });

    test('something that is not a WAV file is a FormatException', () {
      expect(() => parseWavHeader(Uint8List.fromList(List.filled(64, 7))),
          throwsFormatException);
      expect(() => parseWavHeader(Uint8List(10)), throwsFormatException);
    });

    test('a WAV with no data chunk is a FormatException', () {
      final bytes = wavBytes([1, 2]);
      final noData = Uint8List.sublistView(bytes, 0, 36);

      expect(() => parseWavHeader(noData), throwsFormatException);
    });
  });

  group('WavSource — reading a window of samples from a file', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('inkflow_wav_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<WavSource> open(List<int> samples) async {
      final file = File('${dir.path}/a.wav')..writeAsBytesSync(wavBytes(samples));
      return WavSource.open(file.path);
    }

    test('knows its length in milliseconds', () async {
      final source = await open(List.filled(16000 * 3, 0)); // 3 s

      expect(source.durationMs, 3000);
      await source.close();
    });

    test('returns the samples of [startMs, endMs)', () async {
      final source = await open([for (var i = 0; i < 32000; i++) i % 1000]);

      final bytes = await source.readPcm(startMs: 500, endMs: 1000);

      expect(bytes.length, 8000 * 2);
      final first = ByteData.sublistView(bytes).getInt16(0, Endian.little);
      expect(first, 8000 % 1000); // sample 8000
      await source.close();
    });

    test('a window past the end is cut to what exists', () async {
      final source = await open(List.filled(16000, 0)); // 1 s

      final bytes = await source.readPcm(startMs: 900, endMs: 5000);

      expect(bytes.length, 1600 * 2);
      await source.close();
    });

    test('a window wholly past the end is empty', () async {
      final source = await open(List.filled(16000, 0));

      expect(await source.readPcm(startMs: 2000, endMs: 3000), isEmpty);
      await source.close();
    });

    test('a file that is not 16 kHz mono is refused, not misread', () async {
      final file = File('${dir.path}/b.wav')
        ..writeAsBytesSync(wavBytes([0, 0], sampleRate: 44100));

      await expectLater(WavSource.open(file.path), throwsFormatException);
    });
  });
}
