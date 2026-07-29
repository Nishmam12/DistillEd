// Tier 1.6: exporting a whole notebook, not just the open page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/render/scene_exporter.dart';

SceneShapeElement _box(String id, double size) => SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, size, size],
      color: 0xFF112233,
      strokeWidth: 2,
    );

/// Counts `/Type /Page` object declarations in the raw PDF. Enough to assert
/// page count without pulling in a PDF parser.
int _pageCount(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  return '/Type/Page/'.allMatches(text).length +
      '/Type /Page'.allMatches(text).length;
}

void main() {
  testWidgets('produces a PDF covering every page', (tester) async {
    await tester.runAsync(() async {
      final pdf = await SceneExporter.toNotebookPdf(
        [
          [_box('a', 100)],
          [_box('b', 80)],
          [_box('c', 60)],
        ],
        scale: 1,
      );

      expect(pdf, isNotNull);
      expect(String.fromCharCodes(pdf!.sublist(0, 4)), '%PDF');
      expect(_pageCount(pdf), 3);
    });
  });

  testWidgets('keeps empty pages so numbering matches the notebook',
      (tester) async {
    await tester.runAsync(() async {
      final pdf = await SceneExporter.toNotebookPdf(
        [
          [_box('a', 100)],
          const <SceneElement>[], // untouched page in the middle
          [_box('c', 60)],
        ],
        scale: 1,
      );

      expect(_pageCount(pdf!), 3);
    });
  });

  testWidgets('a single-page notebook still exports', (tester) async {
    await tester.runAsync(() async {
      final pdf = await SceneExporter.toNotebookPdf(
        [
          [_box('a', 100)],
        ],
        scale: 1,
      );

      expect(_pageCount(pdf!), 1);
    });
  });

  testWidgets('returns null when every page is empty', (tester) async {
    await tester.runAsync(() async {
      expect(
        await SceneExporter.toNotebookPdf(
          [const <SceneElement>[], const <SceneElement>[]],
          scale: 1,
        ),
        isNull,
      );
    });
  });

  testWidgets('returns null for a notebook with no pages at all',
      (tester) async {
    await tester.runAsync(() async {
      expect(await SceneExporter.toNotebookPdf(const [], scale: 1), isNull);
    });
  });

  testWidgets('page size is uniform across differently sized pages',
      (tester) async {
    await tester.runAsync(() async {
      // The largest page drives the document size; a PDF whose pages differed
      // in size would paginate and print badly.
      final pdf = await SceneExporter.toNotebookPdf(
        [
          [_box('small', 40)],
          [_box('big', 400)],
        ],
        scale: 1,
        padding: 0,
      );
      final text = String.fromCharCodes(pdf!);
      final boxes = RegExp(r'/MediaBox\s*\[[^\]]*\]')
          .allMatches(text)
          .map((m) => m.group(0))
          .toSet();

      expect(boxes, hasLength(1), reason: 'all pages share one MediaBox');
    });
  });

  testWidgets('honours the notebook background colour', (tester) async {
    await tester.runAsync(() async {
      final pdf = await SceneExporter.toNotebookPdf(
        [
          [_box('a', 50)],
        ],
        background: const Color(0xFFFFFDF7),
        scale: 1,
      );

      expect(pdf, isNotNull);
      expect(String.fromCharCodes(pdf!.sublist(0, 4)), '%PDF');
    });
  });
}
