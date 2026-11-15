part of 'scene_canvas.dart';

/// Text on page pictures: selecting words with the select tool's Text mode,
/// and snapping a highlighter stroke over printed text to the words.
extension _SceneCanvasText on _SceneCanvasState {
  // ---- selecting words -------------------------------------------------------

  void _onTextSelectDown(Offset scene) {
    _selMode = _SelMode.text;
    _textAnchor = scene;
    _textLast = null;
    ref.read(selectionProvider.notifier).clear();
    ref.read(pageTextSelectionProvider.notifier).state = null;
    final image = topImageAt(ref.read(sceneControllerProvider(_key)), scene);
    _textImage = image;
    _textWords = null;
    if (image == null) return;

    final service = ref.read(pageWordsServiceProvider);
    final cached = service.cached(image.relativeImagePath);
    if (cached != null) {
      _textWords = cached;
      _updateTextSelection(scene);
      return;
    }
    // First use of this picture: its words may have to be read off it.
    _textToast('Reading the page…');
    unawaited(service.wordsFor(image.relativeImagePath).then((words) {
      if (!mounted || _textImage?.id != image.id) return;
      _textWords = words;
      if (words.isEmpty) {
        _textToast('No text found on this picture.');
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      _updateTextSelection(_textLast ?? _textAnchor);
    }));
  }

  void _onTextSelectMove(Offset scene) {
    _textLast = scene;
    _updateTextSelection(scene);
  }

  void _onTextSelectUp(Offset scene) {
    _textLast = scene;
    _updateTextSelection(scene);
    _selMode = _SelMode.none;
  }

  /// Selects the words from the one under where the drag began to the one
  /// under [current]. Leaves the selection as it was while either end is off
  /// the text.
  void _updateTextSelection(Offset current) {
    final image = _textImage, words = _textWords;
    if (image == null || words == null || words.isEmpty) return;
    final size = image.boundsRect.size;
    final tolerance = 24 / ref.read(viewportProvider).zoom;
    final a = wordAt(words, toImageUnit(_textAnchor, image),
        size: size, tolerance: tolerance);
    final b = wordAt(words, toImageUnit(current, image),
        size: size, tolerance: tolerance);
    if (a == null || b == null) return;
    ref.read(pageTextSelectionProvider.notifier).state = PageTextSelection(
      key: _key,
      imageId: image.id,
      words: words,
      indexes: wordsBetween(a, b),
    );
  }

  void _textToast(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  // ---- snapping a highlighter to the words ----------------------------------

  /// The picture a highlighter [stroke] was drawn over, judged at its middle.
  ImageElement? _imageUnderStroke(FreehandElement stroke) {
    final p = stroke.points[stroke.points.length ~/ 2];
    return topImageAt(
        ref.read(sceneControllerProvider(_key)), Offset(p.x, p.y));
  }

  /// Replaces a highlighter [stroke] over the words of [image] with clean marks
  /// over exactly those words, as its own undo step (one undo brings back the
  /// stroke as drawn). A stroke that covers no word goes on as any stroke
  /// does (straighten, ink gestures).
  Future<void> _snapHighlight(
      FreehandElement stroke, ImageElement image, int upMs) async {
    final words =
        await ref.read(pageWordsServiceProvider).wordsFor(image.relativeImagePath);
    if (!mounted) return;
    // The words may have taken a moment: act only on what is still there.
    final scene = ref.read(sceneControllerProvider(_key));
    if (!scene.any((e) => e.id == stroke.id)) return;
    final hit = words.isEmpty
        ? const <int>[]
        : wordsUnderStroke(words, [
            for (final p in stroke.points) toImageUnit(Offset(p.x, p.y), image),
          ]);
    if (hit.isEmpty) {
      _finishStroke(stroke, upMs);
      return;
    }
    final snapped = highlightStrokes(
      image: image,
      words: words,
      indexes: hit,
      color: stroke.color,
      opacity: stroke.opacity,
      newId: _newId,
      nextZOrder: _scene.nextZOrder,
    );
    if (snapped.isEmpty) {
      _finishStroke(stroke, upMs);
      return;
    }
    _history.push(ReplaceElementsCommand(removed: [stroke], added: snapped));
    unawaited(HapticFeedback.selectionClick());
  }
}
