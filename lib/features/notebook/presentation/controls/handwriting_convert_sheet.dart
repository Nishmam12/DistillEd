import 'package:flutter/material.dart';

import '../../domain/handwriting_conversion.dart';

/// What the preview hands back: each line's text (as edited) and whether the
/// handwriting stays under the text.
typedef ConvertChoice = ({List<String> texts, bool keepInk});

/// Shows what the selected handwriting read as, one editable line at a time,
/// before it is turned into text. Lines ML Kit was unsure of are marked, so
/// they can be put right first. Pops a [ConvertChoice], or null when
/// cancelled.
Future<ConvertChoice?> showHandwritingConvertSheet(
        BuildContext context, List<ConversionLine> lines) =>
    showModalBottomSheet<ConvertChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HandwritingConvertSheet(lines: lines),
    );

class HandwritingConvertSheet extends StatefulWidget {
  final List<ConversionLine> lines;
  const HandwritingConvertSheet({super.key, required this.lines});

  @override
  State<HandwritingConvertSheet> createState() =>
      _HandwritingConvertSheetState();
}

class _HandwritingConvertSheetState extends State<HandwritingConvertSheet> {
  late final List<TextEditingController> _fields = [
    for (final l in widget.lines) TextEditingController(text: l.text),
  ];
  bool _keepInk = false;

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unsure = widget.lines.where((l) => l.unsure).length;
    final readable = widget.lines.where((l) => l.text.isNotEmpty).length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Convert to text',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            readable == 0
                ? 'None of this read as writing. Type it in below, or cancel.'
                : unsure == 0
                    ? 'Check the text, then convert.'
                    : '$unsure ${unsure == 1 ? 'line needs' : 'lines need'} '
                        'checking. Lines left empty stay as handwriting.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.lines.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final line = widget.lines[i];
                return TextField(
                  key: ValueKey('convertLine$i'),
                  controller: _fields[i],
                  maxLines: null,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: 'Not read: stays as handwriting',
                    prefixIcon: line.unsure
                        ? Tooltip(
                            message: 'Not sure of this line',
                            child: Icon(Icons.help_outline,
                                key: ValueKey('convertUnsure$i'),
                                color: scheme.tertiary),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('convertKeepInk'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep the handwriting'),
            subtitle: const Text('Leave the ink under the text.'),
            value: _keepInk,
            onChanged: (v) => setState(() => _keepInk = v),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('convertConfirm'),
                onPressed: () => Navigator.of(context).pop((
                  texts: [for (final f in _fields) f.text],
                  keepInk: _keepInk,
                )),
                child: const Text('Convert'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
