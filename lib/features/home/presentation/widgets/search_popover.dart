// The search icon and the frosted sage popover that opens in its place: a search
// field and the matching notes as title + page-count rows (margo "Search Bar").
//
// Results are matched locally against every note; the grid behind is left
// alone, as in the design.

import 'dart:math' as math;
import 'dart:ui' as ui;

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
  final _results = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _results.dispose();
    super.dispose();
  }

  static const _iconSize = 36.0;

  void _toggle() {
    if (_portal.isShowing) {
      _close();
    } else {
      setState(() => _query = '');
      _portal.show();
    }
  }

  void _close() => setState(_portal.hide);

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) {
        // The panel takes the search glyph's place: its top-right corner is
        // the glyph's (design: 250 wide, growing down and to the left). On a
        // narrow window it slides right just enough to keep a margin.
        final screen = MediaQuery.sizeOf(overlayContext);
        final box = context.findRenderObject() as RenderBox?;
        final inset = AppIconButton.insetFor(_iconSize);
        final glyph = box != null && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromLTWH(screen.width - 60, 40, 48, 48);
        const margin = 16.0;
        final width = math.min(
          NotesPalette.searchPopoverWidth,
          screen.width - margin * 2,
        );
        final top = glyph.top + inset;
        final right = math.min(
          screen.width - (glyph.right - inset),
          screen.width - margin - width,
        );
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
              right: math.max(margin, right),
              child: _Panel(
                width: width,
                maxHeight: math.max(160, screen.height - top - margin),
                query: _query,
                scrollController: _results,
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
      // Hidden (but holding its place) while the panel covers it.
      child: Visibility.maintain(
        visible: !_portal.isShowing,
        child: AppIconButton(
          AppIcons.search,
          size: _iconSize,
          tooltip: 'Search',
          onPressed: _toggle,
        ),
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.width,
    required this.maxHeight,
    required this.query,
    required this.scrollController,
    required this.onChanged,
    required this.onOpen,
  });

  final double width;
  final double maxHeight;
  final String query;
  final ScrollController scrollController;
  final ValueChanged<String> onChanged;
  final ValueChanged<NoteCardData> onOpen;

  /// Rows visible before the list scrolls (the design shows three and a bit).
  static const _visibleRows = 3.5;

  static const _radius = BorderRadius.all(Radius.circular(20));

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
    final rowHeight = _Row.heightFor(MediaQuery.textScalerOf(context));

    // Frosted sage glass (design: #C9D6C3 @ 40%, background blur). Dark
    // needs more body to read over dark cards, and a hairline for an edge.
    return ClipRRect(
      borderRadius: _radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: c.surfaceSubtle.withValues(alpha: isDark ? 0.75 : 0.4),
            borderRadius: _radius,
            border: isDark ? Border.all(color: c.border) : null,
          ),
          padding: const EdgeInsets.only(top: 7, bottom: 12),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 0, 13, 6),
                  child: SearchBarWidget(autofocus: true, onChanged: onChanged),
                ),
                const _Rule(),
                if (hits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 12, 13, 2),
                    child: Text(
                      cards.isEmpty ? 'No notes yet' : 'No notes match',
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: 15,
                        color: c.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: rowHeight * _visibleRows,
                      ),
                      // The design's 5px sage thumb, 7 in from the edge.
                      child: RawScrollbar(
                        controller: scrollController,
                        thumbVisibility: true,
                        thumbColor: c.surfaceSubtle,
                        thickness: 5,
                        radius: const Radius.circular(50),
                        crossAxisMargin: 7,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemExtent: rowHeight,
                          itemCount: hits.length,
                          itemBuilder: (context, i) => _Row(
                            note: hits[i],
                            onTap: () => onOpen(hits[i]),
                          ),
                        ),
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

/// The design's grey hairline (#A1A1A1 @ 80%) between rows, inset 13/19.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 19, 0),
      child: Container(
        height: 1,
        color: context.colors.textPrimary.withValues(alpha: 0.3),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.note, required this.onTap});

  final NoteCardData note;
  final VoidCallback onTap;

  /// 37 at normal text size (an 18px title plus 8 above and below, and the
  /// rule), growing with the system font.
  static double heightFor(TextScaler scaler) =>
      math.max(37, scaler.scale(18) * 1.2 + 15).ceilToDouble();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 19, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: 18,
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
                      color: c.textPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _Rule(),
        ],
      ),
    );
  }
}
