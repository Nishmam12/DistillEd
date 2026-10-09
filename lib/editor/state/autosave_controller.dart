// Debounced autosave: coalesces rapid edits into one save after a quiet period.
// Editor mutations call [schedule]; [flush] forces a pending save (e.g. on
// page switch / app pause) and waits for any save already running; [dispose]
// cancels.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

class AutosaveController {
  final Duration debounce;
  final Future<void> Function() onSave;

  /// Told when a save throws. A failed save is not rethrown from the timer (an
  /// unhandled error there would be lost anyway); the next edit schedules another.
  final void Function(Object error, StackTrace stack)? onError;

  Timer? _timer;
  Future<void>? _saving;
  bool _again = false;

  AutosaveController({
    required this.onSave,
    this.debounce = const Duration(seconds: 1),
    this.onError,
  });

  bool get hasPending => (_timer?.isActive ?? false) || _saving != null;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_run());
    });
  }

  /// Saves now if an edit is waiting, and waits for a save that is running. An
  /// edit that lands during a save is saved by a second pass before this returns.
  Future<void> flush() async {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = null;
      await _run();
    } else if (_saving != null) {
      await _saving;
    }
  }

  /// One save at a time. A request made during a save marks it to go round again,
  /// so the later edit is not lost and two saves never overlap.
  Future<void> _run() {
    if (_saving != null) {
      _again = true;
      return _saving!;
    }
    return _saving = _saveLoop().whenComplete(() => _saving = null);
  }

  Future<void> _saveLoop() async {
    do {
      _again = false;
      try {
        await onSave();
      } catch (error, stack) {
        (onError ?? _log)(error, stack);
      }
    } while (_again);
  }

  static void _log(Object error, StackTrace stack) =>
      debugPrint('autosave failed: $error');

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
