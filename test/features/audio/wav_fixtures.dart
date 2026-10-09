// Synthetic 16 kHz mono audio for the speech tests: PCM built from runs of tone
// and silence, and a WAV file wrapped around it.

import 'dart:io';
import 'dart:typed_data';

import 'package:distill_ed/features/audio/domain/wav.dart';

/// 16 kHz mono 16-bit PCM from `(milliseconds, amplitude)` runs. A run with a
/// non-zero amplitude is a square wave at that level; zero is silence.
Uint8List pcm(List<(int, int)> runs) {
  final out = BytesBuilder();
  for (final (ms, amp) in runs) {
    final data = ByteData(ms * 16 * 2);
    for (var i = 0; i < ms * 16; i++) {
      data.setInt16(i * 2, amp == 0 ? 0 : (i.isEven ? amp : -amp), Endian.little);
    }
    out.add(data.buffer.asUint8List());
  }
  return out.toBytes();
}

/// Writes [samples] as a 16 kHz mono WAV and opens it.
Future<WavSource> wavOf(Directory dir, Uint8List samples) async =>
    WavSource.open(writeWav(dir, samples));

/// Writes [samples] as a 16 kHz mono WAV file in [dir]; returns its path.
String writeWav(Directory dir, Uint8List samples, {String name = 'a.wav'}) {
  final header = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + samples.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, samples.length, Endian.little);
  final file = File('${dir.path}/$name')
    ..writeAsBytesSync([...header.buffer.asUint8List(), ...samples]);
  return file.path;
}
