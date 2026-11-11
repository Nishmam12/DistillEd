// Any colour, not just the palette's twelve: hue, saturation and brightness
// sliders and a hex field, kept in step, with a preview of the result.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reads `#RGB`, `#RRGGBB` (opaque) or `#AARRGGBB` into an ARGB int, with or
/// without the `#`. Null for anything else.
int? parseHexColor(String input) {
  var hex = input.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return null;
  switch (hex.length) {
    case 3:
      hex = 'FF${hex.split('').map((c) => '$c$c').join()}';
    case 6:
      hex = 'FF$hex';
    case 8:
      break;
    default:
      return null;
  }
  return int.parse(hex, radix: 16);
}

String _hexOf(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Lets the user build a colour, starting from [initial]. Null when cancelled.
Future<int?> showCustomColorDialog(BuildContext context, int initial) =>
    showDialog<int>(
      context: context,
      builder: (_) => _CustomColorDialog(initial: initial),
    );

class _CustomColorDialog extends StatefulWidget {
  final int initial;
  const _CustomColorDialog({required this.initial});

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.initial));
  late final TextEditingController _hex =
      TextEditingController(text: _hexOf(widget.initial));

  /// What the hex field says, when it says something valid; null otherwise.
  /// The sliders always produce a valid colour, so this is null only while
  /// the user is mid-way through typing a bad code.
  int? _typed;
  bool _hexValid = true;

  int get _value => _hexValid ? (_typed ?? _hsv.toColor().toARGB32()) : 0;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      _typed = null;
      _hexValid = true;
      _hex.text = _hexOf(hsv.toColor().toARGB32());
    });
  }

  void _onHex(String text) {
    final parsed = parseHexColor(text);
    setState(() {
      _hexValid = parsed != null;
      _typed = parsed;
      if (parsed != null) _hsv = HSVColor.fromColor(Color(parsed));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom colour'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _hexValid ? Color(_value) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(height: 12),
            _labelled(
              'Hue',
              Slider(
                key: const ValueKey('hueSlider'),
                value: _hsv.hue,
                max: 360,
                onChanged: (v) => _setHsv(_hsv.withHue(v)),
              ),
            ),
            _labelled(
              'Colour',
              Slider(
                value: _hsv.saturation,
                onChanged: (v) => _setHsv(_hsv.withSaturation(v)),
              ),
            ),
            _labelled(
              'Brightness',
              Slider(
                value: _hsv.value,
                onChanged: (v) => _setHsv(_hsv.withValue(v)),
              ),
            ),
            TextField(
              key: const ValueKey('hexField'),
              controller: _hex,
              onChanged: _onHex,
              inputFormatters: [LengthLimitingTextInputFormatter(9)],
              decoration: InputDecoration(
                labelText: 'Hex',
                errorText: _hexValid ? null : 'Use a code like #1971C2',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _hexValid ? () => Navigator.of(context).pop(_value) : null,
          child: const Text('Use'),
        ),
      ],
    );
  }

  Widget _labelled(String label, Widget slider) => Row(
        children: [
          SizedBox(width: 84, child: Text(label)),
          Expanded(child: slider),
        ],
      );
}
