import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/data/persistence/library_repository.dart';
import 'package:distill_ed/domain/model/library_item.dart';
import 'package:distill_ed/editor/state/library_controller.dart';

/// A repository whose writes finish only when the test says so, so the order
/// in which writes start and finish can be controlled.
class _GatedRepository implements LibraryRepository {
  /// What each write was asked to store, in the order the writes started.
  final started = <List<LibraryItem>>[];
  final _gates = <Completer<void>>[];

  /// What a read returns: the last write that finished.
  List<LibraryItem> persisted = const [];

  @override
  Future<List<LibraryItem>> load() async => persisted;

  @override
  Future<void> saveAll(List<LibraryItem> items) {
    started.add(items);
    final gate = Completer<void>();
    _gates.add(gate);
    return gate.future.then((_) => persisted = items);
  }

  void finish(int index) => _gates[index].complete();
}

/// Lets queued work run.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('a later save does not start until the earlier one has finished',
      () async {
    final repo = _GatedRepository();
    final library = LibraryController(repo);

    final added = library.addFromElements('one', const [], id: '1');
    await settle();
    expect(repo.started, hasLength(1));

    final removed = library.remove('1');
    await settle();
    expect(repo.started, hasLength(1),
        reason: 'the removal must wait for the add to land first');

    repo.finish(0);
    await settle();
    expect(repo.started, hasLength(2));
    expect(repo.started[1], isEmpty, reason: 'the second write is the removal');

    repo.finish(1);
    await added;
    await removed;
    expect(repo.persisted, isEmpty);
    expect(library.state, isEmpty);
  });

  test('the last edit is what is on disk, however many came before it',
      () async {
    final repo = _GatedRepository();
    final library = LibraryController(repo);

    final writes = [
      library.addFromElements('a', const [], id: 'a'),
      library.addFromElements('b', const [], id: 'b'),
      library.rename('a', 'renamed'),
    ];
    for (var i = 0; i < 3; i++) {
      await settle();
      repo.finish(i);
    }
    await Future.wait(writes);

    expect(repo.persisted.map((i) => i.id), ['a', 'b']);
    expect(repo.persisted.map((i) => i.name), ['renamed', 'b'],
        reason: 'the rename was the last edit, so it is what was saved');
  });

  test('a load waits for pending saves, so it cannot bring back an older copy',
      () async {
    final repo = _GatedRepository();
    final library = LibraryController(repo);

    final added = library.addFromElements('one', const [], id: '1');
    await settle();

    final loaded = library.load();
    await settle();
    expect(library.state.map((i) => i.id), ['1'],
        reason: 'the file has not caught up yet, so the load must wait');

    repo.finish(0);
    await added;
    await loaded;
    expect(library.state.map((i) => i.id), ['1']);
  });
}
