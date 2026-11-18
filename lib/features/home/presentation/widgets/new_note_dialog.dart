// The "Template" dialog: title, page style and page colour for a new note.
//
// Sage glass over a blurred backdrop (margo design, 515×330, radius 30). The
// page-colour swatches and the paper previews are CONTENT, not chrome — they
// never re-theme (see PaperColors).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/paper_colors.dart';
import '../../../../domain/model/template_type.dart';

typedef NewNoteChoice = ({
  String title,
  int templateIndex,
  int backgroundColor,
});

/// Shows the dialog; resolves to null when cancelled.
Future<NewNoteChoice?> showNewNoteDialog(BuildContext context) {
  return showDialog<NewNoteChoice>(
    context: context,
    barrierColor: context.colors.bgPrimary.withValues(alpha: 0.25),
    builder: (_) => BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: const NewNoteDialog(),
    ),
  );
}

/// The page colours on offer: white, ivory, dark.
const newNotePaperColors = <Color>[
  PaperColors.paperWhite,
  PaperColors.paperIvory,
  PaperColors.paperDark,
];

class NewNoteDialog extends StatefulWidget {
  const NewNoteDialog({super.key});

  @override
  State<NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<NewNoteDialog> {
  final _controller = TextEditingController();
  int _template = 0;
  int _paper = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop((
      title: _controller.text.trim().isEmpty ? 'Untitled' : _controller.text,
      templateIndex: _template,
      backgroundColor: newNotePaperColors[_paper].toARGB32(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = TextStyle(
      fontFamily: 'ModulusPro',
      fontSize: 14,
      height: 1.17,
      fontWeight: FontWeight.w500,
      color: c.textPrimary,
    );

    // Design (515×330): sage glass at 50% over the blurred page, radius 30,
    // a small 0/4 blur-4 shadow. Content 19 in from the left, 20 from the
    // right; the buttons sit 27 in from the bottom-right corner.
    return Dialog(
      backgroundColor: c.surfaceSubtle.withValues(alpha: isDark ? 0.9 : 0.5),
      surfaceTintColor: Colors.transparent,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: isDark ? BorderSide(color: c.border) : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 515),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(19, 20, 20, 27),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Template', style: label.copyWith(fontSize: 18)),
              const SizedBox(height: 15),
              // Title pill: 32 tall, the design's lift under it.
              Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.textScalerOf(context).scale(32),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.fieldFill,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: isDark ? null : _lift,
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  cursorColor: c.textPrimary,
                  textAlignVertical: TextAlignVertical.center,
                  style: label.copyWith(fontWeight: FontWeight.w400),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    // Explicit: the theme's field padding would otherwise
                    // apply and blow the 32 pill up.
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Note title..',
                    // The design's white placeholder on the light field; the
                    // dark field takes cream ink at the same strength.
                    hintStyle: label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: (isDark ? c.textPrimary : Colors.white)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Page Style', style: label),
              const SizedBox(height: 12),
              // 51×69 pages inset 25 from each side of the field, five to a
              // row and spread across it; on the narrowest phones they shrink
              // (same shape) rather than overflow, and the rest wrap below.
              LayoutBuilder(
                builder: (context, constraints) {
                  const count = 5; // per row
                  const minGap = 6.0;
                  final side = math.min(25.0, constraints.maxWidth * 0.05);
                  final tileWidth = math.min(
                    _StyleTile.maxWidth,
                    (constraints.maxWidth - side * 2 - minGap * (count - 1)) /
                        count,
                  );
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: Column(
                      children: [
                        for (var from = 0;
                            from < _pickable.length;
                            from += count)
                          Padding(
                            padding: EdgeInsets.only(top: from == 0 ? 0 : 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                for (var i = from;
                                    i < from + count &&
                                        i < _pickable.length;
                                    i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        right: i == from + count - 1
                                            ? 0
                                            : (constraints.maxWidth -
                                                    side * 2 -
                                                    tileWidth * count) /
                                                (count - 1)),
                                    child: _StyleTile(
                                      type: _pickable[i],
                                      width: tileWidth,
                                      paper: newNotePaperColors[_paper],
                                      selected: i == _template,
                                      onTap: () =>
                                          setState(() => _template = i),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Page Color', style: label),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 19),
                child: Row(
                  children: [
                    for (var i = 0; i < newNotePaperColors.length; i++)
                      _Swatch(
                        color: newNotePaperColors[i],
                        selected: i == _paper,
                        onTap: () => setState(() => _paper = i),
                      ),
                  ],
                ),
              ),
              // A Wrap, not a Row: at the largest font sizes on a narrow phone the
              // two pills no longer fit side by side and drop onto two lines.
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 13,
                    runSpacing: 8,
                    children: [
                      _Pill(
                        label: 'Cancel',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _Pill(label: 'Create', onTap: _submit),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's small lift (black 25%, 0/4, blur 4) under the field and pages.
const _lift = [
  BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 4)),
];

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light: accent @50% with ink (the design). Dark: the muted accent wash
    // with an accent label.
    return Material(
      color: isDark ? c.accentMuted : c.accent.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ModulusPro',
              fontSize: 14,
              color: isDark ? c.accent : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              // Unselected: the design's mid-grey ring (#919191).
              color: selected
                  ? c.accent
                  : c.textPrimary.withValues(alpha: 0.45),
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.type,
    required this.width,
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final TemplateType type;
  final double width;
  final Color paper;
  final bool selected;
  final VoidCallback onTap;

  /// Design size: 51 × 69.
  static const maxWidth = 51.0;
  static const aspect = 69.0 / 51.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: type.displayName,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: width * aspect,
          // Square sheets on the design's lift; the chosen one gets an
          // accent ring (the mockup has no selected state to copy).
          decoration: BoxDecoration(
            color: paper,
            boxShadow: _lift,
            border: selected ? Border.all(color: c.accent, width: 2) : null,
          ),
          child: ClipRect(
            child: CustomPaint(painter: _PaperPainter(type, paper)),
          ),
        ),
      ),
    );
  }
}

/// A miniature of a page template, drawn in ink that suits the paper.
class _PaperPainter extends CustomPainter {
  _PaperPainter(this.type, this.paper);

  final TemplateType type;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = paper.computeLuminance() > 0.5
        ? PaperColors.penPalette.first
        : PaperColors.paperWhite;
    final line = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 9.0;

    switch (type.family) {
      case TemplateType.blank:
        break;
      case TemplateType.ruled:
        for (var y = step + 4; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
      case TemplateType.dotted:
        final dot = Paint()..color = ink.withValues(alpha: 0.5);
        for (var y = step; y < size.height; y += step) {
          for (var x = step; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 0.9, dot);
          }
        }
      case TemplateType.grid:
        for (var y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        for (var x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
      case TemplateType.cornell:
        final cue = size.width * 0.28;
        final summary = size.height * 0.82;
        for (var y = step; y < summary; y += step) {
          canvas.drawLine(Offset(cue, y), Offset(size.width, y), line);
        }
        canvas.drawLine(Offset(cue, 0), Offset(cue, summary), line);
        canvas.drawLine(Offset(0, summary), Offset(size.width, summary), line);
      case TemplateType.music:
        for (var top = 6.0; top + 8 < size.height; top += 22) {
          for (var i = 0; i < 5; i++) {
            final y = top + i * 2;
            canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
          }
        }
      case TemplateType.isometric:
        final dot = Paint()..color = ink.withValues(alpha: 0.5);
        var row = 0;
        for (var y = 6.0; y < size.height; y += 7.8) {
          for (var x = row.isOdd ? 8.5 : 4.0; x < size.width; x += 9) {
            canvas.drawCircle(Offset(x, y), 0.9, dot);
          }
          row++;
        }
      case TemplateType.checklist:
        for (var y = step + 4; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
          canvas.drawRect(Rect.fromLTWH(4, y - 7, 5, 5), line);
        }
      case TemplateType.engineeringGrid:
        const fine = 4.5;
        final faint = Paint()
          ..color = ink.withValues(alpha: 0.18)
          ..strokeWidth = 0.6;
        for (var y = fine; y < size.height; y += fine) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), faint);
        }
        for (var x = fine; x < size.width; x += fine) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), faint);
        }
        for (var y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        for (var x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
      case TemplateType.weeklyPlanner:
        // A band, then four rows of two day boxes.
        canvas.drawLine(const Offset(4, 10), Offset(size.width - 4, 10), line);
        final w = (size.width - 11) / 2, h = (size.height - 19) / 4;
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 2; c++) {
            canvas.drawRect(
                Rect.fromLTWH(4 + c * (w + 3), 13 + r * (h + 1), w, h - 1),
                line);
          }
        }
      case TemplateType.monthlyPlanner:
        // A band, then seven days by six weeks.
        canvas.drawLine(const Offset(4, 10), Offset(size.width - 4, 10), line);
        final grid = Rect.fromLTRB(4, 14, size.width - 4, size.height - 4);
        canvas.drawRect(grid, line);
        for (var c = 1; c < 7; c++) {
          final x = grid.left + grid.width * c / 7;
          canvas.drawLine(Offset(x, grid.top), Offset(x, grid.bottom), line);
        }
        for (var r = 1; r < 6; r++) {
          final y = grid.top + grid.height * r / 6;
          canvas.drawLine(Offset(grid.left, y), Offset(grid.right, y), line);
        }
      default:
        break; // spacings are drawn as their family
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.type != type || old.paper != paper;
}

/// One tile per pattern; the spacing is chosen later, in the editor's paper
/// sheet.
final _pickable = TemplateType.pickable;
