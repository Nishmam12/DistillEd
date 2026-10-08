// The plugin's one model slot (docs/TECH_MIGRATION_PLAN.md, phase 4.5).
//
// flutter_edge_ai's embedder cache holds ONE model: asking for another closes the
// first. So the app's embedders share this slot. Calls run one after another, and
// a model is loaded only once the embedder that held the slot has released its
// model. Without it, a question could find its model closed under it mid-call, and
// a rollout's target load would close the serving model without anyone knowing.

import 'dart:async';

/// Something that can hold the plugin's model and give it up when asked.
abstract class EmbedderSlotOwner {
  /// Drops the model this owner holds. The slot calls this while it is running a
  /// call itself, so an implementation must not take the slot again.
  Future<void> releaseFromSlot();
}

class EmbedderSlot {
  EmbedderSlot();

  /// The app's one slot. Embedders use it unless they are given another.
  static final EmbedderSlot shared = EmbedderSlot();

  Future<void> _lane = Future<void>.value();
  EmbedderSlotOwner? _holder;

  /// Runs [body] after every call before it has finished, so calls never overlap.
  Future<T> run<T>(Future<T> Function() body) {
    final previous = _lane;
    final done = Completer<void>();
    _lane = done.future;
    return previous.then((_) => body()).whenComplete(done.complete);
  }

  /// [owner] is about to load its model, so whoever holds the slot releases first.
  /// Call inside [run].
  Future<void> claim(EmbedderSlotOwner owner) async {
    final holder = _holder;
    _holder = owner;
    if (holder != null && !identical(holder, owner)) {
      await holder.releaseFromSlot();
    }
  }

  /// [owner] has released its model itself, so the slot is free.
  void released(EmbedderSlotOwner owner) {
    if (identical(_holder, owner)) _holder = null;
  }
}
