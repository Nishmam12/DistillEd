// Which vision model reads an image, per AiProcessingMode.
//
// The privacy-relevant assertion is the first group's: with cloud-first OFF the
// cloud transcriber must not be touched at all, no matter what the local one
// returns. The performance-relevant one is the second group's: with it ON the
// LOCAL model must not be loaded, which is the whole point of the mode.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/image_transcriber.dart';
import 'package:inkflow/features/ai/domain/routing/cloud_first_transcriber.dart';

class RecordingTranscriber implements ImageTranscriber {
  final String reply;
  final Object? throws;
  int calls = 0;

  RecordingTranscriber(this.reply, {this.throws});

  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    calls++;
    if (throws != null) throw throws!;
    return reply;
  }
}

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  Future<String> read(CloudFirstTranscriber t) =>
      t.transcribeImage(bytes, prompt: 'p');

  group('cloud-first off', () {
    test('reads on-device and never touches the cloud', () async {
      final local = RecordingTranscriber('local text');
      final cloud = RecordingTranscriber('cloud text');

      final result = await read(CloudFirstTranscriber(
        local: local,
        cloud: cloud,
        preferCloud: () => false,
      ));

      expect(result, 'local text');
      expect(cloud.calls, 0, reason: 'nothing may leave the device');
      expect(local.calls, 1);
    });
  });

  group('cloud-first on', () {
    test('reads in the cloud without loading the local model', () async {
      final local = RecordingTranscriber('local text');
      final cloud = RecordingTranscriber('cloud text');

      final result = await read(CloudFirstTranscriber(
        local: local,
        cloud: cloud,
        preferCloud: () => true,
      ));

      expect(result, 'cloud text');
      expect(local.calls, 0, reason: 'the 2.6 GB model must not be loaded');
    });

    test('falls back to on-device when the cloud call fails', () async {
      final local = RecordingTranscriber('local text');
      final cloud = RecordingTranscriber('',
          throws: AiGenerationException('gateway 404'));

      final result = await read(CloudFirstTranscriber(
        local: local,
        cloud: cloud,
        preferCloud: () => true,
      ));

      expect(result, 'local text',
          reason: 'a slow read beats reporting the page as unreadable');
      expect(cloud.calls, 1);
      expect(local.calls, 1);
    });

    test('falls back when no cloud transcriber is wired at all', () async {
      final local = RecordingTranscriber('local text');

      final result = await read(CloudFirstTranscriber(
        local: local,
        cloud: null,
        preferCloud: () => true,
      ));

      expect(result, 'local text');
      expect(local.calls, 1);
    });
  });

  test('the mode is read per call, not captured at construction', () async {
    final local = RecordingTranscriber('local text');
    final cloud = RecordingTranscriber('cloud text');
    var prefer = false;

    final t = CloudFirstTranscriber(
      local: local,
      cloud: cloud,
      preferCloud: () => prefer,
    );

    expect(await read(t), 'local text');
    prefer = true;
    expect(await read(t), 'cloud text',
        reason: 'switching modes must take effect without a rebuild');
  });
}
