// Undo/redo stacks for one page's scene. Commands apply against the
// SceneController (a SceneMutator).

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/commands/scene_command.dart';
import 'scene_controller.dart';

class HistoryState {
  final int undoDepth;
  final int redoDepth;
  const HistoryState(this.undoDepth, this.redoDepth);

  bool get canUndo => undoDepth > 0;
  bool get canRedo => redoDepth > 0;
}

class HistoryController extends StateNotifier<HistoryState> {
  final SceneMutator _mutator;
  final List<SceneCommand> _undo = [];
  final List<SceneCommand> _redo = [];

  /// The oldest commands are forgotten past this many, so a long session does
  /// not hold every stroke it ever drew.
  static const int defaultMaxDepth = 200;

  final int _maxDepth;

  HistoryController(this._mutator, {int maxDepth = defaultMaxDepth})
      : _maxDepth = maxDepth,
        super(const HistoryState(0, 0));

  /// Applies [command] and records it for undo. A command that throws part way
  /// is rolled back as far as it can be and NOT recorded, so undo never offers
  /// to reverse something that did not fully happen.
  void push(SceneCommand command) {
    try {
      command.apply(_mutator);
    } catch (_) {
      try {
        command.revert(_mutator);
      } catch (_) {}
      rethrow;
    }
    _record(command);
  }

  /// Records a command whose effect has already been applied (e.g. a live drag
  /// transform that updated the scene during the gesture).
  void pushApplied(SceneCommand command) => _record(command);

  void _record(SceneCommand command) {
    _undo.add(command);
    if (_undo.length > _maxDepth) _undo.removeAt(0);
    _redo.clear();
    _sync();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final command = _undo.removeLast();
    command.revert(_mutator);
    _redo.add(command);
    _sync();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final command = _redo.removeLast();
    command.apply(_mutator);
    _undo.add(command);
    _sync();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _sync();
  }

  void _sync() => state = HistoryState(_undo.length, _redo.length);
}

final historyProvider = StateNotifierProvider.family<HistoryController,
    HistoryState, ScenePageKey>(
  (ref, key) =>
      HistoryController(ref.read(sceneControllerProvider(key).notifier)),
);
