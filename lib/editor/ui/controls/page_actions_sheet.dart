// The long-press page menu: duplicate / move / delete for a single page.
//
// Shared by the editor's page nav bar and the book view's filmstrip so both
// surfaces offer the same actions with the same guards, and both drive the
// existing [PageNotifier] rather than talking to the repository directly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/page_notifier.dart';

/// Actions the sheet can return. `null` means the user dismissed it.
enum PageAction { duplicate, moveLeft, moveRight, delete }

/// The menu body. Split out from [showPageActionsSheet] so the option guards
/// can be widget-tested without a live notebook behind them; it only pops a
/// [PageAction] and never touches persistence itself.
class PageActionsSheet extends StatelessWidget {
  final int pageIndex;
  final int pageCount;

  const PageActionsSheet({
    super.key,
    required this.pageIndex,
    required this.pageCount,
  });

  bool get _canMoveLeft => pageIndex > 0;
  bool get _canMoveRight => pageIndex < pageCount - 1;

  /// A notebook must always keep at least one page.
  bool get _canDelete => pageCount > 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Page ${pageIndex + 1} of $pageCount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Duplicate'),
            onTap: () => Navigator.pop(context, PageAction.duplicate),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Move left'),
            enabled: _canMoveLeft,
            onTap: _canMoveLeft
                ? () => Navigator.pop(context, PageAction.moveLeft)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.arrow_forward),
            title: const Text('Move right'),
            enabled: _canMoveRight,
            onTap: _canMoveRight
                ? () => Navigator.pop(context, PageAction.moveRight)
                : null,
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: _canDelete ? Theme.of(context).colorScheme.error : null,
            ),
            title: const Text('Delete'),
            subtitle: _canDelete
                ? null
                : const Text('A notebook needs at least one page'),
            enabled: _canDelete,
            onTap: _canDelete
                ? () => Navigator.pop(context, PageAction.delete)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Shows the page menu for [pageIndex] and performs the chosen action.
///
/// Deleting is confirmed first and is blocked when only one page remains — a
/// notebook must always have at least one page (the repository throws
/// otherwise, and [PageNotifier.deletePage] returns early).
Future<void> showPageActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required int notebookId,
  required int pageIndex,
  required int pageCount,
}) async {
  final action = await showModalBottomSheet<PageAction>(
    context: context,
    builder: (_) => PageActionsSheet(
      pageIndex: pageIndex,
      pageCount: pageCount,
    ),
  );

  if (action == null || !context.mounted) return;

  final notifier = ref.read(pageProvider(notebookId).notifier);
  switch (action) {
    case PageAction.duplicate:
      await notifier.duplicatePage(pageIndex);
    case PageAction.moveLeft:
      await notifier.reorderPages(pageIndex, pageIndex - 1);
    case PageAction.moveRight:
      await notifier.reorderPages(pageIndex, pageIndex + 1);
    case PageAction.delete:
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Delete page ${pageIndex + 1}?'),
          content: const Text(
              'Everything drawn on this page will be removed. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await notifier.deletePage(pageIndex);
      }
  }
}
