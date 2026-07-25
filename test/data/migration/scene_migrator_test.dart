import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/data/migration/legacy_page_data.dart';
import 'package:inkflow/data/migration/legacy_page_source.dart';
import 'package:inkflow/data/migration/migration_gate.dart';
import 'package:inkflow/data/migration/scene_migrator.dart';
import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/data/migration/legacy_models/shape_element.dart';
import 'package:inkflow/data/migration/legacy_models/stroke.dart';

class _FakeSource implements LegacyPageSource {
  final List<LegacyPageData> pages;
  int loadCount = 0;
  _FakeSource(this.pages);
  @override
  Future<List<LegacyPageData>> loadAllPages() async {
    loadCount++;
    return pages;
  }
}

class _ThrowingSource implements LegacyPageSource {
  @override
  Future<List<LegacyPageData>> loadAllPages() async =>
      throw StateError('source must not be read when already migrated');
}

ShapeElement _rect(String id, int zOrder) => ShapeElement()
  ..id = id
  ..type = ShapeType.rectangle
  ..color = 0xFF000000
  ..strokeWidth = 2
  ..hasFill = false
  ..fillColor = 0
  ..opacity = 1.0
  ..geometryData = [0, 0, 10, 10]
  ..rotation = 0
  ..text = ''
  ..fontSize = 16
  ..fontFamily = 'Roboto'
  ..isBold = false
  ..isItalic = false
  ..svgRelativePath = ''
  ..zOrder = zOrder
  ..seed = 0
  ..roughness = 0
  ..startBindingId = ''
  ..endBindingId = '';

LegacyPageData _samplePage() => LegacyPageData(
      notebookId: 1,
      pageId: 42,
      strokes: [
        const Stroke(id: '100', color: 0xFF000000, size: 2, points: []),
        const Stroke(id: '200', color: 0xFF000000, size: 2, points: []),
      ],
      shapes: [_rect('rect', 0)],
    );

void main() {
  group('SceneMigratorV2', () {
    test('migrates legacy pages and sets the schema version', () async {
      final source = _FakeSource([_samplePage()]);
      final store = InMemorySceneElementStore();
      final gate = InMemoryMigrationGate(0);

      final ran = await SceneMigratorV2(source: source, store: store, gate: gate)
          .run();

      expect(ran, isTrue);
      expect(await gate.currentVersion(), SceneMigratorV2.targetVersion);
      final elements = await store.loadForPage(42);
      expect(elements.length, 3); // 2 strokes + 1 shape
      // zOrder is contiguous and ordered
      expect(elements.map((e) => e.zOrder).toList(), [0, 1, 2]);
    });

    test('is idempotent: a second run is a no-op and adds no duplicates',
        () async {
      final source = _FakeSource([_samplePage()]);
      final store = InMemorySceneElementStore();
      final gate = InMemoryMigrationGate(0);
      final migrator =
          SceneMigratorV2(source: source, store: store, gate: gate);

      expect(await migrator.run(), isTrue);
      expect(await migrator.run(), isFalse); // gated
      expect((await store.loadForPage(42)).length, 3);
    });

    test('does not read the source when already at target version', () async {
      final migrator = SceneMigratorV2(
        source: _ThrowingSource(),
        store: InMemorySceneElementStore(),
        gate: InMemoryMigrationGate(SceneMigratorV2.targetVersion),
      );
      expect(await migrator.run(), isFalse); // returns without throwing
    });
  });

  group('InMemorySceneElementStore', () {
    test('upsert is keyed by element id (no duplicates on repeat)', () async {
      final store = InMemorySceneElementStore();
      const e = FreehandElement(
          id: 'f', zOrder: 0, points: [], color: 0xFF000000, size: 2);

      await store.upsertForPage(1, 1, [e]);
      await store.upsertForPage(1, 1, [e]);
      expect((await store.loadForPage(1)).length, 1);
    });

    test('loadForPage returns elements ordered by zOrder', () async {
      final store = InMemorySceneElementStore();
      await store.upsertForPage(1, 1, const [
        FreehandElement(id: 'b', zOrder: 2, points: [], color: 0, size: 1),
        FreehandElement(id: 'a', zOrder: 0, points: [], color: 0, size: 1),
        FreehandElement(id: 'c', zOrder: 1, points: [], color: 0, size: 1),
      ]);
      expect((await store.loadForPage(1)).map((e) => e.id).toList(),
          ['a', 'c', 'b']);
    });
  });
}
