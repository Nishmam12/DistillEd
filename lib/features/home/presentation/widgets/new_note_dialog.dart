// The "Template" dialog: title, page style and page colour for a new note.
//
// Sage glass over a blurred backdrop (margo design, 515×330, radius 30). The
// page-colour swatches and the paper previews are CONTENT, not chrome — they
// never re-theme (see PaperColors).

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
      title: _controller.text,
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
      fontWeight: FontWeight.w500,
      color: c.textPrimary,
    );

    return Dialog(
      backgroundColor: c.surfaceSubtle,
      surfaceTintColor: c.surfaceSubtle,
      elevation: isDark ? 0 : 6,
      shadowColor: c.brand.withValues(alpha: 0.3),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: isDark ? BorderSide(color: c.border) : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 515),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Template', style: label.copyWith(fontSize: 18)),
              const SizedBox(height: 14),
              // Title pill. The design's white placeholder on this green is
              // 2.1:1; ink at 60% clears 4.5:1.
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: c.fieldFill,
                  borderRadius: BorderRadius.circular(40),
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
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Note title..',
                    hintStyle: label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: c.textPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Page Style', style: label),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final type in TemplateType.values)
                    _StyleTile(
                      type: type,
                      paper: newNotePaperColors[_paper],
                      selected: type.index == _template,
                      onTap: () => setState(() => _template = type.index),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Page Color', style: label),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < newNotePaperColors.length; i++)
                    _Swatch(
                      color: newNotePaperColors[i],
                      selected: i == _paper,
                      onTap: () => setState(() => _paper = i),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Pill(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  _Pill(label: 'Create', onTap: _submit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
      padding: const EdgeInsets.only(right: 16, left: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? c.accent : c.border,
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
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final TemplateType type;
  final Color paper;
  final bool selected;
  final VoidCallback onTap;

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
          width: 56,
          height: 76,
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
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

    switch (type) {
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
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.type != type || old.paper != paper;
}
