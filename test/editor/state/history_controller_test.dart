import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/data/persistence/scene_element_store.dart';
import 'package:distill_ed/domain/commands/scene_command.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/editor/state/history_controller.dart';
import 'package:distill_ed/editor/state/scene_controller.dart';

SceneController _controller() =>
    SceneController(InMemorySceneElementStore(), notebookId: 1, pageId: 1);

FreehandElement _el(String id, int z) =>
    FreehandElement(id: id, zOrder: z, color: 0, size: 1, points: const []);

class _Throwing implements SceneCommand {
  bool reverted = false;
  @override
  void apply(SceneMutator m) => throw StateError('half way');
  @override
  void revert(SceneMutator m) => reverted = true;
}

void main() {
  test('a command that throws is rolled back and not recorded', () {
    final h = HistoryController(_controller());
    final bad = _Throwing();

    expect(() => h.push(bad), throwsStateError);

    expect(bad.reverted, isTrue);
    expect(h.state.canUndo, isFalse);
  });

  test('history keeps only the most recent commands', () {
    final ctl = _controller();
    final h = HistoryController(ctl, maxDepth: 3);

    for (var i = 0; i < 10; i++) {
      h.push(AddElementsCommand([_el('e$i', i)]));
    }

    expect(h.state.undoDepth, 3);
    while (h.state.canUndo) {
      h.undo();
    }
    expect(ctl.state.map((e) => e.id).length, 7, reason: 'the first 7 stay');
  });

  test('add command: push applies, undo reverts, redo re-applies', () {
    final ctl = _controller();
    final h = HistoryController(ctl);

    h.push(AddElementsCommand([_el('a', 0)]));
    expect(ctl.state.map((e) => e.id), ['a']);
    expect(h.state.canUndo, true);

    h.undo();
    expect(ctl.state, isEmpty);
    expect(h.state.canRedo, true);

    h.redo();
    expect(ctl.state.map((e) => e.id), ['a']);
  });

  test('remove command round-trips through undo', () {
    final ctl = _controller()..setAll([_el('a', 0), _el('b', 1)]);
    final h = HistoryController(ctl);

    h.push(RemoveElementsCommand([ctl.state.first]));
    expect(ctl.state.map((e) => e.id), ['b']);
    h.undo();
    expect(ctl.state.map((e) => e.id).toSet(), {'a', 'b'});
  });

  test('update command restores the before snapshot on undo', () {
    const before = SceneShapeElement(
      id: 'r',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 10, 10],
      color: 0xFF000000,
      strokeWidth: 1,
    );
    final ctl = _controller()..setAll([before]);
    final h = HistoryController(ctl);

    final after = before.copyWith(geometryData: [5, 5, 15, 15]);
    h.push(UpdateElementsCommand(before: [before], after: [after]));
    expect((ctl.state.first as SceneShapeElement).geometryData, [5, 5, 15, 15]);

    h.undo();
    expect((ctl.state.first as SceneShapeElement).geometryData, [0, 0, 10, 10]);
  });

  test('a new push clears the redo stack', () {
    final ctl = _controller();
    final h = HistoryController(ctl);
    h.push(AddElementsCommand([_el('a', 0)]));
    h.undo();
    expect(h.state.canRedo, true);
    h.push(AddElementsCommand([_el('b', 0)]));
    expect(h.state.canRedo, false);
  });

  test('replace command swaps elements in ONE step, and undo brings them back',
      () {
    final ctl = _controller()..setAll([_el('stroke', 3), _el('other', 1)]);
    final h = HistoryController(ctl);
    const shape = SceneShapeElement(
      id: 'shape',
      zOrder: 3,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 10, 10],
      color: 0xFF000000,
      strokeWidth: 1,
    );

    h.push(ReplaceElementsCommand(
      removed: [ctl.state.firstWhere((e) => e.id == 'stroke')],
      added: [shape],
    ));
    expect(ctl.state.map((e) => e.id).toSet(), {'shape', 'other'});

    h.undo();
    expect(ctl.state.map((e) => e.id).toSet(), {'stroke', 'other'},
        reason: 'one undo restores the freehand stroke');

    h.redo();
    expect(ctl.state.map((e) => e.id).toSet(), {'shape', 'other'});
  });
}
