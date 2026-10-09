part of 'scene_canvas.dart';

/// Pointer-tool handlers (eraser, laser, select, commit) split out of the state.
extension _SceneCanvasTools on _SceneCanvasState {
  // ---- eraser ---------------------------------------------------------------

  double _eraserRadius(EditorToolState tool) => math.max(8.0, tool.size);

  void _onEraserDown(EditorToolState tool, StrokePoint p) {
    if (tool.eraserPixel) {
      _active.value = [_scenePoint(p)];
      return;
    }
    final scene = _toScene(p);
    _lastErase = scene;
    _eraserPending.value = EraserService.hitAlongSegment(
      a: scene,
      b: scene,
      radius: _eraserRadius(tool),
      elements: ref.read(sceneControllerProvider(_key)),
    );
  }

  void _onEraserMove(EditorToolState tool, StrokePoint p) {
    if (tool.eraserPixel) {
      if (_active.value.isNotEmpty) {
        _active.value = [..._active.value, _scenePoint(p)];
      }
      return;
    }
    final scene = _toScene(p);
    final hits = EraserService.hitAlongSegment(
      a: _lastErase,
      b: scene,
      radius: _eraserRadius(tool),
      elements: ref.read(sceneControllerProvider(_key)),
      skip: _eraserPending.value,
    );
    if (hits.isNotEmpty) {
      _eraserPending.value = {..._eraserPending.value, ...hits};
    }
    _lastErase = scene;
  }

  void _onEraserUp(EditorToolState tool) {
    if (tool.eraserPixel) {
      final points = _active.value;
      _active.value = const [];
      if (points.isEmpty) return;
      // True pixel erase: cut the previewed hole out of real geometry
      // (splitting strokes, converting cut shapes to strokes) as one undo
      // step — no clear-blend overlay element is committed anymore. The
      // outline is built exactly like the preview so the cut matches it.
      final eraserPath =
          FreehandPath.build(points, tool.size, isComplete: true);
      if (eraserPath == null) return;
      final result = ScenePixelEraserService.erase(
        eraserPath: eraserPath,
        elements: ref.read(sceneControllerProvider(_key)),
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
    // Locked elements ARE selectable (a page-locked import must still be
    // reachable for "Extract text" / "Unlock" in the selection bar — otherwise
    // locking it makes it permanently inert) but must not be draggable, or
    // locking would do nothing to protect it from a stray move gesture.
    final hitId = SceneHitTest.topmostAt(scene, all, includeLocked: true);
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
    if (_selMode == _SelMode.marquee) {
      final rect = _marquee.value;
      _marquee.value = null;
      if (rect != null) {
        final all = ref.read(sceneControllerProvider(_key));
        final ids = SceneHitTest.within(rect, all);
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
    final points = _active.value;
    _active.value = const [];
    if (points.isEmpty) return;
    // If a lecture is being recorded, stamp the stroke with how far into that
    // recording it began — measured from the stroke's FIRST point, so tapping
    // it later seeks to when the writing started, not when the pen lifted.
    final stamp = ref
        .read(recordingSessionProvider(_key.notebookId))
        .stampFor(points.first.t ?? _engineNowMs());
    final stroke = FreehandElement(
      id: _newId(),
      zOrder: _scene.nextZOrder(),
      points: points,
      color: tool.color,
      size: tool.size,
      opacity: tool.opacity,
      recordingId: stamp?.recordingId,
      audioOffsetMs: stamp?.audioOffsetMs,
    );
    _history.push(AddElementsCommand([stroke]));
    _maybeResolveGesture(stroke, upMs ?? points.last.t ?? 0);
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
      case ScribbleErase(:final victims):
        _history.push(RemoveElementsCommand([
          stroke,
          for (final v in victims)
            if (onPage.contains(v.id)) v,
        ]));
    }
  }

  int _engineNowMs() => ref.read(engineClockProvider)();

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

  Future<void> _createText(Offset scene) async {
    final tool = ref.read(editorToolProvider);
    final result = await showSceneTextDialog(
      context,
      title: 'Add text',
      confirmLabel: 'Add',
    );
    if (result == null || result.text.trim().isEmpty) return;
    if (!mounted) return;
    final body = result.text.trim();
    final w = math.max(120.0, body.length * tool.fontSize * 0.6);
    _history.push(AddElementsCommand([
      TextElement(
        id: _newId(),
        zOrder: _scene.nextZOrder(),
        geometryData: [
          scene.dx,
          scene.dy,
          scene.dx + w,
          scene.dy + tool.fontSize * 1.6
        ],
        text: body,
        color: tool.color,
        fontSize: tool.fontSize,
        fontFamily: tool.fontFamily,
        opacity: tool.opacity,
        isBold: result.isBold,
        isItalic: result.isItalic,
        align: result.align,
      )
    ]));
  }
}
