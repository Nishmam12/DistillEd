// Gives the on-device models' memory back when the system needs it.
//
// The language model is kept resident for minutes after its last use, because a
// cold load costs 4-17 s. That is only safe if it is let go the moment the
// device is short of memory or the app leaves the screen: a 2.6 GB model that
// stays resident under pressure is swapped out and read back in, which is slower
// than reloading it, and it is what gets the app (and everything else) killed.

import 'dart:async';

import 'package:flutter/widgets.dart';

class ModelMemoryObserver with WidgetsBindingObserver {
  /// Unloads whatever model memory can be unloaded. Must not throw.
  final Future<void> Function() _release;

  ModelMemoryObserver({required this._release});

  /// How many times the system has reported memory pressure. A page read that
  /// sees this change stops asking for the model (see
  /// `PageContentExtractor`): the model was just let go, and each further
  /// picture would load it again.
  int get pressureCount => _pressureCount;
  int _pressureCount = 0;

  /// Starts listening. Safe to call once; pair with [detach].
  void attach() => WidgetsBinding.instance.addObserver(this);

  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didHaveMemoryPressure() {
    _pressureCount++;
    _releaseNow('memory pressure');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `paused` is the app leaving the screen. `inactive` (the notification
    // shade, a permission dialog) is deliberately not: it comes and goes within
    // a second, and the model would be reloaded for nothing.
    if (state == AppLifecycleState.paused) _releaseNow('app backgrounded');
  }

  void _releaseNow(String reason) {
    debugPrint('[AiPerf] releasing on-device models: $reason');
    unawaited(_release().catchError((Object _) {}));
  }
}
