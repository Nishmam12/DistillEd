// Typing straight onto the page: the text tool's field, placed and scaled with
// the view so what is typed looks like the text it becomes. Replaces the
// modal "Add text" / "Edit text" dialog (finding 11 of the first device test).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/model/checklist_text.dart';
import '../../domain/model/scene_element.dart';
import '../state/viewport_controller.dart';
import 'text_input_dialog.dart' show SceneTextResult;

/// Shown in an empty field.
const String kInlineTextHint = 'Type here';

/// Narrowest a new text box is, in scene units (as the dialog made them).
const double kInlineTextMinWidth = 120;

/// Widest a new text box grows to as it is typed, in scene units. Past this it
/// wraps, rather than running off the page.
const double kInlineTextMaxWidth = 640;

/// What is being written: a new text at [origin], or the existing [editing].
@immutable
class InlineTextSession {
  /// The text element being changed, or null for a new one.
  final TextElement? editing;

  /// Scene point of the text's top-left corner.
  final Offset origin;

  final String text;
  final double fontSize;
  final String fontFamily;
  final int color;
  final double opacity;
  final bool isBold;
  final bool isItalic;
  final TextAlignKind align;

  /// An existing text keeps its width; a new one grows as it is typed.
  final double? fixedWidth;

  const InlineTextSession({
    required this.origin,
    required this.fontSize,
    required this.fontFamily,
    required this.color,
    required this.opacity,
    this.editing,
    this.text = '',
    this.isBold = false,
    this.isItalic = false,
    this.align = TextAlignKind.left,
    this.fixedWidth,
  });

  factory InlineTextSession.edit(TextElement t, Rect bounds) =>
      InlineTextSession(
        editing: t,
        origin: bounds.topLeft,
        text: t.text,
        fontSize: t.fontSize,
        fontFamily: t.fontFamily,
        color: t.color,
        opacity: t.opacity,
        isBold: t.isBold,
        isItalic: t.isItalic,
        align: t.align,
        fixedWidth: bounds.width,
      );
}

TextStyle inlineTextStyle(InlineTextSession s,
        {required bool bold, required bool italic}) =>
    TextStyle(
      fontSize: s.fontSize,
      fontFamily: s.fontFamily,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: Color(s.color).withValues(alpha: s.opacity),
    );

/// Width, in scene units, a new text box needs for [text]: its longest line,
/// between [kInlineTextMinWidth] and [kInlineTextMaxWidth].
double inlineTextWidthFor(String text, TextStyle style) {
  var widest = 0.0;
  for (final line in text.split('\n')) {
    final p = TextPainter(
      text: TextSpan(text: line.isEmpty ? ' ' : line, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, p.width);
    p.dispose();
  }
  // A little slack for the caret, and so the painter (laid out at exactly this
  // width) does not wrap a line the field kept on one.
  return (widest + 4).clamp(kInlineTextMinWidth, kInlineTextMaxWidth);
}

TextAlign _textAlign(TextAlignKind a) => switch (a) {
      TextAlignKind.left => TextAlign.left,
      TextAlignKind.center => TextAlign.center,
      TextAlignKind.right => TextAlign.right,
    };

/// The field and its format strip, laid over the canvas in screen space.
///
/// Fills the canvas but only the field and strip take touches, so a touch
/// anywhere else reaches the page (which then commits the text). The field is
/// drawn at the page's zoom; the strip stays at a readable size.
class InlineTextEditor extends StatefulWidget {
  final InlineTextSession session;
  final ViewportState viewport;

  /// The text as typed (untrimmed) with its formatting, and the box width in
  /// scene units.
  final void Function(SceneTextResult result, double width) onCommit;

  /// Escape: throw the edit away.
  final VoidCallback onCancel;

  /// The field's rect on screen, reported after each layout, so the canvas can
  /// keep it above the keyboard.
  final ValueChanged<Rect>? onFieldRect;

  const InlineTextEditor({
    super.key,
    required this.session,
    required this.viewport,
    required this.onCommit,
    required this.onCancel,
    this.onFieldRect,
  });

  @override
  State<InlineTextEditor> createState() => InlineTextEditorState();
}

class InlineTextEditorState extends State<InlineTextEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.session.text);
  final FocusNode _focus = FocusNode(debugLabel: 'inlineText');
  final GlobalKey _fieldKey = GlobalKey();
  late bool _bold = widget.session.isBold;
  late bool _italic = widget.session.isItalic;
  late TextAlignKind _align = widget.session.align;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  TextStyle get _style =>
      inlineTextStyle(widget.session, bold: _bold, italic: _italic);

  // An empty field is as wide as its hint, so the hint does not wrap.
  double get _width =>
      widget.session.fixedWidth ??
      inlineTextWidthFor(
          _controller.text.isEmpty ? kInlineTextHint : _controller.text,
          _style);

  /// Hands the text to the canvas. Safe to call more than once: only the
  /// first counts.
  void commit() {
    if (_done) return;
    _done = true;
    widget.onCommit(
      SceneTextResult(
        text: _controller.text,
        isBold: _bold,
        isItalic: _italic,
        align: _align,
      ),
      _width,
    );
  }

  void _cancel() {
    if (_done) return;
    _done = true;
    widget.onCancel();
  }

  void _reportRect() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final parent = context.findRenderObject() as RenderBox?;
    if (parent == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: parent);
    final bottomRight = box.localToGlobal(
        box.size.bottomRight(Offset.zero), ancestor: parent);
    widget.onFieldRect?.call(Rect.fromPoints(topLeft, bottomRight));
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportRect());
    final vp = widget.viewport;
    final at = vp.toViewport(widget.session.origin);
    final zoom = vp.zoom;
    final width = _width;
    final lineHeight = widget.session.fontSize * 1.3 * zoom;
    // The strip sits above the text, or below it when there is no room above.
    const stripHeight = 48.0;
    final stripAbove = at.dy >= stripHeight + 8;

    return Stack(
      children: [
        Positioned(
          left: at.dx,
          top: at.dy,
          child: Transform.scale(
            scale: zoom,
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: _fieldKey,
              width: width,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): _cancel,
                },
                child: TextField(
                  key: const ValueKey('inlineTextField'),
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: _style,
                  textAlign: _textAlign(_align),
                  cursorColor: context.colors.accent,
                  decoration: InputDecoration.collapsed(
                    hintText: kInlineTextHint,
                    hintStyle: _style.copyWith(
                        color: context.colors.textSecondary
                            .withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: math.max(0.0, at.dx - 4),
          top: stripAbove
              ? at.dy - stripHeight - 4
              : at.dy + math.max(lineHeight, 24) + 8,
          child: _FormatStrip(
            bold: _bold,
            italic: _italic,
            align: _align,
            text: _controller.text,
            onBold: () => setState(() => _bold = !_bold),
            onItalic: () => setState(() => _italic = !_italic),
            onAlign: (a) => setState(() => _align = a),
            onToggleItem: (line) => _controller.text =
                ChecklistText.toggleItem(_controller.text, line),
            onDone: commit,
          ),
        ),
      ],
    );
  }
}

