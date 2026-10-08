// Hold-to-snap and scribble-to-erase, end to end through the real input pipeline:
// a stylus stroke with explicit timestamps, a fake classifier standing in for ML
// Kit, and the real SceneController and history. The decisions themselves are
// tested in test/editor/tools/ink_gestures_test.dart; this is the glue — that a
// recognised gesture lands as ONE undoable step, that nothing happens unless the
// setting is on, and that a stroke undone while the model was thinking is not
// resurrected.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkflow/core/providers/settings_provider.dart';
import 'package:inkflow/data/persistence/scene_element_store.dart';
import 'package:inkflow/domain/commands/scene_command.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/history_controller.dart';
import 'package:inkflow/editor/state/ink_gesture_providers.dart';
import 'package:inkflow/editor/state/scene_controller.dart';
import 'package:inkflow/editor/state/viewport_controller.dart';
import 'package:inkflow/editor/tools/ink_gestures.dart';
import 'package:inkflow/editor/ui/scene_canvas.dart';

const ScenePageKey _key = (notebookId: 0, pageId: 0);

/// Answers each model with a fixed label, optionally after a delay the test
/// controls, and records what it was asked.
class _FakeClassifier implements InkClassifier {
  _FakeClassifier(this.byModel);

  final Map<String, String> byModel;
  final asked = <String>[];
  Completer<void>? hold;

  @override
  Future<InkClass?> classify(FreehandElement stroke, {required String model}) async {
    asked.add(model);
    await hold?.future;
    final label = byModel[model];
    return label == null ? null : (label: label, score: 0.1);
  }
}

Duration ms(int v) => Duration(milliseconds: v);

Future<ProviderContainer> _open(
  WidgetTester tester, {
  required _FakeClassifier classifier,
  bool snap = true,
  bool erase = true,
}) async {
  SharedPreferences.setMockInitialValues(
      {'ui.snapShapes': snap, 'ui.scribbleErase': erase});
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    inkClassifierProvider.overrideWithValue(classifier),
  ]);
  addTearDown(container.dispose);
  container.read(settingsProvider); // starts restoring the flags
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: SceneCanvas(notebookId: 0, pageId: 0)),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

List<SceneElement> _scene(ProviderContainer c) =>
    c.read(sceneControllerProvider(_key));

/// A freehand rectangle ([w] x [h] SCREEN pixels from (100, 100)) with a hold at
/// the end, if [holdMs] > 0.
Future<void> _drawRectangle(WidgetTester tester,
    {int holdMs = 700, double w = 120, double h = 100}) async {
  final g = await tester.startGesture(const Offset(100, 100),
      kind: PointerDeviceKind.stylus);
  await g.moveTo(Offset(100 + w, 100), timeStamp: ms(100));
  await g.moveTo(Offset(100 + w, 100 + h), timeStamp: ms(200));
  await g.moveTo(Offset(100, 100 + h), timeStamp: ms(300));
  await g.moveTo(const Offset(100, 102), timeStamp: ms(400));
  if (holdMs > 0) {
    await g.moveTo(const Offset(101, 102), timeStamp: ms(400 + holdMs ~/ 2));
  }
  await g.up(timeStamp: ms(400 + holdMs));
  await tester.pump();
  await tester.pump();
}

/// A scrub back and forth across 100..200 x 100..172.
Future<void> _scrub(WidgetTester tester) async {
  final g = await tester.startGesture(const Offset(100, 100),
      kind: PointerDeviceKind.stylus);
  var t = 0;
  for (var i = 1; i <= 8; i++) {
    t += 40;
    await g.moveTo(Offset(i.isOdd ? 200 : 100, 100 + i * 9.0), timeStamp: ms(t));
  }
  await g.up(timeStamp: ms(t + 10));
  await tester.pump();
  await tester.pump();
}

const _word = SceneShapeElement(
  id: 'word',
  zOrder: 0,
  shapeType: ShapeType.rectangle,
  geometryData: [110, 110, 170, 150],
  color: 0xFF000000,
  strokeWidth: 2,
);

