import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/data/migration/legacy_models/ink_file_storage.dart';
import 'package:inkflow/data/migration/legacy_models/stroke.dart';
import 'package:inkflow/domain/model/stroke_point.dart';

void main() {
  group('InkFileStorage.saveStrokesSync', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('inkflow_ink_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    List<Stroke> readBack(String path) {
      final jsonString = File(path).readAsStringSync();
      final data = jsonDecode(jsonString) as List<dynamic>;
      return data
          .map((e) => Stroke.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    Stroke sample(String id) => Stroke(
          id: id,
          color: 0xFF112233,
          size: 5.0,
          opacity: 0.8,
          isEraser: false,
          points: const [
            StrokePoint(x: 1, y: 2, pressure: 0.4),
            StrokePoint(x: 3, y: 4, pressure: 0.6),
          ],
        );

    test('round-trips strokes through the .ink JSON format', () {
      InkFileStorage.saveStrokesSync(
        notebookDir: tempDir.path,
        pageId: 0,
        strokes: [sample('a'), sample('b')],
      );

      final file = '${tempDir.path}/page_0.ink';
      expect(File(file).existsSync(), isTrue);

      final loaded = readBack(file);
      expect(loaded.length, 2);
      expect(loaded[0].id, 'a');
      expect(loaded[0].color, 0xFF112233);
      expect(loaded[0].opacity, 0.8);
      expect(loaded[0].points.first.x, 1);
      expect(loaded[0].points.first.pressure, 0.4);
    });

    test('overwrite leaves no orphaned .bak/.tmp on the happy path', () {
      InkFileStorage.saveStrokesSync(
        notebookDir: tempDir.path,
        pageId: 1,
        strokes: [sample('first')],
      );
      // Second save creates a .bak, renames the .tmp over the final, then cleans up.
      InkFileStorage.saveStrokesSync(
        notebookDir: tempDir.path,
        pageId: 1,
        strokes: [sample('second'), sample('third')],
      );

      final base = '${tempDir.path}/page_1.ink';
      expect(File(base).existsSync(), isTrue);
      expect(File('$base.bak').existsSync(), isFalse, reason: 'backup removed after success');
      expect(File('$base.tmp').existsSync(), isFalse, reason: 'temp consumed by rename');

      final loaded = readBack(base);
      expect(loaded.map((s) => s.id), ['second', 'third']);
    });
  });
}
