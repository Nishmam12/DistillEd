// The plugin's one model slot (docs/TECH_MIGRATION_PLAN.md, phase 4.5). Every
// embedder call runs one at a time, and a model is loaded only after the one that
// held the slot has been released.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/data/embeddings/embedder_slot.dart';

class _Owner implements EmbedderSlotOwner {
  _Owner(this.name, this.log);

  final String name;
  final List<String> log;

  @override
  Future<void> releaseFromSlot() async => log.add('release $name');
}

void main() {
  test('calls run one at a time, never overlapping', () async {
    final slot = EmbedderSlot();
    var inside = 0;
    var overlaps = 0;

    Future<void> call() => slot.run(() async {
          inside++;
          if (inside > 1) overlaps++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inside--;
        });

    await Future.wait([call(), call(), call()]);

    expect(overlaps, 0);
  });

  test('loading a second owner releases the first one before it loads',
      () async {
    final log = <String>[];
    final slot = EmbedderSlot();
    final serving = _Owner('serving', log);
    final target = _Owner('target', log);

    await slot.run(() async {
      await slot.claim(serving);
      log.add('load serving');
    });
    await slot.run(() async {
      await slot.claim(target);
      log.add('load target');
    });

    expect(log, ['load serving', 'release serving', 'load target']);
  });

  test('the owner that already holds the slot releases nothing when it claims again',
      () async {
    final log = <String>[];
    final slot = EmbedderSlot();
    final serving = _Owner('serving', log);

    await slot.run(() async => slot.claim(serving));
    await slot.run(() async => slot.claim(serving));

    expect(log, isEmpty);
  });

  test('an owner that released itself leaves nothing for the slot to release',
      () async {
    final log = <String>[];
    final slot = EmbedderSlot();
    final serving = _Owner('serving', log);
    final target = _Owner('target', log);

    await slot.run(() async {
      await slot.claim(serving);
      slot.released(serving);
    });
    await slot.run(() async => slot.claim(target));

    expect(log, isEmpty);
  });
}
