// "Customise toolbar": drag the editor's tools into order, switch each on or
// off, or put the bar back as it came. Saved as it changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:margo/core/icons/phosphor_icons_regular.dart';

import '../../../../editor/state/toolbar_layout.dart';
import '../../../../editor/ui/editor_constants.dart';

const Map<String, String> _names = {
  'select': 'Select',
  'pen': 'Pen',
  'shape': 'Shapes',
  'arrow': 'Arrow and line',
  'eraser': 'Eraser',
  'text': 'Text',
  'tape': 'Revision tape',
  'laser': 'Laser pointer',
};

IconData _iconOf(String id) => id == 'arrow'
    ? PhosphorIconsRegular.arrowRight
    : kEditorTools.firstWhere((e) => e.$1.name == id).$2;

Future<void> showToolbarCustomiser(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _Customiser(),
    );

class _Customiser extends ConsumerStatefulWidget {
  const _Customiser();

  @override
  ConsumerState<_Customiser> createState() => _CustomiserState();
}

class _CustomiserState extends ConsumerState<_Customiser> {
  /// Every tool, in order, and whether it is on the bar.
  late List<(String, bool)> _items = _fromLayout(ref.read(toolbarLayoutProvider));

  static List<(String, bool)> _fromLayout(ToolbarLayout layout) => [
        for (final id in layout.shown) (id, true),
        for (final id in layout.hidden) (id, false),
      ];

  void _save() => ref.read(toolbarLayoutProvider.notifier).set([
        for (final (id, on) in _items)
          if (on) id,
      ]);

  @override
  Widget build(BuildContext context) {
    final onCount = _items.where((i) => i.$2).length;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Customise toolbar',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  key: const ValueKey('toolbarReset'),
                  onPressed: () async {
                    await ref.read(toolbarLayoutProvider.notifier).reset();
                    setState(() => _items = _fromLayout(ToolbarLayout.standard));
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Drag to reorder. Switch a tool off to keep it off the bar.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Flexible(
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              onReorder: (from, to) {
                setState(() {
                  final item = _items.removeAt(from);
                  _items.insert(to > from ? to - 1 : to, item);
                });
                _save();
              },
              children: [
                for (final (i, (id, on)) in _items.indexed)
                  ListTile(
                    key: ValueKey('toolbarItem:$id'),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Row(
                      children: [
                        Icon(_iconOf(id), size: 20),
                        const SizedBox(width: 12),
                        Text(_names[id] ?? id),
                      ],
                    ),
                    trailing: Switch(
                      value: on,
                      // The last tool on the bar stays on it.
                      onChanged: on && onCount == 1
                          ? null
                          : (v) {
                              setState(() => _items[i] = (id, v));
                              _save();
                            },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
