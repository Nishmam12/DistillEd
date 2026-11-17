// The notes list's sort, its extra filters (date, handwriting, recording) and
// saved searches, in the one sheet the sort button opens. Changes apply live.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../note_cards_provider.dart';
import '../saved_searches.dart';

Future<void> showSortFilterSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SortFilterSheet(),
    );

class _SortFilterSheet extends ConsumerWidget {
  const _SortFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sort = ref.watch(notesSortProvider);
    final more = ref.watch(notesMoreFiltersProvider);
    final saved = ref.watch(savedSearchesProvider);
    final setMore = ref.read(notesMoreFiltersProvider.notifier);
    TextStyle heading() => TextStyle(
        fontFamily: 'ModulusPro', fontSize: 13, color: c.textSecondary);
    TextStyle item() => TextStyle(
        fontFamily: 'ModulusPro',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: c.textPrimary);

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in NotesSort.values)
              ListTile(
                title: Text(s.label, style: item()),
                trailing: s == sort
                    ? Icon(Icons.check_rounded, color: c.accent)
                    : null,
                onTap: () => ref.read(notesSortProvider.notifier).state = s,
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Filter', style: heading()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final d in NotesDateFilter.values)
                    ChoiceChip(
                      label: Text(d.label),
                      selected: more.date == d,
                      onSelected: (_) =>
                          setMore.state = more.copyWith(date: d),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: Text('Has handwriting', style: item()),
              value: more.inkOnly,
              onChanged: (v) => setMore.state = more.copyWith(inkOnly: v),
            ),
            SwitchListTile(
              title: Text('Has a lecture recording', style: item()),
              value: more.recordingOnly,
              onChanged: (v) =>
                  setMore.state = more.copyWith(recordingOnly: v),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('Saved searches', style: heading()),
            ),
            for (final s in saved)
              ListTile(
                leading: const Icon(Icons.saved_search),
                title: Text(s.name, style: item()),
                onTap: () {
                  applySavedSearch(ref, s);
                  Navigator.of(context).pop();
                },
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      ref.read(savedSearchesProvider.notifier).delete(s.name),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text('Save this view…', style: item()),
              subtitle: const Text('Folder, tags, filters and sort'),
              onTap: () async {
                final name = await _askName(context);
                if (name == null) return;
                await ref
                    .read(savedSearchesProvider.notifier)
                    .saveCurrent(ref, name);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _askName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save search'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(context)
              .pop(v.trim().isEmpty ? null : v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final v = controller.text.trim();
                Navigator.of(context).pop(v.isEmpty ? null : v);
              },
              child: const Text('Save')),
        ],
      ),
    );
  }
}