void main() {
  group('hold to snap', () {
    testWidgets('a held rectangle becomes a clean rectangle, in the stroke\'s '
        'colour and width', (tester) async {
      final classifier = _FakeClassifier({kShapesModel: 'RECTANGLE'});
      final c = await _open(tester, classifier: classifier);

      await _drawRectangle(tester);

      final scene = _scene(c);
      expect(scene, hasLength(1));
      final shape = scene.single as SceneShapeElement;
      expect(shape.shapeType, ShapeType.rectangle);
      expect(shape.geometryData, [100, 100, 220, 200]);
      expect(classifier.asked, [kShapesModel]);
    });

    testWidgets('undo brings the freehand stroke back; undo again removes it',
        (tester) async {
      final c = await _open(tester,
          classifier: _FakeClassifier({kShapesModel: 'RECTANGLE'}));
      await _drawRectangle(tester);
      final history = c.read(historyProvider(_key).notifier);

      history.undo();
      expect(_scene(c).single, isA<FreehandElement>(),
          reason: 'one undo undoes the snap, not the drawing');

      history.undo();
      expect(_scene(c), isEmpty);

      history.redo();
      history.redo();
      expect(_scene(c).single, isA<SceneShapeElement>());
    });

    testWidgets('a stroke lifted at once stays as drawn, and the model is '
        'never asked', (tester) async {
      final classifier = _FakeClassifier({kShapesModel: 'RECTANGLE'});
      final c = await _open(tester, classifier: classifier);

      await _drawRectangle(tester, holdMs: 0);

      expect(_scene(c).single, isA<FreehandElement>());
      expect(classifier.asked, isEmpty);
    });

    testWidgets('with the setting off nothing changes', (tester) async {
      final classifier = _FakeClassifier({kShapesModel: 'RECTANGLE'});
      final c = await _open(tester, classifier: classifier, snap: false);

      await _drawRectangle(tester);

      expect(_scene(c).single, isA<FreehandElement>());
      expect(classifier.asked, isEmpty);
    });

    testWidgets('with both settings off the classifier is not even created — '
        'every stroke on every page pays for nothing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(retry: (_, __) => null, overrides: [
        sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
        inkClassifierProvider
            .overrideWith((ref) => throw StateError('created without being asked')),
      ]);
      addTearDown(container.dispose);
      container.read(settingsProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SceneCanvas(notebookId: 0, pageId: 0)),
        ),
      ));
      await tester.pump();
      await tester.pump();

      await _drawRectangle(tester);

      expect(_scene(container).single, isA<FreehandElement>());
    });

    testWidgets('size is judged on the screen: zoomed out, a small drawing is '
        'small, however many scene units it spans', (tester) async {
      final classifier = _FakeClassifier({kShapesModel: 'RECTANGLE'});
      final c = await _open(tester, classifier: classifier);
      c.read(viewportProvider.notifier).zoomAtPoint(0.25, Offset.zero);
      await tester.pump();

      // 30 screen px — 120 scene units at this zoom — is a doodle.
      await _drawRectangle(tester, w: 30, h: 30);

      expect(_scene(c).single, isA<FreehandElement>());
      expect(classifier.asked, isEmpty);
    });

    testWidgets('...and zoomed in, a drawing a few scene units across is big '
        'on the screen, and snaps', (tester) async {
      final classifier = _FakeClassifier({kShapesModel: 'RECTANGLE'});
      final c = await _open(tester, classifier: classifier);
      c.read(viewportProvider.notifier).zoomAtPoint(4, Offset.zero);
      await tester.pump();

      // 120 screen px is only 30 scene units at 4x.
      await _drawRectangle(tester, w: 120, h: 100);

      expect(_scene(c).single, isA<SceneShapeElement>());
    });

    testWidgets('a model with no answer leaves the stroke as drawn',
        (tester) async {
      final c = await _open(tester, classifier: _FakeClassifier({}));

      await _drawRectangle(tester);

      expect(_scene(c).single, isA<FreehandElement>());
    });

    testWidgets('a stroke undone while the model was thinking is not '
        'resurrected as a shape', (tester) async {
      final classifier = _FakeClassifier({kShapesModel: 'RECTANGLE'})
        ..hold = Completer<void>();
      final c = await _open(tester, classifier: classifier);

      await _drawRectangle(tester);
      expect(_scene(c).single, isA<FreehandElement>(), reason: 'visible at once');

      c.read(historyProvider(_key).notifier).undo(); // the student undoes it
      classifier.hold!.complete();
      await tester.pump();
      await tester.pump();

      expect(_scene(c), isEmpty);
    });
  });

  group('scribble to erase', () {
    testWidgets('a scrub over something wipes it out, scribble and all',
        (tester) async {
      final classifier = _FakeClassifier({kGestureModel: 'scribble'});
      final c = await _open(tester, classifier: classifier);
      await c.read(sceneControllerProvider(_key).notifier).add(_word);

      await _scrub(tester);

      expect(_scene(c), isEmpty);
      expect(classifier.asked, [kGestureModel]);
    });

    testWidgets('one undo brings back what was erased', (tester) async {
      final c = await _open(tester,
          classifier: _FakeClassifier({kGestureModel: 'scribble'}));
      await c.read(sceneControllerProvider(_key).notifier).add(_word);
      await _scrub(tester);

      c.read(historyProvider(_key).notifier).undo();

      expect(_scene(c).map((e) => e.id), contains('word'));
      expect(_scene(c), hasLength(2), reason: 'the word and the scribble');
    });

    testWidgets('what was deleted while the model thought is not brought back '
        'by undoing the erase', (tester) async {
      final classifier = _FakeClassifier({kGestureModel: 'scribble'})
        ..hold = Completer<void>();
      final c = await _open(tester, classifier: classifier);
      await c.read(sceneControllerProvider(_key).notifier).add(_word);
      await _scrub(tester);

      // Meanwhile the student removes the word themselves.
      c.read(historyProvider(_key).notifier)
          .push(const RemoveElementsCommand([_word]));
      classifier.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(_scene(c), isEmpty);

      c.read(historyProvider(_key).notifier).undo(); // undo the scribble erase

      expect(_scene(c).map((e) => e.id), isNot(contains('word')),
          reason: 'the scribble returns; the word the student deleted does not');
      expect(_scene(c), hasLength(1));
    });

    testWidgets('a scrub the model calls writing is just ink', (tester) async {
      final c = await _open(tester,
          classifier: _FakeClassifier({kGestureModel: 'writing'}));
      await c.read(sceneControllerProvider(_key).notifier).add(_word);

      await _scrub(tester);

      expect(_scene(c), hasLength(2));
    });

    testWidgets('a scrub over nothing is left as ink', (tester) async {
      final classifier = _FakeClassifier({kGestureModel: 'scribble'});
      final c = await _open(tester, classifier: classifier);

      await _scrub(tester);

      expect(_scene(c).single, isA<FreehandElement>());
      expect(classifier.asked, isEmpty);
    });

    testWidgets('with the setting off nothing is erased', (tester) async {
      final classifier = _FakeClassifier({kGestureModel: 'scribble'});
      final c = await _open(tester, classifier: classifier, erase: false);
      await c.read(sceneControllerProvider(_key).notifier).add(_word);

      await _scrub(tester);

      expect(_scene(c), hasLength(2));
      expect(classifier.asked, isEmpty);
    });
  });
}
