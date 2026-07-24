// The app-bar note title, editable in place. Tapping it turns the title into a
// text field; submitting (or tapping away) renames the note, while a blank or
// unchanged value quietly restores the current name. Lives on its own so the
// notebook editor's app bar stays readable and the rename behaviour is unit
// testable without standing up the whole screen.

import 'package:flutter/material.dart';

class EditableNoteTitle extends StatefulWidget {
  final String title;

  /// Called with the trimmed, non-empty, changed title when the user commits an
  /// edit. Null renders the title as plain, non-tappable text — used while the
  /// notebook is still loading and there is nothing to rename yet.
  final ValueChanged<String>? onRename;

  const EditableNoteTitle({
    super.key,
    required this.title,
    required this.onRename,
  });

  @override
  State<EditableNoteTitle> createState() => _EditableNoteTitleState();
}

class _EditableNoteTitleState extends State<EditableNoteTitle> {
  bool _editing = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant EditableNoteTitle old) {
    super.didUpdateWidget(old);
    // Adopt a title that changed elsewhere (e.g. the first load populating it)
    // only while we are not mid-edit, so it never overwrites what's being typed.
    if (!_editing && widget.title != old.title) {
      _controller.text = widget.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _controller
      ..text = widget.title
      ..selection =
          TextSelection(baseOffset: 0, extentOffset: widget.title.length);
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _commit() {
    // onSubmitted and onTapOutside can both fire for one edit; the first flips
    // this off so the rename callback runs at most once.
    if (!_editing) return;
    final next = _controller.text.trim();
    setState(() => _editing = false);
    if (next.isEmpty || next == widget.title) return;
    widget.onRename?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;

    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        style: style,
        cursorColor: theme.colorScheme.onSurface,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
        ),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _commit(),
      );
    }

    final tappable = widget.onRename != null;
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(widget.title,
              style: style, overflow: TextOverflow.ellipsis),
        ),
        if (tappable) ...[
          const SizedBox(width: 6),
          Icon(Icons.edit_outlined,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );

    if (!tappable) return title;
    return InkWell(
      onTap: _start,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: title,
      ),
    );
  }
}
