// A handle on one read of a page: lets the caller stop its expensive part and
// watch how far it has got.
//
// Written after the first device test, where a page of 23 photos was read on
// the device for over ten minutes with no way to stop it, until Android killed
// the app for memory. A read is still never abandoned half way — stopping only
// ends the DEEP reading (the vision model). Whatever is left is read the cheap
// way, so the page always comes back with something.

import 'package:flutter/foundation.dart';

/// How far the deep reading of a page's pictures has got.
@immutable
class PageReadProgress {
  /// Pictures the vision model has started on, this one included (from 1).
  final int picture;

  /// Pictures this read will give the vision model, at most.
  final int of;

  const PageReadProgress({required this.picture, required this.of});

  @override
  bool operator ==(Object other) =>
      other is PageReadProgress && other.picture == picture && other.of == of;

  @override
  int get hashCode => Object.hash(picture, of);

  @override
  String toString() => 'PageReadProgress($picture of $of)';
}

class PageReadControl {
  bool _stopped = false;

  /// Whether [stop] has been called.
  bool get stopped => _stopped;

  /// Ends the deep reading. The read in flight finishes its current picture
  /// (a model call cannot be interrupted) and reads the rest cheaply.
  void stop() => _stopped = true;

  /// Null until the first picture goes to the vision model.
  final ValueNotifier<PageReadProgress?> progress = ValueNotifier(null);

  void dispose() => progress.dispose();
}
