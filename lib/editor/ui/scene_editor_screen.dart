// Dev playground for the unified canvas. Reachable from Settings when Developer
// Mode is on. Uses an in-memory scene store so it is fully self-contained — no
// persistence, no Isar, no effect on real notebooks. All chrome is the shared
// [EditorBottomBar]/[EditorAppBarActions] used by the real notebook editor too.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/persistence/scene_element_store.dart';
import '../state/scene_controller.dart';
import '../state/viewport_controller.dart';
import 'controls/editor_app_bar_actions.dart';
import 'controls/editor_bottom_bar.dart';
import 'controls/editor_tool_options_overlay.dart';
import 'scene_canvas.dart';
import 'universal_color_palette.dart';

const ScenePageKey _demoKey = (notebookId: 0, pageId: 0);

class SceneEditorScreen extends StatelessWidget {
  const SceneEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
      ],
      child: const _SceneEditorBody(),
    );
  }
}

class _SceneEditorBody extends ConsumerWidget {
  const _SceneEditorBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(viewportProvider.select((v) => v.zoom));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canvas 2.0 (dev)'),
        actions: [
          Center(child: Text('${(zoom * 100).round()}%')),
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => ref.read(viewportProvider.notifier).reset(),
          ),
          const EditorAppBarActions(pageKey: _demoKey),
        ],
      ),
      body: const Stack(
        children: [
          Positioned.fill(child: SceneCanvas(notebookId: 0, pageId: 0)),
          // Toolbar sits below in bottomNavigationBar here, so its options
          // panel floats up from the bottom instead of down from the top.
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: EditorToolOptionsOverlay(anchorBottom: true),
            ),
          ),
          Positioned(top: 8, right: 8, child: UniversalColorPalette()),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: EditorBottomBar(pageKey: _demoKey),
      ),
    );
  }
}
