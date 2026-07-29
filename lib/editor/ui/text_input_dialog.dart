// The one text-entry dialog for scene text, shared by "add text" (the text
// tool) and "edit text" (the selection bar), so the two can never drift apart.

import 'package:flutter/material.dart';

import '../../domain/model/checklist_text.dart';
import '../../domain/model/scene_element.dart';

/// What the dialog returns: the words plus the formatting chosen alongside
/// them. Formatting is set here as well as in the selection bar so a user can
/// style text as they write it rather than only after committing it.
class SceneTextResult {
  final String text;
  final bool isBold;
  final bool isItalic;
  final TextAlignKind align;

  const SceneTextResult({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.align = TextAlignKind.left,
  });
}

/// Prompts for scene text, seeded with [initial] and the initial formatting.
///
/// Returns the entered text and formatting, or null when the user cancels —
/// which callers must treat as "leave the element alone". An empty *result* is
/// distinct from a cancel: it means the user deliberately cleared the field,
/// and the caller decides what that means (creation ignores it; editing
/// rejects it, since a text element with no text is invisible and
/// unselectable).
Future<SceneTextResult?> showSceneTextDialog(
  BuildContext context, {
  String initial = '',
  bool initialBold = false,
  bool initialItalic = false,
  TextAlignKind initialAlign = TextAlignKind.left,
  required String title,
  required String confirmLabel,
}) {
  return showDialog<SceneTextResult>(
    context: context,
    builder: (context) => _SceneTextDialog(
      initial: initial,
      initialBold: initialBold,
      initialItalic: initialItalic,
      initialAlign: initialAlign,
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

class _SceneTextDialog extends StatefulWidget {
  final String initial;
  final bool initialBold;
  final bool initialItalic;
  final TextAlignKind initialAlign;
  final String title;
  final String confirmLabel;

  const _SceneTextDialog({
    required this.initial,
    required this.initialBold,
    required this.initialItalic,
    required this.initialAlign,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<_SceneTextDialog> createState() => _SceneTextDialogState();
}

class _SceneTextDialogState extends State<_SceneTextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  late bool _bold = widget.initialBold;
  late bool _italic = widget.initialItalic;
  late TextAlignKind _align = widget.initialAlign;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            // Multi-line: the painter already wraps to the element's width, and
            // pasted or extracted text routinely runs past one line.
            maxLines: null,
            keyboardType: TextInputType.multiline,
            // Preview the choices as they are made, so the toggles are not
            // acting on something the user cannot see until they commit.
            style: TextStyle(
              fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: switch (_align) {
              TextAlignKind.left => TextAlign.left,
              TextAlignKind.center => TextAlign.center,
              TextAlignKind.right => TextAlign.right,
            },
            decoration: const InputDecoration(hintText: 'Type text…'),
          ),
          // A checklist is text with `[ ]` markers, so it is editable as raw
          // text above; these rows are the tick-friendly view of the same
          // string, kept in sync with the field.
          if (ChecklistText.isChecklist(_controller.text)) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Items', style: TextStyle(fontSize: 12)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in ChecklistText.items(_controller.text))
                      InkWell(
                        onTap: () => setState(() {
                          _controller.text = ChecklistText.toggleItem(
                              _controller.text, item.lineIndex);
                        }),
                        child: Row(
                          children: [
                            Checkbox(
                              value: item.done,
                              onChanged: (_) => setState(() {
                                _controller.text = ChecklistText.toggleItem(
                                    _controller.text, item.lineIndex);
                              }),
                            ),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  decoration: item.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Bold',
                isSelected: _bold,
                icon: const Icon(Icons.format_bold),
                onPressed: () => setState(() => _bold = !_bold),
              ),
              IconButton(
                tooltip: 'Italic',
                isSelected: _italic,
                icon: const Icon(Icons.format_italic),
                onPressed: () => setState(() => _italic = !_italic),
              ),
              const SizedBox(width: 8),
              for (final a in TextAlignKind.values)
                IconButton(
                  tooltip: switch (a) {
                    TextAlignKind.left => 'Align left',
                    TextAlignKind.center => 'Align center',
                    TextAlignKind.right => 'Align right',
                  },
                  isSelected: _align == a,
                  icon: Icon(switch (a) {
                    TextAlignKind.left => Icons.format_align_left,
                    TextAlignKind.center => Icons.format_align_center,
                    TextAlignKind.right => Icons.format_align_right,
                  }),
                  onPressed: () => setState(() => _align = a),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(SceneTextResult(
            text: _controller.text,
            isBold: _bold,
            isItalic: _italic,
            align: _align,
          )),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
