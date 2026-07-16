// Undo/redo command pattern for the unified scene.
//
// Commands act on a [SceneMutator] (implemented by SceneController) so the
// domain layer stays free of the editor/state layer. Each command knows how to
// apply and revert itself; the HistoryController owns the undo/redo stacks.

import '../model/scene_element.dart';

/// Minimal mutation surface a command needs. State changes are synchronous;
/// persistence may happen asynchronously behind these calls.
abstract class SceneMutator {
  void applyAdd(List<SceneElement> elements);
  void applyRemove(Set<String> ids);
  void applyUpdate(List<SceneElement> elements);
  void applyReplaceAll(List<SceneElement> elements);
}

abstract class SceneCommand {
  void apply(SceneMutator m);
  void revert(SceneMutator m);
}

/// Adds elements; undo removes them.
class AddElementsCommand implements SceneCommand {
  final List<SceneElement> added;
  const AddElementsCommand(this.added);

  @override
  void apply(SceneMutator m) => m.applyAdd(added);

  @override
  void revert(SceneMutator m) => m.applyRemove({for (final e in added) e.id});
}

/// Removes elements; undo re-adds them.
class RemoveElementsCommand implements SceneCommand {
  final List<SceneElement> removed;
  const RemoveElementsCommand(this.removed);

  @override
  void apply(SceneMutator m) => m.applyRemove({for (final e in removed) e.id});

  @override
  void revert(SceneMutator m) => m.applyAdd(removed);
}

/// Replaces a set of elements (matched by id); undo restores the [before] copies.
class UpdateElementsCommand implements SceneCommand {
  final List<SceneElement> before;
  final List<SceneElement> after;
  const UpdateElementsCommand({required this.before, required this.after});

  @override
  void apply(SceneMutator m) => m.applyUpdate(after);

  @override
  void revert(SceneMutator m) => m.applyUpdate(before);
}

/// One true pixel-erase gesture: removes the originals the cut crossed and
/// adds the surviving sub-strokes, as a single undo step.
class PixelEraseCommand implements SceneCommand {
  final List<SceneElement> removed;
  final List<SceneElement> added;
  const PixelEraseCommand({required this.removed, required this.added});

  @override
  void apply(SceneMutator m) {
    m.applyRemove({for (final e in removed) e.id});
    m.applyAdd(added);
  }

  @override
  void revert(SceneMutator m) {
    m.applyRemove({for (final e in added) e.id});
    m.applyAdd(removed);
  }
}

/// Replaces the whole element list (e.g. a z-order reindex). Stores full
/// before/after snapshots.
class ReplaceAllCommand implements SceneCommand {
  final List<SceneElement> before;
  final List<SceneElement> after;
  const ReplaceAllCommand({required this.before, required this.after});

  @override
  void apply(SceneMutator m) => m.applyReplaceAll(after);

  @override
  void revert(SceneMutator m) => m.applyReplaceAll(before);
}
