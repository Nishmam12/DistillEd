// Small helpers shared across the editor toolbar/panel widgets in this
// directory (kept separate so each widget file only imports what it needs).

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/model/scene_element.dart';
import '../../state/scene_controller.dart';
import '../../state/selection_controller.dart';

String editorNewId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 30)}';

List<SceneElement> editorSelection(WidgetRef ref, ScenePageKey key) {
  final ids = ref.read(selectionProvider);
  return ref
      .read(sceneControllerProvider(key))
      .where((e) => ids.contains(e.id))
      .toList();
}
