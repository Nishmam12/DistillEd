// The one text-entry dialog for scene text, shared by "add text" (the text
// tool) and "edit text" (the selection bar), so the two can never drift apart.

import 'package:flutter/material.dart';

/// Prompts for scene text, seeded with [initial].
///
/// Returns the entered string, or null when the user cancels — which callers
/// must treat as "leave the element alone". An empty *result* is distinct from
/// a cancel: it means the user deliberately cleared the field, and the caller
/// decides what that means (creation ignores it; editing rejects it, since a
/// text element with no text is invisible and unselectable).
Future<String?> showSceneTextDialog(
  BuildContext context, {
  String initial = '',
  required String title,
  required String confirmLabel,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        // Multi-line: the painter already wraps to the element's width, and
        // pasted or extracted text routinely runs past one line.
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(hintText: 'Type text…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
