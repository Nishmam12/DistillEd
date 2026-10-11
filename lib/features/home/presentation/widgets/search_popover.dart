// The search icon and the sage popover that opens under it: a search field and
// the matching notes as title + page-count rows (margo design, "Search Bar").
//
// Results are matched locally against every note; the grid behind is left
// alone, as in the design.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/icons/app_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/note_card_data.dart';
import '../note_cards_provider.dart';
import '../notes_palette.dart';
import 'search_bar_widget.dart';

class SearchPopoverButton extends ConsumerStatefulWidget {
  const SearchPopoverButton({super.key, required this.onOpenNote});

  final ValueChanged<NoteCardData> onOpenNote;

  @override
  ConsumerState<SearchPopoverButton> createState() =>
      _SearchPopoverButtonState();
}

class _SearchPopoverButtonState extends ConsumerState<SearchPopoverButton> {
  final _portal = OverlayPortalController();
  String _query = '';

  void _toggle() {
    if (_portal.isShowing) {
      _close();
    } else {
      setState(() => _query = '');
      _portal.show();
    }
  }

  void _close() => _portal.hide();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) {
        // Hang the panel just under the search icon, but pin it to the
        // window's right edge with a margin and size it to the window: anchored
        // to the icon alone it would run off the left of a narrow screen, since
        // the icon is not at the edge.
        final screen = MediaQuery.sizeOf(overlayContext);
        final box = context.findRenderObject() as RenderBox?;
        final iconBottom = box != null && box.hasSize
            ? box.localToGlobal(Offset(0, box.size.height)).dy
            : 72.0;
        final top = iconBottom + 6;
        const margin = 16.0;
        return Stack(
          children: [
            // Tap anywhere else to dismiss.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: top,
              right: margin,
              child: _Panel(
                width: math.min(
                  NotesPalette.searchPopoverWidth,
                  screen.width - margin * 2,
                ),
                maxHeight: math.max(160, screen.height - top - margin),
                query: _query,
                onChanged: (v) => setState(() => _query = v),
                onOpen: (note) {
                  _close();
                  widget.onOpenNote(note);
                },
              ),
            ),
          ],
        );
      },
      child: IconButton(
        tooltip: 'Search',
        onPressed: _toggle,
        icon: const AppIcon(AppIcons.search, size: 30),
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.width,
    required this.maxHeight,
    required this.query,
    required this.onChanged,
    required this.onOpen,
  });

  final double width;
  final double maxHeight;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<NoteCardData> onOpen;

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cards = ref.watch(noteCardsProvider).value ?? const <NoteCardData>[];
    final hits = query.trim().isEmpty
        ? cards
        : [
            for (final card in cards)
              if (card.matches(query)) card,
          ];
    final shown = hits.take(_maxRows).toList();

    return Material(
      color: c.surfaceSubtle,
      elevation: isDark ? 0 : 6,
      shadowColor: c.brand.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark ? BorderSide(color: c.border) : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchBarWidget(autofocus: true, onChanged: onChanged),
                const SizedBox(height: 6),
                // Rows scroll if the window is too short to show them all
                // (landscape phones, large text).
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              cards.isEmpty ? 'No notes yet' : 'No notes match',
                              style: TextStyle(
                                fontFamily: 'ModulusPro',
                                fontSize: 15,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        for (var i = 0; i < shown.length; i++)
                          _Row(
                            note: shown[i],
                            divider: i < shown.length - 1,
                            onTap: () => onOpen(shown[i]),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.note, required this.divider, required this.onTap});

  final NoteCardData note;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: c.border)) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ModulusPro',
                  fontSize: 17,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              note.pageCountLabel,
              style: TextStyle(
                fontFamily: 'ModulusPro',
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
