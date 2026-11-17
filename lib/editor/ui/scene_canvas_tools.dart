part of 'scene_canvas.dart';

/// Pointer-tool handlers (eraser, laser, select, commit) split out of the state.
extension _SceneCanvasTools on _SceneCanvasState {
  // ---- eraser ---------------------------------------------------------------

  double _eraserRadius(EditorToolState tool) => math.max(8.0, tool.eraserSize);

  List<SceneElement> _erasable(EditorToolState tool) => EraserService.erasable(
        ref.read(sceneControllerProvider(_key)),
        highlighterOnly: tool.eraserHighlighterOnly,
      );

  void _onEraserDown(EditorToolState tool, StrokePoint p) {
    if (tool.eraserPixel) {
      // The preview of what will be cut: a grey ghost, not the pen's colour.
      _active.begin(_scenePoint(p),
          color: 0xFF9AA0A6, size: tool.eraserSize, opacity: 0.4);
      return;
    }
    final scene = _toScene(p);
    _lastErase = scene;
    _eraserPending.value = EraserService.hitAlongSegment(
      a: scene,
      b: scene,
      radius: _eraserRadius(tool),
      elements: _erasable(tool),
    );
  }

  void _onEraserMove(EditorToolState tool, StrokePoint p) {
    if (tool.eraserPixel) {
      _active.add(_scenePoint(p));
      return;
    }
    final scene = _toScene(p);
    final hits = EraserService.hitAlongSegment(
      a: _lastErase,
      b: scene,
      radius: _eraserRadius(tool),
      elements: _erasable(tool),
      skip: _eraserPending.value,
    );
    if (hits.isNotEmpty) {
      _eraserPending.value = {..._eraserPending.value, ...hits};
    }
    _lastErase = scene;
  }

  void _onEraserUp(EditorToolState tool) {
    if (tool.eraserPixel) {
      final points = _active.take();
      if (points.isEmpty) return;
      // True pixel erase: cut the previewed hole out of real geometry
      // (splitting strokes, converting cut shapes to strokes) as one undo
      // step — no clear-blend overlay element is committed anymore. The
      // outline is built exactly like the preview so the cut matches it.
      final eraserPath =
          FreehandPath.build(points, tool.eraserSize, isComplete: true);
      if (eraserPath == null) return;
      final result = ScenePixelEraserService.erase(
        eraserPath: eraserPath,
        elements: _erasable(tool),
      );
      if (result.isEmpty) return;
      _history.push(
          ReplaceElementsCommand(removed: result.removed, added: result.added));
      return;
    }
    final ids = _eraserPending.value;
    _eraserPending.value = const {};
    if (ids.isEmpty) return;
    final removed = ref
        .read(sceneControllerProvider(_key))
        .where((e) => ids.contains(e.id))
        .toList();
    if (removed.isNotEmpty) _history.push(RemoveElementsCommand(removed));
  }

  // ---- laser ----------------------------------------------------------------