/// Bold, italic, alignment, ticking checklist items, and Done.
class _FormatStrip extends StatelessWidget {
  final bool bold;
  final bool italic;
  final TextAlignKind align;
  final String text;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final ValueChanged<TextAlignKind> onAlign;
  final ValueChanged<int> onToggleItem;
  final VoidCallback onDone;

  const _FormatStrip({
    required this.bold,
    required this.italic,
    required this.align,
    required this.text,
    required this.onBold,
    required this.onItalic,
    required this.onAlign,
    required this.onToggleItem,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isChecklist = ChecklistText.isChecklist(text);
    return Material(
      key: const ValueKey('inlineTextStrip'),
      elevation: 4,
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('inlineTextBold'),
              tooltip: 'Bold',
              visualDensity: VisualDensity.compact,
              isSelected: bold,
              icon: const Icon(Icons.format_bold),
              onPressed: onBold,
            ),
            IconButton(
              key: const ValueKey('inlineTextItalic'),
              tooltip: 'Italic',
              visualDensity: VisualDensity.compact,
              isSelected: italic,
              icon: const Icon(Icons.format_italic),
              onPressed: onItalic,
            ),
            for (final a in TextAlignKind.values)
              IconButton(
                key: ValueKey('inlineTextAlign_${a.name}'),
                tooltip: switch (a) {
                  TextAlignKind.left => 'Align left',
                  TextAlignKind.center => 'Align center',
                  TextAlignKind.right => 'Align right',
                },
                visualDensity: VisualDensity.compact,
                isSelected: align == a,
                icon: Icon(switch (a) {
                  TextAlignKind.left => Icons.format_align_left,
                  TextAlignKind.center => Icons.format_align_center,
                  TextAlignKind.right => Icons.format_align_right,
                }),
                onPressed: () => onAlign(a),
              ),
            // A checklist is text with `[ ]` markers: tick items here rather
            // than editing the markers by hand.
            if (isChecklist)
              PopupMenuButton<int>(
                key: const ValueKey('inlineTextChecklist'),
                tooltip: 'Tick items',
                icon: const Icon(Icons.checklist),
                onSelected: onToggleItem,
                itemBuilder: (_) => [
                  for (final item in ChecklistText.items(text))
                    CheckedPopupMenuItem<int>(
                      value: item.lineIndex,
                      checked: item.done,
                      child: Text(item.label),
                    ),
                ],
              ),
            const SizedBox(width: 4),
            TextButton(
              key: const ValueKey('inlineTextDone'),
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
