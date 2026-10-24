// Lists saved library items; returns the chosen one to the caller (which
// performs the insert in its own provider scope).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/library_controller.dart';

class EditorLibrarySheet extends ConsumerWidget {
  const EditorLibrarySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No saved items yet.\nSelect elements, then "Save to library".',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final item in items)
                  ListTile(
                    leading: const Icon(Icons.dashboard_customize_outlined),
                    title: Text(item.name),
                    subtitle: Text('${item.elements.length} element(s)'),
                    onTap: () => Navigator.of(context).pop(item),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(context, ref, item.id),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(libraryProvider.notifier).remove(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text("Couldn't remove that item. Try again.")),
      );
    }
  }
}
