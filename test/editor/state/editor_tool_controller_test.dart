import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/editor_tool_controller.dart';

void main() {
  test('EditorToolController updates tool/color/size/opacity', () {
    final c = EditorToolController();
    expect(c.state.tool, EditorTool.pen);
    expect(c.state.isHand, false);

    c.setTool(EditorTool.hand);
    expect(c.state.tool, EditorTool.hand);
    expect(c.state.isHand, true);

    c.setSize(12);
    expect(c.state.size, 12);

    c.setOpacity(0.4);
    expect(c.state.opacity, 0.4);
  });

  test('setColor is the one universal colour — it sets stroke AND fill',
      () {
    final c = EditorToolController();
    c.setColor(0xFFFF0000);
    expect(c.state.color, 0xFFFF0000);
    expect(c.state.fillColor, 0xFFFF0000);
  });

  test('setShapeType switches to the shape tool and records the type', () {
    final c = EditorToolController();
    c.setShapeType(ShapeType.diamond);
    expect(c.state.tool, EditorTool.shape);
    expect(c.state.shapeType, ShapeType.diamond);
  });

  test('shape style setters update state', () {
    final c = EditorToolController();
    c.setHasFill(true);
    c.setFillStyle(FillStyle.solid);
    c.setStrokeStyle(StrokeStyle.dashed);
    c.setEdges(EdgeStyle.round);
    c.setEndArrowhead(Arrowhead.dot);
    c.setElbowed(true);

    expect(c.state.hasFill, true);
    expect(c.state.fillStyle, FillStyle.solid);
    expect(c.state.strokeStyle, StrokeStyle.dashed);
    expect(c.state.edges, EdgeStyle.round);
    expect(c.state.endArrowhead, Arrowhead.dot);
    expect(c.state.elbowed, true);
  });

  group('arrow tool', () {
    test('selectArrowTool switches into shape+arrow and opens the panel',
        () {
      final c = EditorToolController();
      c.closePanel();
      c.selectArrowTool();
      expect(c.state.tool, EditorTool.shape);
      expect(c.state.shapeType, ShapeType.arrow);
      expect(c.state.panelOpen, isTrue);
    });

    test('selecting it again while already active toggles the panel', () {
      final c = EditorToolController();
      c.selectArrowTool();
      expect(c.state.panelOpen, isTrue);

      c.selectArrowTool(); // already arrow → toggle closed
      expect(c.state.panelOpen, isFalse);
      expect(c.state.shapeType, ShapeType.arrow);

      c.selectArrowTool(); // already arrow → toggle back open
      expect(c.state.panelOpen, isTrue);
    });

    test('switching to another shape and back to arrow reselects it', () {
      final c = EditorToolController();
      c.selectArrowTool();
      c.setShapeType(ShapeType.rectangle);
      expect(c.state.shapeType, ShapeType.rectangle);

      c.selectArrowTool();
      expect(c.state.shapeType, ShapeType.arrow);
      expect(c.state.panelOpen, isTrue);
    });
  });

  group('options panel visibility', () {
    test('the panel starts open on the default tool', () {
      final c = EditorToolController();
      expect(c.state.panelOpen, isTrue);
    });

    test('switching to a different tool (re)opens the panel', () {
      final c = EditorToolController();
      c.closePanel();
      expect(c.state.panelOpen, isFalse);

      c.setTool(EditorTool.eraser);
      expect(c.state.tool, EditorTool.eraser);
      expect(c.state.panelOpen, isTrue);
    });

    test('re-selecting the already-active tool toggles the panel', () {
      final c = EditorToolController();
      expect(c.state.tool, EditorTool.pen);
      expect(c.state.panelOpen, isTrue);

      c.setTool(EditorTool.pen); // same tool → toggle closed
      expect(c.state.panelOpen, isFalse);

      c.setTool(EditorTool.pen); // same tool again → toggle back open
      expect(c.state.panelOpen, isTrue);
    });

    test('closePanel hides the panel and is idempotent', () {
      final c = EditorToolController();
      c.closePanel();
      expect(c.state.panelOpen, isFalse);

      // Calling it again while already closed must not throw or otherwise
      // disturb state (it's called unconditionally on every canvas gesture).
      c.closePanel();
      expect(c.state.panelOpen, isFalse);
      expect(c.state.tool, EditorTool.pen);
    });

    test('closePanel does not change the active tool', () {
      final c = EditorToolController();
      c.setTool(EditorTool.shape);
      c.closePanel();
      expect(c.state.tool, EditorTool.shape);
      expect(c.state.panelOpen, isFalse);
    });
  });
}
