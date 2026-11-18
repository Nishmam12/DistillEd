// "Today" on Home (Evernote's widgets, kept to one calm row): cards due, the
// study plan's tasks for today, and a scratch pad. Each card can be dismissed;
// Settings brings it back. The last-opened notebook is the Recent strip below.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../share/share_intake.dart' show SharedPayload;
import '../../domain/study_today.dart';
import '../home_notifier.dart';
import '../recent_notebooks.dart';
import '../study_today_providers.dart';

class TodayStrip extends ConsumerWidget {
  const TodayStrip({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(todayHiddenProvider);
    // A database that can't be read (or a test without one) shows no study
    // cards, never an error.
    final notebooks = ref.watch(studyNotebooksProvider).value ?? const [];
    final now = DateTime.now();

    final due = [
      for (final n in notebooks)
        if (dueBy(n.cardDue, now) case final d when d > 0) (n: n, due: d),
    ]..sort((a, b) => b.due.compareTo(a.due));
    final planned = [
      for (final n in notebooks)
        if (planTasksOn(n.plan, now) case final t when t.isNotEmpty)
          (n: n, tasks: t),
    ];

    final total = due.fold(0, (s, e) => s + e.due);
    final cards = <Widget>[
      if (total > 0 && !hidden.contains(TodayCard.cards))
        _Card(
          key: const ValueKey('todayCards'),
          kind: TodayCard.cards,
          icon: Icons.style_outlined,
          title: '$total ${total == 1 ? 'card' : 'cards'} due',
          lines: [for (final e in due.take(3)) '${e.n.title}  ${e.due}'],
          onTap: () => _open(context, ref, due.first.n.id, '/review'),
        ),
      if (planned.isNotEmpty && !hidden.contains(TodayCard.plan))
        _Card(
          key: const ValueKey('todayPlan'),
          kind: TodayCard.plan,
          icon: Icons.event_note_outlined,
          title: 'Today\'s plan',
          lines: [
            for (final p in planned.take(3)) '${p.n.title}: ${p.tasks.first}',
          ],
          onTap: () => _open(context, ref, planned.first.n.id, '/plan'),
        ),
      if (!hidden.contains(TodayCard.pad)) const _ScratchPad(),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    final c = context.colors;
    return Padding(
      padding:
          EdgeInsets.only(bottom: 12, left: padding.left, right: padding.right),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Today',
              style: TextStyle(
                  fontFamily: 'ModulusPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            key: const ValueKey('todayStrip'),
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final card in cards) ...[card, const SizedBox(width: 10)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _open(BuildContext context, WidgetRef ref, int id, String sub) {
    unawaited(ref.read(recentNotebooksProvider.notifier).record(id));
    final container = ProviderScope.containerOf(context, listen: false);
    unawaited(context
        .push('/note2/$id$sub')
        .then((_) => container.invalidate(studyNotebooksProvider)));
  }
}

class _Frame extends ConsumerWidget {
  const _Frame({
    super.key,
    required this.kind,
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  final TodayCard kind;
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return SizedBox(
      width: 260,
      child: Material(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: c.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'ModulusPro',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary)),
                    ),
                    IconButton(
                      tooltip: 'Hide from Today',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      icon: Icon(Icons.close, color: c.textSecondary),
                      onPressed: () => ref
                          .read(todayHiddenProvider.notifier)
                          .set(kind, hidden: true),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.kind,
    required this.icon,
    required this.title,
    required this.lines,
    required this.onTap,
  });

  final TodayCard kind;
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Frame(
        kind: kind,
        icon: icon,
        title: title,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Text(line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: context.colors.textSecondary)),
          ],
        ),
      );
}

/// A few lines jotted on Home; "Make a note" turns them into a note.
class _ScratchPad extends ConsumerStatefulWidget {
  const _ScratchPad();

  @override
  ConsumerState<_ScratchPad> createState() => _ScratchPadState();
}

class _ScratchPadState extends ConsumerState<_ScratchPad> {
  late final _controller = TextEditingController(
      text: ref.read(scratchPadProvider));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _makeNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Or the keyboard comes back with Home.
    FocusScope.of(context).unfocus();
    final firstLine = text.split('\n').first;
    final title = firstLine.length > 40
        ? '${firstLine.substring(0, 40)}…'
        : firstLine;
    final notebook =
        await ref.read(homeNotifierProvider.notifier).createNotebook(title);
    _controller.clear();
    await ref.read(scratchPadProvider.notifier).set('');
    if (!mounted) return;
    unawaited(ref.read(recentNotebooksProvider.notifier).record(notebook.id));
    // The editor places shared text as a typed text box: the same path.
    unawaited(context.push('/note2/${notebook.id}',
        extra: SharedPayload(text: text)));
  }

  @override
  Widget build(BuildContext context) {
    // The saved text arrives a moment after start.
    ref.listen(scratchPadProvider, (_, text) {
      if (_controller.text.isEmpty && text.isNotEmpty) _controller.text = text;
    });
    return _Frame(
      key: const ValueKey('todayPad'),
      kind: TodayCard.pad,
      icon: Icons.edit_note_outlined,
      title: 'Scratch pad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _controller,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Jot something down',
              border: InputBorder.none,
            ),
            onChanged: ref.read(scratchPadProvider.notifier).set,
          ),
          TextButton(
            onPressed: _makeNote,
            child: const Text('Make a note'),
          ),
        ],
      ),
    );
  }
}
