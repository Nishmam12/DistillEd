// Identity for Learning Memory records that are *events* rather than facts.
//
// A concept has a natural key (notebook + normalized name) that two devices
// derive independently. An event — a quiz attempt, a study session — has no
// such key, so it gets an id assigned once at creation and never rewritten.
// See the sync-ready note in `concept_mastery.dart`.

import 'dart:math';

/// 128 bits of secure randomness as lowercase hex — the same collision
/// resistance as a UUIDv4, without taking a dependency for one function.
String newStableId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
