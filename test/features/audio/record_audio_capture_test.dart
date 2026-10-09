import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/audio/data/record_audio_capture.dart';
import 'package:distill_ed/features/audio/domain/audio_ports.dart';
import 'package:record/record.dart';

void main() {
  test('speech recordings ask for 16 kHz mono WAV — what the models take as '
      'they are', () {
    final config = RecordAudioCapture.configFor(AudioFormat.speechWav);

    expect(config.encoder, AudioEncoder.wav);
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
  });

  test('ordinary recordings stay compressed AAC', () {
    final config = RecordAudioCapture.configFor(AudioFormat.aac);

    expect(config.encoder, AudioEncoder.aacLc);
  });
}
