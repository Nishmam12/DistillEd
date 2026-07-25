import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/home/domain/models/notebook.dart';
import 'package:inkflow/features/home/presentation/models/note_card_data.dart';
import 'package:inkflow/features/home/presentation/notes_palette.dart';

Notebook _notebook({
  int id = 1,
  String title = 'Workout',
  DateTime? createdAt,
  int pageCount = 2,
}) {
  return Notebook()
    ..id = id
    ..title = title
    ..createdAt = createdAt ?? DateTime(2020, 8, 14)
    ..modifiedAt = createdAt ?? DateTime(2020, 8, 14)
    ..pageCount = pageCount;
}

List<SceneElement> _page() => [
      const FreehandElement(
        id: 'a',
        zOrder: 0,
        color: 0xFF111111,
        size: 4,
        points: [
          StrokePoint(x: 0, y: 0, pressure: 0.5),
          StrokePoint(x: 40, y: 40, pressure: 0.5),
        ],
      ),
    ];

void main() {
  group('NoteCardData.fromNotebook', () {
    test('carries notebook metadata onto the card', () {
      final card = NoteCardData.fromNotebook(
        _notebook(id: 7, title: 'Grocery', pageCount: 1),
      );

      expect(card.id, 7);
      expect(card.title, 'Grocery');
      expect(card.pages, 1);
      expect(card.pinned, isFalse);
    });

    test('is an image note when a thumbnail was resolved', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewImage: '/tmp/notes/1/thumbnails/page_0.png',
      );

      expect(card.type, NoteType.image);
      expect(card.previewImage, isNotNull);
    });

    test('is a text note when there is prose but no thumbnail', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewText: 'It is perfectly okay to write garbage.',
      );

      expect(card.type, NoteType.text);
    });

    test('is a checklist when most lines carry a marker', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewText: '- Eggs\n- Chicken\n- Rice\n- Almond Milk',
      );

      expect(card.type, NoteType.checklist);
    });

    test('a lone dash inside a paragraph is not a checklist', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewText: 'Admitting fault is a hallmark\n- of true leadership\nso '
            'own the mistake early',
      );

      expect(card.type, NoteType.text);
    });

    test('is a scene note when the first page has content', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewScene: _page(),
      );

      expect(card.type, NoteType.scene);
      expect(card.previewScene, hasLength(1));
    });

    test('the live page outranks a thumbnail and text', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewScene: _page(),
        previewImage: '/tmp/page_0.png',
        previewText: '- Eggs\n- Chicken',
      );

      expect(card.type, NoteType.scene);
    });

    test('an empty first page falls through to the next best preview', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewScene: const [],
        previewImage: '/tmp/page_0.png',
      );

      expect(card.type, NoteType.image);
    });

    test('a thumbnail wins over recognised text', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewImage: '/tmp/page_0.png',
        previewText: '- Eggs\n- Chicken',
      );

      expect(card.type, NoteType.image);
    });

    test('trims whitespace-only preview text to empty', () {
      final card = NoteCardData.fromNotebook(_notebook(), previewText: '   \n ');

      expect(card.previewText, isEmpty);
      expect(card.type, NoteType.text);
    });
  });

  group('labels', () {
    test('formats the creation date as M/D/YY', () {
      final card = NoteCardData.fromNotebook(
        _notebook(createdAt: DateTime(2021, 7, 26)),
      );

      expect(card.dateLabel, '7/26/21');
    });

    test('pads a single-digit year', () {
      final card = NoteCardData.fromNotebook(
        _notebook(createdAt: DateTime(2005, 1, 2)),
      );

      expect(card.dateLabel, '1/2/05');
    });

    test('singularises a one-page note', () {
      expect(NoteCardData.fromNotebook(_notebook(pageCount: 1)).pageLabel,
          '1 page');
      expect(NoteCardData.fromNotebook(_notebook(pageCount: 5)).pageLabel,
          '5 pages');
    });
  });

  group('previewLines', () {
    test('strips bullet, checkbox and numeric markers', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewText: '- Eggs\n• Chicken\n[ ] Rice\n1. Almond Milk',
      );

      expect(card.previewLines(), ['Eggs', 'Chicken', 'Rice', 'Almond Milk']);
    });

    test('drops blank lines and caps the count', () {
      final card = NoteCardData.fromNotebook(
        _notebook(),
        previewText: 'one\n\ntwo\n   \nthree\nfour\nfive',
      );

      expect(card.previewLines(max: 3), ['one', 'two', 'three']);
    });

    test('is empty when there is no text', () {
      expect(NoteCardData.fromNotebook(_notebook()).previewLines(), isEmpty);
    });
  });

  group('matches', () {
    final card = NoteCardData.fromNotebook(
      _notebook(title: 'Better Creator'),
      previewText: 'edit brilliantly',
    );

    test('an empty query keeps everything', () {
      expect(card.matches(''), isTrue);
      expect(card.matches('   '), isTrue);
    });

    test('matches the title case-insensitively', () {
      expect(card.matches('better'), isTrue);
      expect(card.matches('CREATOR'), isTrue);
    });

    test('matches the preview text', () {
      expect(card.matches('brilliant'), isTrue);
    });

    test('rejects a miss', () {
      expect(card.matches('grocery'), isFalse);
    });
  });

  group('NotesPalette', () {
    test('exposes the spec colours', () {
      expect(NotesPalette.background.toARGB32(), 0xFFF7F8FA);
      expect(NotesPalette.card.toARGB32(), 0xFFFFFFFF);
      expect(NotesPalette.textPrimary.toARGB32(), 0xFF111111);
      expect(NotesPalette.textSecondary.toARGB32(), 0xFF7A7A7A);
      expect(NotesPalette.accent.toARGB32(), 0xFF192841);
    });

    test('keeps the card height inside the 150–170 band', () {
      expect(NotesPalette.cardHeight,
          inInclusiveRange(NotesPalette.cardHeightMin, NotesPalette.cardHeightMax));
    });

    test('keeps the overlay inside the 30–35% band', () {
      expect(NotesPalette.overlayWidthFactor, inInclusiveRange(0.30, 0.35));
    });

    test('gives a note a stable tint', () {
      expect(NotesPalette.tintFor(3), NotesPalette.tintFor(3));
      expect(NotesPalette.tintFor(-3), NotesPalette.tintFor(3));
      expect(
        NotesPalette.tintFor(NotesPalette.previewTints.length),
        NotesPalette.previewTints.first,
      );
    });
  });
}
