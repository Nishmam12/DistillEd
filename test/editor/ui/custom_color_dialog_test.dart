import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/editor/ui/custom_color_dialog.dart';

void main() {
  group('parseHexColor', () {
    test('reads #RRGGBB as opaque', () {
      expect(parseHexColor('#E03131'), 0xFFE03131);
      expect(parseHexColor('e03131'), 0xFFE03131);
      expect(parseHexColor('  #e03131 '), 0xFFE03131);
    });

    test('reads #AARRGGBB', () {
      expect(parseHexColor('#80E03131'), 0x80E03131);
    });

    test('reads the short #RGB form', () {
      expect(parseHexColor('#F0A'), 0xFFFF00AA);
    });

    test('rejects anything else', () {
      for (final bad in ['', '#', 'xyz', '#12345', '#GGGGGG', '#1234567']) {
        expect(parseHexColor(bad), isNull, reason: bad);
      }
    });
  });

  testWidgets('typing a hex code and pressing Use returns that colour',
      (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await showCustomColorDialog(context, 0xFF000000),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('hexField')), '#1971C2');
    await tester.pump();
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(picked, 0xFF1971C2);
  });

  testWidgets('a bad hex code cannot be used', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCustomColorDialog(context, 0xFF000000),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('hexField')), 'nope');
    await tester.pump();

    final use = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Use'));
    expect(use.onPressed, isNull);
  });

  testWidgets('moving the hue slider changes the colour', (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await showCustomColorDialog(context, 0xFFE03131),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const ValueKey('hueSlider')), const Offset(80, 0));
    await tester.pump();
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked, isNot(0xFFE03131));
  });
}
