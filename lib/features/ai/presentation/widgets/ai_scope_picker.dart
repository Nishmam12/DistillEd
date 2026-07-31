// The one control for choosing what an AI request covers — this page, this
// imported PDF, or the whole notebook.
//
// Shared rather than re-implemented per feature so the three surfaces that
// offer a scope (Ask your notes, Summarize, Knowledge graph) name the same
// things the same way, and so the "Whole PDF" option appears under exactly one
// rule: the current page came from a multi-page import. On a hand-written page
// that option is hidden rather than shown-and-disabled — there is no PDF to
// name, and a greyed-out row invites a tap that can never do anything.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/ink_colors.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../domain/ai_scope.dart';
import '../ai_providers.dart';

/// The import a page belongs to, or null when the user made it by hand.
/// A family over the page key so switching pages re-resolves it.
final pageImportGroupProvider =
    FutureProvider.family<ScopePage?, ScenePageKey>((ref, key) {
  return ref.watch(aiScopeResolverProvider).importGroupOf(
        notebookId: key.notebookId,
        pageId: key.pageId,
      );
});

/// The scope kinds available on [key]'s page, in menu order.
///
/// [withSelection] adds the selection row for features that can act on one
/// (Summarize); Ask searches an index, which has no notion of a lasso, so it
/// never offers it.
List<AiScopeKind> scopeChoicesFor({
  required bool hasImportGroup,
  bool withSelection = false,
  bool hasSelection = false,
}) =>
    [
      if (withSelection && hasSelection) AiScopeKind.selection,
      AiScopeKind.page,
      if (hasImportGroup) AiScopeKind.importGroup,
      AiScopeKind.notebook,
    ];

/// Menu wording for a kind. [sourceName] fills in the PDF's file name when the
/// caller knows it — "Whole PDF (lecture.pdf)" tells a student which document
/// they're about to search when a notebook holds two.
String scopeChoiceLabel(AiScopeKind kind, {String? sourceName}) =>
    switch (kind) {
      AiScopeKind.selection => 'Selected items',
      AiScopeKind.page => 'This page',
      AiScopeKind.importGroup =>
        sourceName == null ? 'Whole PDF' : 'Whole PDF ($sourceName)',
      AiScopeKind.notebook => 'Whole notebook',
    };

/// A compact "reading: this page ▾" control.
///
/// Deliberately always visible, not tucked behind an overflow: which pages an
/// answer was allowed to read is the single fact that decides whether "I
/// couldn't find that in your notes" means "your notes don't say" or "you
/// scoped me to one page".
class AiScopePicker extends ConsumerWidget {
  final ScenePageKey pageKey;
  final AiScopeKind value;
  final ValueChanged<AiScopeKind> onChanged;

  /// Disabled while a request is in flight — changing scope mid-answer would
  /// label the running answer with pages it never read.
  final bool enabled;

  const AiScopePicker({
    super.key,
    required this.pageKey,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(pageImportGroupProvider(pageKey)).valueOrNull;
    final choices = scopeChoicesFor(hasImportGroup: group != null);
    final fg = enabled ? context.ink.textSecondary : context.ink.textMuted;

    return PopupMenuButton<AiScopeKind>(
      tooltip: 'What to search',
      position: PopupMenuPosition.under,
      enabled: enabled,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final kind in choices)
          PopupMenuItem(
            value: kind,
            child: Row(
              children: [
                Icon(
                  kind == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: context.ink.accent,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    scopeChoiceLabel(kind,
                        sourceName: group?.importSourceName),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_outlined, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              scopeChoiceLabel(value, sourceName: group?.importSourceName),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: fg),
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 16, color: fg),
        ],
      ),
    );
  }
}
