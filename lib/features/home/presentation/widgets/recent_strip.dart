// "Recent": the notebooks opened last, as a row of chips above the grid.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/note_card_data.dart';

class RecentStrip extends StatelessWidget {
  const RecentStrip({
    super.key,
    required this.notes,
    required this.onOpen,
    this.padding = EdgeInsets.zero,
  });

  final List<NoteCardData> notes;
  final ValueChanged<NoteCardData> onOpen;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: padding.left, right: padding.right),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Recent',
              style: TextStyle(
                  fontFamily: 'ModulusPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              key: const ValueKey('recentStrip'),
              scrollDirection: Axis.horizontal,
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ActionChip(
                key: ValueKey('recent:${notes[i].id}'),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(notes[i].title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                onPressed: () => onOpen(notes[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
