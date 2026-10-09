import 'package:flutter_test/flutter_test.dart';

import 'package:distill_ed/editor/state/ink_gesture_providers.dart';

void main() {
  group('enableInkGesture — turning a gesture on', () {
    test('switches it on and downloads its model', () async {
      final events = <String>[];

      final message = await enableInkGesture(
        setEnabled: (v) async => events.add('set $v'),
        downloadModel: () async => events.add('download'),
      );

      expect(message, isNull);
      expect(events, ['set true', 'download']);
    });

    test('a download that fails switches it back off, and says why', () async {
      final events = <String>[];

      final message = await enableInkGesture(
        setEnabled: (v) async => events.add('set $v'),
        downloadModel: () async => throw StateError('offline'),
      );

      expect(events, ['set true', 'set false'],
          reason: 'a gesture that cannot work must not look like it is on');
      expect(message, contains("Couldn't download"));
    });
  });
}
