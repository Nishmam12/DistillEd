import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/presentation/model_memory_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int releases;
  late ModelMemoryObserver observer;

  setUp(() {
    releases = 0;
    observer = ModelMemoryObserver(release: () async => releases++);
  });

  test('memory pressure releases the models', () {
    observer.didHaveMemoryPressure();
    expect(releases, 1);
  });

  test('leaving the screen releases the models', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(releases, 1);
  });

  test('a brief interruption does not — the model would reload for nothing',
      () {
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(releases, 0);
  });

  test('a release that throws is contained', () async {
    final failing = ModelMemoryObserver(release: () async => throw StateError('x'));
    failing.didHaveMemoryPressure();
    await Future<void>.delayed(Duration.zero); // nothing escapes as an error
  });
}
