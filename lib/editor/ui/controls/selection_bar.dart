// The selection action bar — shown above the toolbar whenever one or more
// elements are selected (delete, duplicate, copy, edit/extract text, save to
// library, group/lock, reorder, align/distribute).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/commands/scene_command.dart';
import '../../../domain/geometry/element_bounds.dart';
import '../../../domain/model/scene_element.dart';
import '../../../domain/services/alignment_service.dart';
import '../../../domain/services/selection_editing.dart';
import '../../../domain/services/z_order_service.dart';
import '../../../features/ai/data/ocr/image_text_recognition_service.dart';
import '../../../features/ai/presentation/ai_providers.dart';
import '../../import/ocr_layout.dart';
import '../../render/scene_element_painter.dart';
import '../../render/scene_image_cache.dart';
import '../../state/clipboard_service.dart';
import '../../state/history_controller.dart';
import '../../state/library_controller.dart';
import '../../state/scene_controller.dart';
import '../../state/scene_image_cache_provider.dart';
import '../../state/selection_controller.dart';
import '../text_input_dialog.dart';
import 'editor_controls_shared.dart';

class SelectionBar extends ConsumerWidget {
  final ScenePageKey pageKey;
  const SelectionBar({super.key, required this.pageKey});

  List<SceneElement> _sel(WidgetRef ref) => editorSelection(ref, pageKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.read(historyProvider(pageKey).notifier);
    final sel = ref.read(selectionProvider.notifier);
    final ids = ref.read(selectionProvider);
    final all = ref.read(sceneControllerProvider(pageKey));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              history.push(RemoveElementsCommand(_sel(ref)));
              sel.clear();
            },
          ),
          IconButton(
            tooltip: 'Duplicate',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              final copies = SelectionEditing.duplicate(_sel(ref),
                  offset: const Offset(16, 16), nextId: editorNewId);
              history.push(AddElementsCommand(copies));
              sel.selectMany(copies.map((e) => e.id));
            },
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.content_copy),
            onPressed: () => ClipboardService.copy(_sel(ref)),
          ),
          // Only offered for a single text element: editing is inherently about
          // one element's words, and a locked one is not up for changing.
          if (_editableText(ids, all) case final TextElement t)
            IconButton(
              tooltip: 'Edit text',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editText(context, ref, t),
            ),
          // Turns an imported page or photo into editable text sitting over it.
          if (_singleImage(ids, all) case final ImageElement im)
            IconButton(
              tooltip: 'Extract text',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => _extractText(context, ref, im),
            ),
          IconButton(
            tooltip: 'Save to library',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _saveToLibrary(context, ref),
          ),
          IconButton(
            tooltip: 'Group',
            icon: const Icon(Icons.join_full),
            onPressed: () {
              final before = _sel(ref);
              final gid = editorNewId();
              history.push(UpdateElementsCommand(
                before: before,
                after: [
                  for (final e in before) SelectionEditing.withGroup(e, gid)
                ],
              ));
            },
          ),
          IconButton(
            tooltip: 'Ungroup',
            icon: const Icon(Icons.join_inner),
            onPressed: () {
              final before = _sel(ref);
              history.push(UpdateElementsCommand(
                before: before,
                after: [
                  for (final e in before) SelectionEditing.withGroup(e, '')
                ],
              ));
            },
          ),
          Builder(builder: (context) {
            final before = _sel(ref);
            // If everything selected is already locked, this un-locks; any
            // unlocked element in the mix locks the whole selection. Selection
            // is kept (not cleared) either way — clearing it after locking is
            // what made a locked import unreachable in the first place, since
            // nothing else can re-select a locked element except tapping it.
            final allLocked = before.isNotEmpty && before.every((e) => e.isLocked);
            return IconButton(
              tooltip: allLocked ? 'Unlock' : 'Lock',
              icon: Icon(allLocked ? Icons.lock_open_outlined : Icons.lock_outline),
              onPressed: () {
                history.push(UpdateElementsCommand(
                  before: before,
                  after: [
                    for (final e in before)
                      SelectionEditing.withLocked(e, !allLocked)
                  ],
                ));
              },
            );
          }),
          const VerticalDivider(width: 12),
          IconButton(
            tooltip: 'Bring to front',
            icon: const Icon(Icons.flip_to_front),
            onPressed: () => history.push(ReplaceAllCommand(
                before: all, after: ZOrderService.bringToFront(all, ids))),
          ),
          IconButton(
            tooltip: 'Send to back',
            icon: const Icon(Icons.flip_to_back),
            onPressed: () => history.push(ReplaceAllCommand(
                before: all, after: ZOrderService.sendToBack(all, ids))),
          ),
          const VerticalDivider(width: 12),
          IconButton(
            tooltip: 'Align left',
            icon: const Icon(Icons.align_horizontal_left),
            onPressed: () => _align(ref, history, AlignEdge.left),
          ),
          IconButton(
            tooltip: 'Align centre',
            icon: const Icon(Icons.align_horizontal_center),
            onPressed: () => _align(ref, history, AlignEdge.centerH),
          ),
          IconButton(
            tooltip: 'Align top',
            icon: const Icon(Icons.align_vertical_top),
            onPressed: () => _align(ref, history, AlignEdge.top),
          ),
          IconButton(
            tooltip: 'Distribute horizontally',
            icon: const Icon(Icons.horizontal_distribute),
            onPressed: () {
              final before = _sel(ref);
              history.push(UpdateElementsCommand(
                before: before,
                after:
                    AlignmentService.distribute(before, SceneAxis.horizontal),
              ));
            },
          ),
        ],
      ),
    );
  }

  void _align(WidgetRef ref, HistoryController history, AlignEdge edge) {
    final before = _sel(ref);
    history.push(UpdateElementsCommand(
      before: before,
      after: AlignmentService.align(before, edge),
    ));
  }

  /// The single unlocked [TextElement] in the selection, or null when the
  /// selection is anything else.
  static TextElement? _editableText(
      Set<String> ids, List<SceneElement> all) {
    if (ids.length != 1) return null;
    final e = all.where((e) => e.id == ids.first).firstOrNull;
    return e is TextElement && !e.isLocked ? e : null;
  }

  /// Width of one extracted line drawn at [fontSize], in the same font a
  /// [TextElement] defaults to — so the size chosen for a line is the size it
  /// actually renders at, not an average-character guess.
  static double _measureExtractedLine(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// The single [ImageElement] in the selection that has a file behind it, or
  /// null when the selection is anything else. Locked is fine — a page-sized
  /// import is locked by default, and reading it changes nothing about it.
  static ImageElement? _singleImage(Set<String> ids, List<SceneElement> all) {
    if (ids.length != 1) return null;
    final e = all.where((e) => e.id == ids.first).firstOrNull;
    return e is ImageElement && e.relativeImagePath.isNotEmpty ? e : null;
  }

  /// Reads the text out of [im] and lays it over the picture as ordinary,
  /// editable text elements.
  ///
  /// Everything lands in one [AddElementsCommand], so a single undo takes the
  /// whole extraction back. The picture is deliberately left in place — OCR
  /// misreads are only checkable against the original, and a page's diagrams
  /// aren't text — with removing it offered as a follow-up for anyone who wants
  /// text alone.
  Future<void> _extractText(
      BuildContext context, WidgetRef ref, ImageElement im) async {
    final messenger = ScaffoldMessenger.of(context);
    final absolute = SceneImageCache.resolvePath(
        ref.read(sceneImageCacheProvider).baseDir, im.relativeImagePath);

    // The same app-wide recogniser the AI pipeline reads pages with, so an
    // image OCR'd for one is already cached for the other.
    final List<RecognizedLine> boxes;
    try {
      boxes =
          await ref.read(imageTextRecognitionServiceProvider).lines(absolute);
    } on TextExtractionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    // OCR is slow enough that the user can leave the page mid-run; `ref` must
    // not be touched once this widget is gone.
    if (!context.mounted) return;

    // The recogniser reports boxes in the source image's pixel space, so the
    // picture's own pixel size is what they map from — read from the decoded
    // bitmap, which the cache already holds to draw it.
    final bitmap = ref.read(sceneImageCacheProvider).get(im.relativeImagePath);
    if (bitmap == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('That picture is still loading — try again.')));
      return;
    }

    final placed = layOutOcrBoxes(
      boxes: boxes,
      sourcePixels:
          Size(bitmap.width.toDouble(), bitmap.height.toDouble()),
      target: ElementBounds.of(im),
      measureWidth: _measureExtractedLine,
    );
    if (placed.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No text found in that picture.')));
      return;
    }

    final scene = ref.read(sceneControllerProvider(pageKey).notifier);
    var z = scene.nextZOrder();
    final added = [
      for (final p in placed)
        TextElement(
          id: editorNewId(),
          zOrder: z++,
          geometryData: [
            p.bounds.left,
            p.bounds.top,
            p.bounds.right,
            p.bounds.bottom
          ],
          text: p.text,
          color: 0xFF1A1A1A,
          fontSize: p.fontSize,
        ),
    ];
    ref.read(historyProvider(pageKey).notifier).push(AddElementsCommand(added));

    messenger.showSnackBar(SnackBar(
      content: Text('Extracted ${added.length} line'
          '${added.length == 1 ? '' : 's'} of text'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Remove picture',
        onPressed: () => ref
            .read(historyProvider(pageKey).notifier)
            .push(RemoveElementsCommand([im])),
      ),
    ));
  }

  /// Rewrites [t]'s words in place, keeping everything else about it — position,
  /// width, colour, font — exactly as the user left it.
  ///
  /// Only the height is recomputed, from the paragraph the painter will actually
  /// draw: text is wrapped to the element's width but never clipped vertically,
  /// so replacing a line with a paragraph would otherwise leave the bounds
  /// reporting a box far smaller than the visible text — which is what
  /// selection, hit-testing and AI note placement all read.
  Future<void> _editText(
      BuildContext context, WidgetRef ref, TextElement t) async {
    final text = await showSceneTextDialog(
      context,
      initial: t.text,
      title: 'Edit text',
      confirmLabel: 'Save',
    );
    // Null is cancel. Empty is a deliberate clear, but an empty text element is
    // invisible and unselectable — a trap — so treat it as "delete the text"
    // being unavailable here and leave the element alone.
    if (text == null || text.trim().isEmpty || text == t.text) return;

    final rect = ElementBounds.of(t);
    final updated = t.copyWith(text: text.trim());
    final height = SceneElementPainter.layOutText(updated, rect.width).height;
    if (!context.mounted) return;

    ref.read(historyProvider(pageKey).notifier).push(UpdateElementsCommand(
          before: [t],
          after: [
            updated.copyWith(geometryData: [
              rect.left,
              rect.top,
              rect.right,
              rect.top + math.max(height, t.fontSize),
            ]),
          ],
        ));
  }

  Future<void> _saveToLibrary(BuildContext context, WidgetRef ref) async {
    final selected = _sel(ref);
    if (selected.isEmpty) return;
    final name = await _promptName(context);
    if (name == null) return;
    await ref
        .read(libraryProvider.notifier)
        .addFromElements(name, selected, id: editorNewId());
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved "$name" to library')));
    }
  }

  Future<String?> _promptName(BuildContext context) {
    final controller = TextEditingController();
    String? clean(String v) => v.trim().isEmpty ? null : v.trim();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to library'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Item name'),
          onSubmitted: (v) => Navigator.of(context).pop(clean(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(clean(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
  }
}
