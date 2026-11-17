// The action chips at the start of the selection bar: a web address, email,
// phone number, street address or date in the selected handwriting or text,
// with the one thing to do with each. Read on the device; nothing at all when
// there is nothing to act on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../domain/model/element_link.dart';
import '../../../../domain/model/scene_element.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../../ai/data/ml_kit_action_finder.dart';
import '../../../ai/domain/study_planner/note_deadlines.dart';
import '../../../ai/presentation/ai_providers.dart';
import '../../../ai/presentation/study_planner/pinned_deadlines.dart';
import '../../domain/action_links.dart';

final actionFinderProvider = Provider<MlKitActionFinder>((ref) {
  final finder = MlKitActionFinder();
  ref.onDispose(finder.dispose);
  return finder;
});

/// The selection's words: typed text as it is, handwriting read line by line
/// when its model is already on the device (never downloaded for this).
Future<String> _selectionText(Ref ref, List<SceneElement> sel) async {
  final parts = <String>[
    for (final e in sel)
      if (e is TextElement && e.text.trim().isNotEmpty) e.text.trim(),
  ];
  final ink = [
    for (final e in sel)
      if (e is FreehandElement && !e.isEraser) e,
  ];
  if (ink.isNotEmpty) {
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final language = ref.read(settingsProvider).recognitionLanguage;
    try {
      if (await recognition.isModelDownloaded(language)) {
        for (final l in await recognition.recognizeInkLines(ink, language)) {
          if (l.text.trim().isNotEmpty) parts.add(l.text.trim());
        }
      }
    } catch (_) {}
  }
  return parts.join('\n');
}

/// The chips for the elements [ids] (sorted, comma-joined) on a page: read
/// once per selection, so moving or recolouring it reads nothing again.
final selectionActionsProvider = FutureProvider.autoDispose
    .family<({String text, List<ActionLink> links}), (ScenePageKey, String)>(
        (ref, arg) async {
  final (pageKey, joined) = arg;
  final ids = joined.split(',').toSet();
  final sel = [
    for (final e in ref.read(sceneControllerProvider(pageKey)))
      if (ids.contains(e.id)) e,
  ];
  final text = await _selectionText(ref, sel);
  if (text.isEmpty) return (text: '', links: const <ActionLink>[]);
  try {
    final now = DateTime.now();
    final found = await ref.read(actionFinderProvider).find(text, now: now);
    return (text: text, links: actionLinksFrom(found, now: now));
  } catch (_) {
    // No entity model yet (it downloads once, online): no chips.
    return (text: text, links: const <ActionLink>[]);
  }
});

class SelectionActionChips extends ConsumerWidget {
  const SelectionActionChips({
    super.key,
    required this.pageKey,
    required this.selectedIds,
    this.onOpenLink,
  });

  final ScenePageKey pageKey;
  final Set<String> selectedIds;

  /// Opens a web address the way element links are (asking first).
  final void Function(String link)? onOpenLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedIds.isEmpty) return const SizedBox.shrink();
    final key = (pageKey, (selectedIds.toList()..sort()).join(','));
    final found = ref.watch(selectionActionsProvider(key)).value;
    if (found == null || found.links.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final link in found.links)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              key: ValueKey('action:${link.kind.name}'),
              avatar: Icon(_icon(link.kind), size: 16),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(link.label, overflow: TextOverflow.ellipsis),
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () => _act(context, ref, link, found.text),
            ),
          ),
        const VerticalDivider(width: 12),
      ],
    );
  }

  static IconData _icon(ActionKind kind) => switch (kind) {
        ActionKind.web => Icons.language,
        ActionKind.email => Icons.mail_outline,
        ActionKind.phone => Icons.call_outlined,
        ActionKind.address => Icons.place_outlined,
        ActionKind.date => Icons.event_outlined,
      };

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    ActionLink link,
    String text,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (link.kind == ActionKind.date) {
      final line = text.split('\n').firstWhere(
            (l) => l.contains(link.text),
            orElse: () => text.split('\n').first,
          );
      await PinnedDeadlines.add(
        pageKey.notebookId,
        NoteDeadline(
          date: link.date!,
          label: line.length > kDeadlineLabelMax
              ? '${line.substring(0, kDeadlineLabelMax - 1)}…'
              : line,
          pageId: pageKey.pageId,
          pinned: true,
        ),
      );
      ref.invalidate(noteDeadlinesProvider(pageKey.notebookId));
      messenger.showSnackBar(const SnackBar(
          content: Text("Added to this notebook's study plan dates.")));
      return;
    }
    final uri = link.uri;
    if (uri == null) return;
    if (link.kind == ActionKind.web && onOpenLink != null) {
      onOpenLink!(LinkToWeb(uri.toString()).encoded);
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No app on this device can open that.')));
    }
  }
}
