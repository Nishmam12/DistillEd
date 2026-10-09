import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/state/autosave_controller.dart';

void main() {
  test('debounce coalesces rapid edits into one save', () async {
    var saves = 0;
    final a = AutosaveController(
        onSave: () async => saves++,
        debounce: const Duration(milliseconds: 50));

    a.schedule();
    a.schedule();
    a.schedule();
    expect(saves, 0);

    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(saves, 1);
    a.dispose();
  });

  test('flush saves a pending edit immediately', () async {
    var saves = 0;
    final a = AutosaveController(
        onSave: () async => saves++,
        debounce: const Duration(seconds: 10));

    a.schedule();
    expect(a.hasPending, true);
    await a.flush();
    expect(saves, 1);
    expect(a.hasPending, false);
    a.dispose();
  });

  test('flush is a no-op when nothing is pending', () async {
    var saves = 0;
    final a = AutosaveController(onSave: () async => saves++);
    await a.flush();
    expect(saves, 0);
    a.dispose();
  });

  test('flush waits for a save that is already running', () async {
    final gate = Completer<void>();
    var finished = false;
    final a = AutosaveController(
        onSave: () async {
          await gate.future;
          finished = true;
        },
        debounce: const Duration(milliseconds: 5));

    a.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final flushed = a.flush();
    gate.complete();
    await flushed;

    expect(finished, isTrue);
    a.dispose();
  });

  test('an edit during a save is saved by a second pass, never overlapping',
      () async {
    final gate = Completer<void>();
    var running = 0, maxRunning = 0, saves = 0;
    final a = AutosaveController(
        onSave: () async {
          saves++;
          running++;
          maxRunning = running > maxRunning ? running : maxRunning;
          if (saves == 1) await gate.future;
          running--;
        },
        debounce: const Duration(milliseconds: 5));

    a.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 20)); // save 1 running
    a.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 20)); // wants save 2
    gate.complete();
    await a.flush();

    expect(saves, 2);
    expect(maxRunning, 1);
    a.dispose();
  });

  test('a failing save is reported, not thrown from the timer', () async {
    Object? seen;
    final a = AutosaveController(
        onSave: () async => throw StateError('disk full'),
        debounce: const Duration(milliseconds: 5),
        onError: (e, _) => seen = e);

    a.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(seen, isA<StateError>());
    a.dispose();
  });
}
