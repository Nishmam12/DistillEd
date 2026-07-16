import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/features/home/domain/models/note_page.dart';
import 'package:inkflow/features/summarize/data/scene_notebook_ink_loader.dart';

NotePage _page(int id, int index) => NotePage()
  ..id = id
  ..notebookId = 1
  ..pageIndex = index
  ..createdAt = DateTime(2026)
  ..modifiedAt = DateTime(2026);

const _ink = FreehandElement(
  id: 'ink1',
  zOrder: 0,
  color: 0xFF000000,
  size: 2,
  opacity: 0.9,
  points: [
    StrokePoint(x: 1, y: 2, pressure: 0.6, t: 100),
    StrokePoint(x: 3, y: 4, pressure: 0.7, t: 116),
  ],
);

void main() {
  group('SceneNotebookInkLoader', () {
    late InMemorySceneElementStore store;
    late SceneNotebookInkLoader loader;
    late List<NotePage> pages;

    setUp(() {
      store = InMemorySceneElementStore();
      pages = [];
      loader = SceneNotebookInkLoader(
        store: store,
        pagesOf: (_) async => pages,
      );
    });

    test('adapts freehand elements to strokes, preserving points and t', () async {
      pages = [_page(11, 0)];
      await store.upsertForPage(1, 11, [_ink]);

      final result = await loader.loadPagesStrokes(1);

      expect(result, hasLength(1));
      final stroke = result.single.single;
      expect(stroke.id, 'ink1');
      expect(stroke.color, 0xFF000000);
      expect(stroke.size, 2);
      expect(stroke.opacity, 0.9);
      expect(stroke.isEraser, false);
      expect(stroke.points, hasLength(2));
      expect(stroke.points[0].t, 100); // timestamps flow through untouched
      expect(stroke.points[1].pressure, 0.7);
    });

    test('skips non-ink elements and keeps eraser flag on ink', () async {
      pages = [_page(11, 0)];
      await store.upsertForPage(1, 11, [
        _ink.copyWith(id: 'e1', isEraser: true),
        const TextElement(
          id: 't1',
          zOrder: 1,
          geometryData: [0, 0, 10, 10],
          text: 'typed',
          color: 0xFF000000,
        ),
        const SceneShapeElement(
          id: 's1',
          zOrder: 2,
          shapeType: ShapeType.rectangle,
          geometryData: [0, 0, 5, 5],
          color: 0xFF000000,
          strokeWidth: 1,
        ),
      ]);

      final result = await loader.loadPagesStrokes(1);

      // Only the freehand element becomes a stroke (the recognition service
      // itself filters erasers — the loader just adapts faithfully).
      expect(result.single, hasLength(1));
      expect(result.single.single.id, 'e1');
      expect(result.single.single.isEraser, true);
    });

    test('returns one (possibly empty) list per page, in page order', () async {
      pages = [_page(21, 0), _page(22, 1), _page(23, 2)];
      await store.upsertForPage(1, 23, [_ink.copyWith(id: 'late')]);
      await store.upsertForPage(1, 21, [_ink.copyWith(id: 'early')]);
      // page 22 stays empty

      final result = await loader.loadPagesStrokes(1);

      expect(result, hasLength(3));
      expect(result[0].single.id, 'early');
      expect(result[1], isEmpty);
      expect(result[2].single.id, 'late');
    });

    test('empty notebook produces an empty list', () async {
      expect(await loader.loadPagesStrokes(1), isEmpty);
    });
  });
}
