// The name prompt for "Save to library". The dialog owns its text controller, so
// the controller is disposed with the dialog rather than leaked on every open.

import 'package:flutter/material.dart';

/// Asks for the name of a library item. Null when cancelled or left blank;
/// otherwise the name, trimmed.
Future<String?> showSaveToLibraryDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _SaveToLibraryDialog(),
    );

String? _cleanName(String value) => value.trim().isEmpty ? null : value.trim();

class _SaveToLibraryDialog extends StatefulWidget {
  const _SaveToLibraryDialog();

  @override
  State<_SaveToLibraryDialog> createState() => _SaveToLibraryDialogState();
}

class _SaveToLibraryDialogState extends State<_SaveToLibraryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save to library'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Item name'),
        onSubmitted: (v) => Navigator.of(context).pop(_cleanName(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_cleanName(_controller.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
