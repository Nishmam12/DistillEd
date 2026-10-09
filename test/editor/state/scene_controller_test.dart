import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/scene_controller.dart';

FreehandElement _el(String id, int z) =>
    FreehandElement(id: id, zOrder: z, color: 0, size: 1, points: const []);

/// An in-memory store whose upserts finish late, to expose write reordering.
class _SlowUpsertStore extends InMemorySceneElementStore {
  @override
  Future<void> upsertForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await super.upsertForPage(notebookId, pageId, elements);
  }
}

void main() {
  test('a removal queued after a slow add is not undone by it', () async {
    final store = _SlowUpsertStore();
    final ctl = SceneController(store, notebookId: 1, pageId: 1);

    final add = ctl.addMany([_el('a', 0)]); // slow write in flight
    final remove = ctl.removeMany({'a'}); // must land AFTER the add
    await Future.wait([add, remove]);

    expect(await store.loadForPage(1), isEmpty);
    expect(ctl.state, isEmpty);
  });

  test('removeMany deletes only the given ids and keeps the rest', () async {
    final store = InMemorySceneElementStore();
    final ctl = SceneController(store, notebookId: 1, pageId: 1);
    await ctl.addMany([_el('a', 0), _el('b', 1), _el('c', 2)]);

    await ctl.removeMany({'a', 'c'});

    expect((await store.loadForPage(1)).map((e) => e.id), ['b']);
  });

  test('a failed write does not wedge later writes', () async {
    final store = _FailOnceStore();
    final ctl = SceneController(store, notebookId: 1, pageId: 1);

    await expectLater(ctl.addMany([_el('a', 0)]), throwsStateError);
    await ctl.addMany([_el('b', 1)]);

    expect((await store.loadForPage(1)).map((e) => e.id), ['b']);
  });
}

class _FailOnceStore extends InMemorySceneElementStore {
  bool _failed = false;

  @override
  Future<void> upsertForPage(
    int notebookId,
    int pageId,
    List<SceneElement> elements,
  ) {
    if (!_failed) {
      _failed = true;
      throw StateError('disk full');
    }
    return super.upsertForPage(notebookId, pageId, elements);
  }
}
