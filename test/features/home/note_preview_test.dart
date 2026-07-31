import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/home/presentation/models/note_card_data.dart';
import 'package:inkflow/features/home/presentation/widgets/note_preview.dart';
import 'package:inkflow/features/home/presentation/widgets/note_scene_preview.dart';

/// A 1×1 transparent PNG — enough for a real ImageProvider in a widget test.
final _pngPixel = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

NoteCardData _note({
  int id = 1,
  String title = 'Grocery',
  NoteType type = NoteType.text,
  String previewText = '',
  String? previewImage,
  List<SceneElement> previewScene = const [],
}) {
  return NoteCardData(
    id: id,
    title: title,
    createdAt: DateTime(2020, 5, 11),
    pages: 1,
    type: type,
    previewText: previewText,
    previewImage: previewImage,
    previewScene: previewScene,
  );
}

const _page = <SceneElement>[
  FreehandElement(
    id: 'a',
    zOrder: 0,
    color: 0xFF111111,
    size: 4,
    points: [
      StrokePoint(x: 0, y: 0, pressure: 0.5),
      StrokePoint(x: 60, y: 90, pressure: 0.5),
    ],
  ),
];

Future<void> _pump(
  WidgetTester tester,
  NoteCardData note, {
  double overlayInset = 0,
  ImageProvider? imageProvider,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 160,
            child: NotePreview(
              note: note,
              overlayInset: overlayInset,
              imageProvider: imageProvider,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('live page previews', () {
    testWidgets('paints the note\'s own first page', (tester) async {
      await _pump(
        tester,
        _note(title: 'IDs', type: NoteType.scene, previewScene: _page),
      );

      expect(find.byType(NoteScenePreview), findsOneWidget);
      expect(find.text('IDS'), findsNothing);
    });

    testWidgets('outranks a thumbnail for the same note', (tester) async {
      await _pump(
        tester,
        _note(
          type: NoteType.scene,
          previewScene: _page,
          previewImage: '/tmp/p.png',
        ),
        imageProvider: MemoryImage(_pngPixel),
      );

      expect(find.byType(NoteScenePreview), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('an empty page falls back without painting a scene',
        (tester) async {
      await _pump(tester, _note(title: 'Workout'));

      expect(find.byType(NoteScenePreview), findsNothing);
      // The title is NOT echoed into the preview area — it belongs to the
      // details column beside it. See _TypographicPreview's header.
      expect(find.text('WORKOUT'), findsNothing);
    });
  });

  group('image previews', () {
    testWidgets('renders the thumbnail instead of the typographic fallback',
        (tester) async {
      await _pump(
        tester,
        _note(title: 'IDs', type: NoteType.image, previewImage: '/tmp/p.png'),
        imageProvider: MemoryImage(_pngPixel),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('IDS'), findsNothing);
    });

    testWidgets('fills the preview area by cropping, anchored to the page top',
        (tester) async {
      await _pump(
        tester,
        _note(type: NoteType.image, previewImage: '/tmp/p.png'),
        imageProvider: MemoryImage(_pngPixel),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.topCenter);
      expect(tester.getSize(find.byType(Image)), const Size(360, 160));
    });

    testWidgets('a note with no thumbnail renders no Image', (tester) async {
      await _pump(tester, _note());

      expect(find.byType(Image), findsNothing);
    });
  });

  group('typographic previews', () {
    testWidgets('never echoes the note title into the preview area',
        (tester) async {
      // The details column to the left already carries the title; repeating it
      // here showed the same string twice at two different sizes.
      await _pump(tester, _note(title: 'Better Creator'));

      expect(find.text('BETTER CREATOR'), findsNothing);
      expect(find.text('Better Creator'), findsNothing);
    });

    testWidgets('lists checklist lines with bullet markers', (tester) async {
      await _pump(
        tester,
        _note(
          title: 'Grocery',
          type: NoteType.checklist,
          previewText: '- Eggs\n- Chicken\n- Rice',
        ),
      );

      expect(find.text('•  Eggs'), findsOneWidget);
      expect(find.text('•  Chicken'), findsOneWidget);
      expect(find.text('•  Rice'), findsOneWidget);
    });

    testWidgets('lists prose lines without markers', (tester) async {
      await _pump(
        tester,
        _note(previewText: 'Admitting fault is a hallmark of leadership'),
      );

      expect(
        find.text('Admitting fault is a hallmark of leadership'),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing at all when there is no recognised text',
        (tester) async {
      // An empty page should look empty — tinted ground and nothing else.
      await _pump(tester, _note(title: 'Workout'));

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('keeps its content clear of the overlay', (tester) async {
      const inset = 120.0;
      await _pump(
        tester,
        _note(title: 'Workout', previewText: 'Admitting fault'),
        overlayInset: inset,
      );

      final lineLeft = tester.getTopLeft(find.text('Admitting fault')).dx;
      final previewLeft = tester.getTopLeft(find.byType(NotePreview)).dx;
      expect(lineLeft - previewLeft, greaterThanOrEqualTo(inset));
    });
  });

  group('readability wash', () {
    testWidgets('fades white left-to-right across the preview', (tester) async {
      await _pump(tester, _note());

      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>()
          .toList();

      expect(gradients, hasLength(1));
      final gradient = gradients.single;
      expect(gradient.begin, Alignment.centerLeft);
      expect(gradient.end, Alignment.centerRight);
      expect(gradient.colors.first.a, 1.0);
      expect(gradient.colors.last.a, 0.0);
    });

    testWidgets('a tinted ground shows through where the wash has faded',
        (tester) async {
      await _pump(tester, _note(id: 2));

      final tint = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.color != null)
          .toList();

      expect(tint, isNotEmpty);
      expect(tint.first.color!.a, 1.0);
    });
  });
}