  void _addLaser(Offset scene) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _laser.value = [..._laser.value, LaserPoint(scene, now)];
    if (!_ticker.isActive) _ticker.start();
  }

  void _onLaserTick(Duration _) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pruned = [
      for (final p in _laser.value)
        if (now - p.addedMs <= _kLaserFadeMs) p
    ];
    _laser.value = pruned;
    if (pruned.isEmpty) _ticker.stop();
  }

  // ---- selection gestures ---------------------------------------------------

  void _onSelectDown(StrokePoint p) {
    if (ref.read(editorToolProvider).selectText) {
      _onTextSelectDown(_toScene(p));
      return;
    }
    final scene = _toScene(p);
    final screen = Offset(p.x, p.y);
    final vp = ref.read(viewportProvider);
    final selected = _selectedElements();

    // A locked selection (a page-locked import) shows no resize/rotate/move
    // gesture at all — only re-selecting it and the selection-bar actions
    // (Extract text, Unlock, ...) are reachable. The overlay still draws
    // handles for it; this just makes them inert rather than hiding them, which
    // is a cosmetic gap, not a correctness one.
    if (selected.isNotEmpty && selected.every((e) => !e.isLocked)) {
      final box = SelectionBounds.union(selected)!;
      final rotateScreen =
          vp.toViewport(box.topCenter) - const Offset(0, kRotateGap);
      if ((screen - rotateScreen).distance <= kHandleHitRadius) {
        _beginGesture(_SelMode.rotate, box, scene, selected);
        return;
      }
      for (final entry in SelectionBounds.handlePoints(box).entries) {
        if ((screen - vp.toViewport(entry.value)).distance <=
            kHandleHitRadius) {
          _activeHandle = entry.key;
          _beginGesture(_SelMode.resize, box, scene, selected);
          return;
        }
      }
    }

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final all = ref.read(sceneControllerProvider(_key));
    // Locked elements (a PDF page, a photo given its own page) are the paper,
    // not something on it: a touch there starts a marquee, so the ink written
    // over a PDF can be selected without grabbing the PDF. They stay
    // selectable for "Extract text" / "Unlock" with a plain TAP, resolved in
    // [_onSelectUp] from [_lockedUnderTap].
    final hitId = SceneHitTest.topmostAt(scene, all);
    _lockedUnderTap =
        hitId == null ? SceneHitTest.topmostAt(scene, all, includeLocked: true) : null;

    // Double-tap a text to type into it.
    final hit = hitId == null ? null : all.firstWhere((e) => e.id == hitId);
    final now = DateTime.now();
    final lastAt = _lastTextTapAt;
    if (hit is TextElement &&
        !hit.isLocked &&
        _lastTextTapId == hitId &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(milliseconds: 450)) {
      _lastTextTapId = null;
      _selMode = _SelMode.none;
      _beginEdit(hit);
      return;
    }
    _lastTextTapId = hit is TextElement ? hitId : null;
    _lastTextTapAt = now;
    final selCtl = ref.read(selectionProvider.notifier);

    if (hitId != null) {
      final group = _groupIds(hitId, all);
      final current = ref.read(selectionProvider);
      if (shift) {
        selCtl.selectMany({...current, ...group});
      } else if (!current.contains(hitId)) {
        selCtl.selectMany(group);
      }
      final nowSelected = _selectedElements();
      if (nowSelected.every((e) => !e.isLocked)) {
        _beginGesture(
            _SelMode.move, SelectionBounds.union(nowSelected)!, scene, nowSelected);
      }
      return;
    }

    if (selected.isNotEmpty && selected.every((e) => !e.isLocked)) {
      final box = SelectionBounds.union(selected)!;
      if (box.contains(scene)) {
        _beginGesture(_SelMode.move, box, scene, selected);
        return;
      }
    }

    if (!shift) selCtl.clear();
    _selMode = _SelMode.marquee;
    _gestureStartScene = scene;
    _marquee.value = Rect.fromPoints(scene, scene);
    // A lasso is a marquee that remembers its path: the box still tells a tap
    // from a drag.
    _lasso.value = ref.read(editorToolProvider).selectLasso ? [scene] : null;
  }

  void _beginGesture(
      _SelMode mode, Rect box, Offset scene, List<SceneElement> originals) {
    _selMode = mode;
    _selBoxStart = box;
    _gestureStartScene = scene;
    // Moving a frame drags the elements it contains along with it.
    _selOriginals =
        mode == _SelMode.move ? _expandMoveTargets(originals) : originals;
    _didTransform = false;
    // Snap targets are fixed for the whole move; compute them once, not per move.
    if (mode == _SelMode.move) {
      final selIds = _selOriginals.map((e) => e.id).toSet();
      _snapTargets = [
        for (final e in ref.read(sceneControllerProvider(_key)))
          if (!selIds.contains(e.id)) SceneGeometry.worldAabb(e),
      ];
    }
  }

  /// Expands [selected] to include the members of any selected frame, so a move
  /// gesture carries the frame's contents.
  List<SceneElement> _expandMoveTargets(List<SceneElement> selected) {
    if (!selected.any((e) => e is FrameElement)) return selected;
    final all = ref.read(sceneControllerProvider(_key));
    final ids =
        FrameService.expandWithMembers(selected.map((e) => e.id).toSet(), all);
    // A locked member must stay put even when its frame is dragged.
    return all
        .where((e) => ids.contains(e.id) && !e.isLocked)
        .toList();
  }

  void _onSelectMove(StrokePoint p) {
    final scene = _toScene(p);
    switch (_selMode) {
      case _SelMode.move:
        _applyMove(scene);
      case _SelMode.resize:
        _applyResize(scene);
      case _SelMode.rotate:
        _applyRotate(scene);
      case _SelMode.marquee:
        _marquee.value = Rect.fromPoints(_gestureStartScene, scene);
        final loop = _lasso.value;
        if (loop != null) _lasso.value = [...loop, scene];
      case _SelMode.text:
        _onTextSelectMove(scene);
      case _SelMode.none:
        break;
    }
  }

  void _applyMove(Offset scene) {
    final delta = scene - _gestureStartScene;
    final movingBox = _selBoxStart.shift(delta);
    final zoom = ref.read(viewportProvider).zoom;
    final snap = SnapEngine.snap(movingBox, _snapTargets, _kSnapScreen / zoom);
    final finalDelta = delta + snap.adjust;
    _guides.value = [for (final g in snap.guides) (g.a, g.b)];
    _didTransform = true;
    _scene.updateInMemory([
      for (final e in _selOriginals) SceneTransformer.translate(e, finalDelta)
    ]);
  }

  void _applyResize(Offset scene) {
    final r = SelectionBounds.resize(
      _selBoxStart,
      _activeHandle!,
      scene,
      aspect: HardwareKeyboard.instance.isShiftPressed,
      fromCenter: HardwareKeyboard.instance.isAltPressed,
    );
    _didTransform = true;
    _scene.updateInMemory([
      for (final e in _selOriginals)
        SceneTransformer.scaleAbout(e, r.sx, r.sy, r.anchor)
    ]);
  }

  void _applyRotate(Offset scene) {
    final center = _selBoxStart.center;
    final start = _gestureStartScene - center;
    final cur = scene - center;
    final angle = math.atan2(cur.dy, cur.dx) - math.atan2(start.dy, start.dx);
    _didTransform = true;
    _scene.updateInMemory([
      for (final e in _selOriginals)
        SceneTransformer.rotateAbout(e, angle, center)
    ]);
  }

  void _onSelectUp(StrokePoint p) {
    if (_selMode == _SelMode.text) {
      _onTextSelectUp(_toScene(p));
      return;
    }
    final lockedUnderTap = _lockedUnderTap;
    _lockedUnderTap = null;
    if (_selMode == _SelMode.marquee) {
      final rect = _marquee.value;
      final loop = _lasso.value;
      _marquee.value = null;
      _lasso.value = null;
      final zoom = ref.read(viewportProvider).zoom;
      final isTap = rect != null &&
          rect.width * zoom <= kTapSlopPx &&
          rect.height * zoom <= kTapSlopPx;
      if (isTap && lockedUnderTap != null) {
        ref.read(selectionProvider.notifier).selectMany({lockedUnderTap});
      } else if (rect != null) {
        final all = ref.read(sceneControllerProvider(_key));
        final ids = loop != null
            ? SceneHitTest.withinPolygon(loop, all)
            : SceneHitTest.within(rect, all);
        // A drag that began on a locked page and caught nothing: the person
        // was most likely trying to move the page. Say how.
        if (ids.isEmpty && lockedUnderTap != null) {
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text(
                  'This page is locked in place. Tap it, then tap Unlock to move it.'),
            ));
        }
        final expanded = <String>{};
        for (final id in ids) {
          expanded.addAll(_groupIds(id, all));
        }
        ref.read(selectionProvider.notifier).selectMany(expanded);
      }
    } else if (_didTransform &&
        (_selMode == _SelMode.move ||
            _selMode == _SelMode.resize ||
            _selMode == _SelMode.rotate)) {
      // Snapshot the same set we transformed (move may include frame members
      // beyond the selection), so undo/redo round-trips them too.
      final ids = _selOriginals.map((e) => e.id).toSet();
      final after = ref
          .read(sceneControllerProvider(_key))
          .where((e) => ids.contains(e.id))
          .toList();
      // The preview outlines were mapped, not rebuilt; draw the result exactly.
      after.forEach(SceneTransformer.settle);
      // Per-move updates were in-memory only; persist the final state once.
      _scene.updateMany(after);
      _history.pushApplied(
          UpdateElementsCommand(before: _selOriginals, after: after));
    }
    _selMode = _SelMode.none;
    _activeHandle = null;
    _selOriginals = const [];
    _didTransform = false;
    _guides.value = const [];
  }

  Set<String> _groupIds(String id, List<SceneElement> all) {
    final el = all.firstWhere((e) => e.id == id);
    if (el.groupId.isEmpty) return {id};
    return all.where((e) => e.groupId == el.groupId).map((e) => e.id).toSet();
  }

  // ---- commit (pen / shape / text) ------------------------------------------

  void _commitStroke(EditorToolState tool, {int? upMs}) {
    final points = _active.take();
    if (points.isEmpty) return;
    // If a lecture is being recorded, stamp the stroke with how far into that
    // recording it began — measured from the stroke's FIRST point, so tapping
    // it later seeks to when the writing started, not when the pen lifted.
    final stamp = widget.stampStroke?.call(strokeAgeMs(points, upMs));
    final stroke = FreehandElement(
      id: _newId(),
      zOrder: _scene.nextZOrder(),
      points: points,
      color: tool.color,
      size: tool.size,
      opacity: tool.opacity,
      penKind: tool.penKind,
      recordingId: stamp?.recordingId,
      audioOffsetMs: stamp?.audioOffsetMs,
    );
    _history.push(AddElementsCommand([stroke]));

    final up = upMs ?? points.last.t ?? 0;
    // A highlighter over printed text on a page picture snaps to the words.
    // Finding them can take a moment (the first time, they are read off the
    // picture), so it finishes on its own; the stroke is on the page already.
    if (stroke.penKind == PenKind.highlighter &&
        ref.read(settingsProvider).snapHighlighter) {
      final image = _imageUnderStroke(stroke);
      if (image != null) {
        unawaited(_snapHighlight(stroke, image, up));
        return;
      }
    }
    _finishStroke(stroke, up);
  }

  /// What happens after a stroke is on the page: straighten it if it was held
  /// at the end, otherwise offer it to the ink gestures.
  void _finishStroke(FreehandElement stroke, int up) {
    final points = stroke.points;
    // Held at the end of a line: straighten it, as its own undo step so one
    // undo brings back the line as drawn. Needs no model, and a straightened
    // line is not then offered to the shape model as well.
    final straight = ref.read(settingsProvider).straightenLines
        ? straightenedLine(points, up, zoom: ref.read(viewportProvider).zoom)
        : null;
    if (straight != null) {
      _history.push(ReplaceElementsCommand(
        removed: [stroke],
        added: [stroke.copyWith(points: straight)],
      ));
      unawaited(HapticFeedback.selectionClick());
      return;
    }
    _maybeResolveGesture(stroke, up);
  }

  // ---- ink gestures ---------------------------------------------------------

  /// Hold-to-snap and scribble-to-erase (see `tools/ink_gestures.dart`). Decided
  /// AFTER the stroke is committed, so it is on the page at once and a gesture
  /// that is not recognised costs nothing; and entirely downstream of the pointer
  /// pipeline, whose palm rejection this never touches. Off unless switched on.
  void _maybeResolveGesture(FreehandElement stroke, int upMs) {
    final settings = ref.read(settingsProvider);
    if (!settings.snapShapes && !settings.scribbleErase) return;
    unawaited(_resolveGesture(stroke, upMs, settings));
  }

  Future<void> _resolveGesture(
      FreehandElement stroke, int upMs, SettingsState settings) async {
    final action = await resolveInkGesture(
      stroke: stroke,
      scene: ref.read(sceneControllerProvider(_key)),
      upMs: upMs,
      classifier: ref.read(inkClassifierProvider),
      snapShapes: settings.snapShapes,
      scribbleErase: settings.scribbleErase,
      zoom: ref.read(viewportProvider).zoom,
      newId: _newId,
      seed: math.Random().nextInt(0x7fffffff),
    );
    if (action == null || !mounted) return;

    // The model took a moment: the stroke may have been undone, or what it was
    // meant to wipe out already gone. Act only on what is still on the page.
    final onPage = {for (final e in ref.read(sceneControllerProvider(_key))) e.id};
    if (!onPage.contains(stroke.id)) return;
    switch (action) {
      case SnapToShape(:final shape):
        _history.push(ReplaceElementsCommand(removed: [stroke], added: [shape]));
        unawaited(HapticFeedback.selectionClick());
      case ScribbleErase(:final victims):
        _history.push(RemoveElementsCommand([
          stroke,
          for (final v in victims)
            if (onPage.contains(v.id)) v,
        ]));
    }
  }

  void _commitShape(EditorToolState tool, Offset end) {
    final start = _shapeStart;
    _shapeStart = null;
    _preview.value = null;
    if (start == null) return;
    if ((end - start).distance < 2) return;
    _history.push(AddElementsCommand([
      ShapeFactory.build(
        tool: tool,
        start: start,
        current: end,
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        seed: _shapeSeed,
      )
    ]));
  }

  // ---- frame ----------------------------------------------------------------

  SceneShapeElement _framePreview(Offset a, Offset b) => SceneShapeElement(
        id: '_preview',
        zOrder: 0,
        shapeType: ShapeType.rectangle,
        geometryData: [a.dx, a.dy, b.dx, b.dy],
        color: 0xFF8A93A6,
        strokeWidth: 1.5,
        strokeStyle: StrokeStyle.dashed,
      );

  // ---- revision tape -----------------------------------------------------------

  /// The strip a tape drag from [a] to [b] lays: the dragged box, but never
  /// thinner than [kTapeMinThickness], so a quick stroke along a line of
  /// writing covers it.
  Rect _tapeRect(Offset a, Offset b) {
    var r = Rect.fromPoints(a, b);
    if (r.height < kTapeMinThickness) {
      r = Rect.fromCenter(
          center: r.center, width: r.width, height: kTapeMinThickness);
    }
    if (r.width < kTapeMinThickness) {
      r = Rect.fromCenter(
          center: r.center, width: kTapeMinThickness, height: r.height);
    }
    return r;
  }

  SceneShapeElement _tapePreview(EditorToolState tool, Offset a, Offset b) {
    final r = _tapeRect(a, b);
    return SceneShapeElement(
      id: '_preview',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [r.left, r.top, r.right, r.bottom],
      color: tool.tapeColor,
      strokeWidth: 1,
      hasFill: true,
      fillColor: tool.tapeColor,
      fillStyle: FillStyle.solid,
    );
  }

  /// A tap on tape lifts it or lays it back (remembered with the page, but not
  /// an undo step: peeking is reading, not editing). A drag lays new tape, as
  /// one undo step.
  void _commitTape(EditorToolState tool, Offset end) {
    final start = _shapeStart;
    _shapeStart = null;
    _preview.value = null;
    if (start == null) return;
    final zoom = ref.read(viewportProvider).zoom;
    final isTap = (end - start).distance * zoom <= kTapSlopPx;
    if (isTap) {
      final all = ref.read(sceneControllerProvider(_key));
      final hitId = SceneHitTest.topmostAt(start, all.whereType<TapeElement>().toList());
      if (hitId == null) return;
      final tape = all.firstWhere((e) => e.id == hitId) as TapeElement;
      _scene.updateMany([tape.copyWith(revealed: !tape.revealed)]);
      unawaited(HapticFeedback.selectionClick());
      return;
    }
    final r = _tapeRect(start, end);
    _history.push(AddElementsCommand([
      TapeElement(
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        geometryData: [r.left, r.top, r.right, r.bottom],
        color: tool.tapeColor,
      )
    ]));
  }

  void _commitFrame(Offset end) {
    final start = _shapeStart;
    _shapeStart = null;
    _preview.value = null;
    if (start == null) return;
    final rect = Rect.fromPoints(start, end);
    if (rect.width < 8 || rect.height < 8) return;
    final count = ref
            .read(sceneControllerProvider(_key))
            .whereType<FrameElement>()
            .length +
        1;
    _history.push(AddElementsCommand([
      FrameElement(
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        geometryData: [rect.left, rect.top, rect.right, rect.bottom],
        name: 'Frame $count',
      )
    ]));
  }

  // ---- typing on the page ----------------------------------------------------

  /// The text tool touched the page at [scene]: open a field there.
  void _beginNewText(Offset scene) {
    final tool = ref.read(editorToolProvider);
    _openInline(InlineTextSession(
      origin: scene,
      fontSize: tool.fontSize,
      fontFamily: tool.fontFamily,
      color: tool.color,
      opacity: tool.opacity,
    ));
  }

  /// Opens the field on an existing text, which is hidden while it is edited.
  void _beginEdit(TextElement t) {
    ref.read(selectionProvider.notifier).clear();
    _openInline(InlineTextSession.edit(t, ElementBounds.of(t)));
  }

  void _openInline(InlineTextSession session) {
    // Another text still open is finished first.
    _inlineKey.currentState?.commit();
    _setInline(session);
  }

  /// Closes the field: gives back any scroll used to keep it above the
  /// keyboard.
  void _endInline() {
    _tapToCommit = false;
    if (_closing) {
      _inline = null;
      return;
    }
    if (_liftedBy != 0) {
      ref.read(viewportProvider.notifier).pan(Offset(0, _liftedBy));
      _liftedBy = 0;
    }
    _setInline(null);
  }

  /// Pushes the text's undo step: at once, or, while the canvas is being taken
  /// down (the widget tree is locked then and must not be told of changes), a
  /// moment later on this page's history, which outlives the canvas.
  void _pushInline(SceneCommand command) {
    if (!_closing) {
      _history.push(command);
      return;
    }
    final history = _history;
    Future.microtask(() => history.push(command));
  }

  /// The field's text, as one undo step: a new text is added (unless left
  /// empty), an edited one updated, and one cleared to nothing deleted.
  void _commitInline(SceneTextResult r, double width) {
    final s = _inline;
    if (s == null) return;
    _endInline();
    final body = r.text.trim();
    final editing = s.editing;

    if (editing == null) {
      if (body.isEmpty) return;
      final o = s.origin;
      final text = TextElement(
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        geometryData: [o.dx, o.dy, o.dx + width, o.dy],
        text: body,
        color: s.color,
        fontSize: s.fontSize,
        fontFamily: s.fontFamily,
        opacity: s.opacity,
        isBold: r.isBold,
        isItalic: r.isItalic,
        align: r.align,
      );
      // Height from the same layout the painter uses, so a multi-line note's
      // box encloses every line (selection, hit-testing, export crop).
      final h = SceneElementPainter.layOutText(text, width).height;
      _pushInline(AddElementsCommand([
        text.copyWith(geometryData: [o.dx, o.dy, o.dx + width, o.dy + h])
      ]));
      return;
    }

    if (body.isEmpty) {
      _pushInline(RemoveElementsCommand([editing]));
      return;
    }
    final updated = editing.copyWith(
      text: body,
      isBold: r.isBold,
      isItalic: r.isItalic,
      align: r.align,
    );
    if (updated.text == editing.text &&
        updated.isBold == editing.isBold &&
        updated.isItalic == editing.isItalic &&
        updated.align == editing.align) {
      return;
    }
    final rect = ElementBounds.of(editing);
    final h = SceneElementPainter.layOutText(updated, rect.width).height;
    _pushInline(UpdateElementsCommand(before: [
      editing
    ], after: [
      updated.copyWith(geometryData: [
        rect.left,
        rect.top,
        rect.right,
        rect.top + math.max(h, updated.fontSize),
      ])
    ]));
  }

  /// Scrolls the page up if the field (at [field], in canvas coordinates)
  /// would sit under the keyboard. The editor does not resize for the keyboard,
  /// so without this the text being typed could be hidden.
  void _keepInlineVisible(Rect field) {
    if (_inline == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final canvasBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final covered = math.max(0.0, keyboard - (screenHeight - canvasBottom));
    final visibleBottom = box.size.height - covered - 16;
    final over = field.bottom - visibleBottom;
    if (over <= 1) return;
    // Never push the top of the text (and its strip) off the top.
    final lift = math.min(over, math.max(0.0, field.top - 64));
    if (lift <= 1) return;
    final vp = ref.read(viewportProvider.notifier);
    final before = ref.read(viewportProvider).scrollY;
    vp.pan(Offset(0, -lift));
    _liftedBy += before - ref.read(viewportProvider).scrollY;
  }
}
