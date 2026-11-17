// The selection action bar — shown above the toolbar whenever one or more
// elements are selected (delete, duplicate, copy, edit/extract text, save to
// library, group/lock, reorder, align/distribute).

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../domain/commands/scene_command.dart';
import '../../../../domain/geometry/element_bounds.dart';
import '../../../../domain/model/checklist_text.dart';
import '../../../../domain/model/scene_element.dart';
import '../../../../domain/services/alignment_service.dart';
import '../../../../domain/services/selection_editing.dart';
import '../../../../domain/services/z_order_service.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../ai/data/handwriting/handwriting_recognition_service.dart';
import '../../../ai/data/ocr/image_text_recognition_service.dart';
import '../../domain/handwriting_conversion.dart';
import 'handwriting_convert_sheet.dart';
import 'link_picker_sheet.dart';
import 'selection_actions.dart';
import '../../domain/solve.dart';
import '../../../ai/domain/recognition_result.dart' show RecognizedInkLine;
import '../../../ai/presentation/ai_providers.dart';
import '../../../audio/presentation/recording_notifier.dart';
import '../../../../editor/import/ocr_layout.dart';
import '../../../../editor/render/scene_element_painter.dart';
import '../../../../editor/render/scene_exporter.dart';
import '../../../../editor/ui/custom_color_dialog.dart';
import '../../../../editor/render/scene_image_cache.dart';
import '../../../../editor/state/clipboard_service.dart';
import '../../../../editor/state/history_controller.dart';
import '../../../../editor/state/library_controller.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../../../editor/state/scene_image_cache_provider.dart';
import '../../../../editor/state/selection_controller.dart';
import '../../../../editor/state/inline_text_request.dart';
import '../../../../editor/ui/controls/editor_controls_shared.dart';
import '../../../../editor/ui/controls/save_to_library_dialog.dart';

/// Line widths offered by the selection bar's Thickness menu, in scene units.
const List<(String, double)> kThicknessChoices = [
  ('Fine', 1.0),
  ('Thin', 2.0),
  ('Medium', 4.0),
  ('Thick', 8.0),
  ('Very thick', 14.0),
];

class SelectionBar extends ConsumerWidget {
  final ScenePageKey pageKey;

  /// Follows a link the selection shares; null hides "Open link".
  final void Function(String link)? onOpenLink;

  const SelectionBar({super.key, required this.pageKey, this.onOpenLink});

  List<SceneElement> _sel(WidgetRef ref) => editorSelection(ref, pageKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.read(historyProvider(pageKey).notifier);
    final sel = ref.read(selectionProvider.notifier);
    // Watched, not read: the z-order buttons and the text toggles below
    // snapshot `all`, and a stale one would revert edits made since the last
    // rebuild.
    final ids = ref.watch(selectionProvider);
    final all = ref.watch(sceneControllerProvider(pageKey));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Things the selection says to do: open, email, call, map, plan.
          SelectionActionChips(
            pageKey: pageKey,
            selectedIds: ids,
            onOpenLink: onOpenLink,
          ),
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
              // Stacked on top, in the originals' order, like paste.
              final base = ref
                  .read(sceneControllerProvider(pageKey).notifier)
                  .nextZOrder();
              final dupes = SelectionEditing.duplicate(
                _sel(ref),
                offset: const Offset(16, 16),
                nextId: editorNewId,
              )..sort((a, b) => a.zOrder.compareTo(b.zOrder));
              final copies = [
                for (int i = 0; i < dupes.length; i++)
                  ZOrderService.withZOrder(dupes[i], base + i),
              ];
              history.push(AddElementsCommand(copies));
              sel.selectMany(copies.map((e) => e.id));
            },
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.content_copy),
            onPressed: () => ClipboardService.copy(_sel(ref)),
          ),
          IconButton(
            key: const ValueKey('copyAsImage'),
            tooltip: 'Copy as image',
            icon: const Icon(Icons.image_outlined),
            onPressed: () => _copyAsImage(context, ref),
          ),
          // Colour and thickness of what is selected: ink, shapes and text.
          if (_sel(ref).any(SelectionEditing.hasColor))
            IconButton(
              key: const ValueKey('recolourSelection'),
              tooltip: 'Colour',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => _recolour(context, ref),
            ),
          if (_sel(ref).any(SelectionEditing.hasThickness))
            PopupMenuButton<double>(
              key: const ValueKey('thicknessSelection'),
              tooltip: 'Thickness',
              icon: const Icon(Icons.line_weight),
              onSelected: (w) => _setThickness(ref, w),
              itemBuilder: (_) => [
                for (final (label, w) in kThicknessChoices)
                  PopupMenuItem<double>(value: w, child: Text(label)),
              ],
            ),
          // Only offered for a single text element: editing is inherently about
          // one element's words, and a locked one is not up for changing.
          if (_editableText(ids, all) case final TextElement t)
            IconButton(
              tooltip: 'Edit text',
              icon: const Icon(Icons.edit_outlined),
              // Opens the text for typing on the page itself.
              onPressed: () => ref
                  .read(inlineTextEditRequestProvider(pageKey).notifier)
                  .state = t.id,
            ),
          // Formatting applies to every unlocked text element in the selection,
          // so it still works when text is selected alongside other elements.
          if (_editableTexts(ids, all) case final texts when texts.isNotEmpty)
            ..._textFormatControls(ref, texts),
          // A stroke drawn while a lecture was recording can replay that moment.
          if (_recordedStroke(ids, all) case final FreehandElement stroke)
            IconButton(
              tooltip: 'Play from here',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () => ref
                  .read(recordingNotifierProvider(pageKey.notebookId).notifier)
                  .playFromStroke(
                    recordingId: stroke.recordingId,
                    audioOffsetMs: stroke.audioOffsetMs,
                  ),
            ),
          // Revision tape: lift it all to peek, or lay it all back down. A
          // mix lifts first, like the lock button resolves a mix.
          if (_sel(ref).whereType<TapeElement>().toList() case final tapes
              when tapes.isNotEmpty)
            Builder(builder: (context) {
              final allLifted = tapes.every((t) => t.revealed);
              return IconButton(
                key: const ValueKey('peekTape'),
                tooltip: allLifted ? 'Cover' : 'Peek',
                icon: Icon(allLifted
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                // Peeking is reading, not editing: remembered, not undone.
                onPressed: () => ref
                    .read(sceneControllerProvider(pageKey).notifier)
                    .updateMany([
                  for (final t in tapes) t.copyWith(revealed: !allLifted)
                ]),
              );
            }),
          // Handwriting: typed text where it was written, or levelled.
          if (_ink(ref).isNotEmpty) ...[
            IconButton(
              key: const ValueKey('convertHandwriting'),
              tooltip: 'Convert to text',
              icon: const Icon(Icons.text_fields),
              onPressed: () => _convertHandwriting(context, ref),
            ),
            IconButton(
              key: const ValueKey('solveHandwriting'),
              tooltip: 'Solve',
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () => _solve(context, ref),
            ),
            IconButton(
              key: const ValueKey('levelHandwriting'),
              tooltip: 'Straighten handwriting',
              icon: const Icon(Icons.straighten),
              onPressed: () => _levelHandwriting(context, ref),
            ),
          ],
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
          // Everything selected links to the same place: go there.
          if ((onOpenLink, _sel(ref).map((e) => e.link).toSet())
              case (final open?, final links)
              when links.length == 1 && links.single.isNotEmpty)
            IconButton(
              tooltip: 'Open link',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => open(links.single),
            ),
          // Links the selection to another page or notebook; tapping it with
          // the hand tool then goes there (see PdfLinkLayer).
          IconButton(
            tooltip: 'Link',
            icon: const Icon(Icons.link),
            onPressed: () async {
              final before = _sel(ref);
              if (before.isEmpty) return;
              final link = await showLinkPicker(
                context,
                currentNotebookId: pageKey.notebookId,
                currentPageId: pageKey.pageId,
                hasLink: before.any((e) => e.link.isNotEmpty),
              );
              if (link == null) return;
              history.push(UpdateElementsCommand(
                before: before,
                after: [for (final e in before) SelectionEditing.withLink(e, link)],
              ));
            },
          ),
          IconButton(
            tooltip: 'Group',
            icon: const Icon(Icons.join_full),
            onPressed: () {
              final before = _sel(ref);
              if (before.length < 2) return;
              final gid = editorNewId();
              history.push(
                UpdateElementsCommand(
                  before: before,
                  after: [
                    for (final e in before) SelectionEditing.withGroup(e, gid),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ungroup',
            icon: const Icon(Icons.join_inner),
            onPressed: () {
              final before = _sel(ref);
              if (before.every((e) => e.groupId.isEmpty)) return;
              history.push(
                UpdateElementsCommand(
                  before: before,
                  after: [
                    for (final e in before) SelectionEditing.withGroup(e, ''),
                  ],
                ),
              );
            },
          ),
          Builder(
            builder: (context) {
              final before = _sel(ref);
              // If everything selected is already locked, this un-locks; any
              // unlocked element in the mix locks the whole selection. Selection
              // is kept (not cleared) either way — clearing it after locking is
              // what made a locked import unreachable in the first place, since
              // nothing else can re-select a locked element except tapping it.
              final allLocked =
                  before.isNotEmpty && before.every((e) => e.isLocked);
              // A locked import (a PDF page) says what is wrong and how to
              // fix it, rather than hiding the way out behind an icon.
              if (allLocked) {
                return TextButton.icon(
                  key: const ValueKey('unlockSelection'),
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Unlock to move'),
                  onPressed: () => history.push(
                    UpdateElementsCommand(
                      before: before,
                      after: [
                        for (final e in before)
                          SelectionEditing.withLocked(e, false),
                      ],
                    ),
                  ),
                );
              }
              return IconButton(
                tooltip: allLocked ? 'Unlock' : 'Lock',
                icon: Icon(
                  allLocked ? Icons.lock_open_outlined : Icons.lock_outline,
                ),
                onPressed: () {
                  if (before.isEmpty) return;
                  history.push(
                    UpdateElementsCommand(
                      before: before,
                      after: [
                        for (final e in before)
                          SelectionEditing.withLocked(e, !allLocked),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const VerticalDivider(width: 12),
          IconButton(
            tooltip: 'Bring to front',
            icon: const Icon(Icons.flip_to_front),
            onPressed: () => history.push(
              ReplaceAllCommand(
                before: all,
                after: ZOrderService.bringToFront(all, ids),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send to back',
            icon: const Icon(Icons.flip_to_back),
            onPressed: () => history.push(
              ReplaceAllCommand(
                before: all,
                after: ZOrderService.sendToBack(all, ids),
              ),
            ),
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
              _pushMoved(
                history,
                before,
                AlignmentService.distribute(before, SceneAxis.horizontal),
              );
            },
          ),
        ],
      ),
    );
  }

  void _align(WidgetRef ref, HistoryController history, AlignEdge edge) {
    final before = _sel(ref);
    _pushMoved(history, before, AlignmentService.align(before, edge));
  }

  /// Pushes one undo step for [moved] (the elements an align/distribute
  /// actually changed); nothing when it changed nothing.
  void _pushMoved(
    HistoryController history,
    List<SceneElement> selected,
    List<SceneElement> moved,
  ) {
    if (moved.isEmpty) return;
    final ids = {for (final e in moved) e.id};
    history.push(
      UpdateElementsCommand(
        before: [
          for (final e in selected)
            if (ids.contains(e.id)) e,
        ],
        after: moved,
      ),
    );
  }

  /// The single unlocked [TextElement] in the selection, or null when the
  /// selection is anything else.
  static TextElement? _editableText(Set<String> ids, List<SceneElement> all) {
    if (ids.length != 1) return null;
    final e = all.where((e) => e.id == ids.first).firstOrNull;
    return e is TextElement && !e.isLocked ? e : null;
  }

  /// Every unlocked text element in the selection, in scene order. Locked text
  /// is excluded for the same reason it can't be edited — a locked element is
  /// not up for changing.
  static List<TextElement> _editableTexts(
    Set<String> ids,
    List<SceneElement> all,
  ) {
    return [
      for (final e in all)
        if (ids.contains(e.id) && e is TextElement && !e.isLocked) e,
    ];
  }

  /// Re-measures [t] and updates its bottom edge.
  ///
  /// Bold and italic change the laid-out height (bold is wider, so it wraps
  /// sooner), and a box that no longer matches the glyphs is what selection,
  /// hit-testing and AI note placement all read — the same reason changing the
  /// words re-measures.
  static TextElement _refit(TextElement t) {
    final rect = ElementBounds.of(t);
    final height = SceneElementPainter.layOutText(t, rect.width).height;
    return t.copyWith(
      geometryData: [
        rect.left,
        rect.top,
        rect.right,
        rect.top + math.max(height, t.fontSize),
      ],
    );
  }

  /// Bold / italic / alignment. One [UpdateElementsCommand] per press, so a
  /// single undo reverts the whole selection rather than one element at a time.
  List<Widget> _textFormatControls(WidgetRef ref, List<TextElement> texts) {
    void apply(TextElement Function(TextElement) change) {
      ref
          .read(historyProvider(pageKey).notifier)
          .push(
            UpdateElementsCommand(
              before: texts,
              after: [for (final t in texts) _refit(change(t))],
            ),
          );
    }

    // A mixed selection turns the attribute ON for everything first; pressing
    // again then clears it. Matches how the lock button resolves a mix.
    final makeBold = texts.any((t) => !t.isBold);
    final makeItalic = texts.any((t) => !t.isItalic);
    final commonAlign = texts.map((t) => t.align).toSet().singleOrNull;

    return [
      IconButton(
        tooltip: makeBold ? 'Bold' : 'Remove bold',
        isSelected: !makeBold,
        icon: const Icon(Icons.format_bold),
        onPressed: () => apply((t) => t.copyWith(isBold: makeBold)),
      ),
      IconButton(
        tooltip: makeItalic ? 'Italic' : 'Remove italic',
        isSelected: !makeItalic,
        icon: const Icon(Icons.format_italic),
        onPressed: () => apply((t) => t.copyWith(isItalic: makeItalic)),
      ),
      // Checklists are a text convention, so this converts in place rather
      // than making a different kind of element.
      IconButton(
        tooltip: texts.every((t) => ChecklistText.isChecklist(t.text))
            ? 'Remove checklist'
            : 'Make checklist',
        isSelected: texts.every((t) => ChecklistText.isChecklist(t.text)),
        icon: const Icon(Icons.checklist),
        onPressed: () {
          final makeList = texts.any((t) => !ChecklistText.isChecklist(t.text));
          apply(
            (t) => t.copyWith(
              text: makeList
                  ? ChecklistText.toChecklist(t.text)
                  : ChecklistText.fromChecklist(t.text),
            ),
          );
        },
      ),
      PopupMenuButton<TextAlignKind>(
        tooltip: 'Align text',
        icon: Icon(_alignIcon(commonAlign)),
        onSelected: (a) => apply((t) => t.copyWith(align: a)),
        itemBuilder: (_) => [
          for (final a in TextAlignKind.values)
            PopupMenuItem(
              value: a,
              child: Row(
                children: [
                  Icon(_alignIcon(a)),
                  const SizedBox(width: 12),
                  Text(_alignLabel(a)),
                  if (a == commonAlign) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            ),
        ],
      ),
    ];
  }

  /// Null [a] means the selection mixes alignments — show the neutral default
  /// rather than implying one of them applies to everything.
  static IconData _alignIcon(TextAlignKind? a) => switch (a) {
    TextAlignKind.center => Icons.format_align_center,
    TextAlignKind.right => Icons.format_align_right,
    TextAlignKind.left || null => Icons.format_align_left,
  };

  static String _alignLabel(TextAlignKind a) => switch (a) {
    TextAlignKind.left => 'Left',
    TextAlignKind.center => 'Center',
    TextAlignKind.right => 'Right',
  };

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
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// A single selected stroke that was drawn during a recording, or null.
  static FreehandElement? _recordedStroke(
    Set<String> ids,
    List<SceneElement> all,
  ) {
    if (ids.length != 1) return null;
    final e = all.where((e) => e.id == ids.first).firstOrNull;
    return e is FreehandElement && e.hasAudio ? e : null;
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
    BuildContext context,
    WidgetRef ref,
    ImageElement im,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final absolute = SceneImageCache.resolvePath(
      ref.read(sceneImageCacheProvider).baseDir,
      im.relativeImagePath,
    );

    // The same app-wide recogniser the AI pipeline reads pages with, so an
    // image OCR'd for one is already cached for the other.
    final List<RecognizedLine> boxes;
    try {
      boxes = await ref
          .read(imageTextRecognitionServiceProvider)
          .lines(absolute);
    } on TextExtractionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    // OCR is slow enough that the user can leave the page mid-run; `ref` must
    // not be touched once this widget is gone.
    if (!context.mounted) return;

    // The recogniser reports boxes in the picture's own pixels, so those are what
    // they map from. Read from the file's header: the decoded bitmap may be
    // smaller than the picture (see SceneImageCache.decodeSize).
    final source = await SceneImageCache.naturalSize(absolute);
    if (!context.mounted) return;
    if (source == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("That picture couldn't be read.")),
      );
      return;
    }

    final placed = layOutOcrBoxes(
      boxes: boxes,
      sourcePixels: source,
      target: ElementBounds.of(im),
      measureWidth: _measureExtractedLine,
    );
    if (placed.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No text found in that picture.')),
      );
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
            p.bounds.bottom,
          ],
          text: p.text,
          color: 0xFF1A1A1A,
          fontSize: p.fontSize,
        ),
    ];
    final history = ref.read(historyProvider(pageKey).notifier);
    history.push(AddElementsCommand(added));

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Extracted ${added.length} line'
          '${added.length == 1 ? '' : 's'} of text',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Remove picture',
          // `history` is captured above: `ref` may be dead by the time this
          // fires (the bar unmounts when the selection changes).
          onPressed: () => history.push(RemoveElementsCommand([im])),
        ),
      ),
    );
  }

  /// Rewrites [t]'s words in place, keeping everything else about it — position,
  /// width, colour, font — exactly as the user left it.
  ///
  /// Only the height is recomputed, from the paragraph the painter will actually
  /// draw: text is wrapped to the element's width but never clipped vertically,
  /// so replacing a line with a paragraph would otherwise leave the bounds
  /// reporting a box far smaller than the visible text — which is what
  /// selection, hit-testing and AI note placement all read.
  /// The handwriting in the selection (eraser strokes are not writing).
  List<FreehandElement> _ink(WidgetRef ref) => [
        for (final e in _sel(ref))
          if (e is FreehandElement && !e.isEraser) e
      ];

  /// Reads the selected handwriting line by line (ML Kit, on the device),
  /// shows it for checking, then puts a text box where each line was: one
  /// undo step.
  Future<void> _convertHandwriting(BuildContext context, WidgetRef ref) async {
    final ink = _ink(ref);
    if (ink.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final language = ref.read(settingsProvider).recognitionLanguage;
    final List<ConversionLine> lines;
    try {
      await recognition.ensureModelDownloaded(language);
      lines = conversionLines(
          await recognition.recognizeInkLines(ink, language), ink);
    } on RecognitionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!context.mounted) return;
    if (lines.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No handwriting to read here.')));
      return;
    }
    final choice = await showHandwritingConvertSheet(context, lines);
    if (choice == null || !context.mounted) return;

    final scene = ref.read(sceneControllerProvider(pageKey).notifier);
    final result = convertLines(lines, choice.texts,
        keepInk: choice.keepInk,
        newId: editorNewId,
        firstZOrder: scene.nextZOrder());
    if (result.added.isEmpty) return;
    ref.read(historyProvider(pageKey).notifier).push(result.removed.isEmpty
        ? AddElementsCommand(result.added)
        : ReplaceElementsCommand(
            removed: result.removed, added: result.added));
    ref
        .read(selectionProvider.notifier)
        .selectMany(result.added.map((t) => t.id));
  }

  /// Reads the selected handwriting as a sum, works it out with the tutor's
  /// calculator, and writes "= answer" just after it: one undo step.
  Future<void> _solve(BuildContext context, WidgetRef ref) async {
    final ink = _ink(ref);
    if (ink.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final language = ref.read(settingsProvider).recognitionLanguage;
    final List<RecognizedInkLine> lines;
    try {
      await recognition.ensureModelDownloaded(language);
      lines = [
        for (final l in await recognition.recognizeInkLines(ink, language))
          if (l.text.trim().isNotEmpty) l,
      ];
    } on RecognitionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!context.mounted) return;
    final outcome = lines.isEmpty
        ? const NoSum()
        : await solveWritten(lines.map((l) => l.text).join(' '));
    if (!context.mounted) return;
    switch (outcome) {
      case NoSum():
        messenger.showSnackBar(const SnackBar(
            content: Text('No sum found in the selected handwriting.')));
      case OutOfRange():
        messenger.showSnackBar(const SnackBar(
            content: Text("That can't be worked out (out of range).")));
      case Solved(:final answer):
        final last = lines.last.bounds;
        final scene = ref.read(sceneControllerProvider(pageKey).notifier);
        final probe = TextElement(
          id: editorNewId(),
          zOrder: scene.nextZOrder(),
          geometryData: [last.right, last.top, last.right, last.bottom],
          text: '= $answer',
          color: ink.last.color,
          fontSize: fontSizeForLine(last.height),
        );
        final width =
            SceneElementPainter.layOutText(probe, double.infinity)
                    .maxIntrinsicWidth +
                4;
        final left = last.right + last.height * 0.3;
        final answerBox = probe.copyWith(geometryData: [
          left,
          last.top,
          left + width,
          last.top + SceneElementPainter.layOutText(probe, width).height,
        ]);
        ref
            .read(historyProvider(pageKey).notifier)
            .push(AddElementsCommand([answerBox]));
    }
  }

  /// Turns each slanted line of the selected handwriting level: one undo step.
  void _levelHandwriting(BuildContext context, WidgetRef ref) {
    final ink = _ink(ref);
    final levelled = levelHandwriting(ink);
    if (levelled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This writing is already level.')));
      return;
    }
    final ids = {for (final e in levelled) e.id};
    ref.read(historyProvider(pageKey).notifier).push(UpdateElementsCommand(
        before: [for (final e in ink) if (ids.contains(e.id)) e],
        after: levelled));
  }

  /// Opens the colour picker and recolours every ink, shape and text in the
  /// selection: one undo step.
  Future<void> _recolour(BuildContext context, WidgetRef ref) async {
    final targets = _sel(ref).where(SelectionEditing.hasColor).toList();
    if (targets.isEmpty) return;
    final start = switch (targets.first) {
      FreehandElement(:final color) => color,
      SceneShapeElement(:final color) => color,
      TextElement(:final color) => color,
      _ => 0xFF000000,
    };
    final picked = await showCustomColorDialog(context, start);
    if (picked == null || !context.mounted) return;
    ref.read(historyProvider(pageKey).notifier).push(UpdateElementsCommand(
        before: targets,
        after: [for (final e in targets) SelectionEditing.withColor(e, picked)]));
  }

  /// Gives every ink and shape in the selection the line width [width]: one
  /// undo step. Text and images are left as they are.
  void _setThickness(WidgetRef ref, double width) {
    final targets = _sel(ref).where(SelectionEditing.hasThickness).toList();
    if (targets.isEmpty) return;
    ref.read(historyProvider(pageKey).notifier).push(UpdateElementsCommand(
        before: targets,
        after: [
          for (final e in targets) SelectionEditing.withThickness(e, width)
        ]));
  }

  /// Renders the selection to a PNG and hands it to the share sheet, whose
  /// Copy, Save and Send actions put it wherever it is wanted. (Flutter's
  /// clipboard carries text only, and a plugin for image clipboards would be a
  /// new dependency.)
  Future<void> _copyAsImage(BuildContext context, WidgetRef ref) async {
    final selected = _sel(ref);
    if (selected.isEmpty) return;
    final cache = ref.read(sceneImageCacheProvider);
    final png = await SceneExporter.toPng(selected,
        imageResolver: cache.get, background: Colors.transparent);
    if (png == null || !context.mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/margo_selection.png');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
    ));
  }

  Future<void> _saveToLibrary(BuildContext context, WidgetRef ref) async {
    final selected = _sel(ref);
    if (selected.isEmpty) return;
    final name = await showSaveToLibraryDialog(context);
    // The dialog can outlive this widget; `ref` must not be read once it has.
    if (name == null || !context.mounted) return;
    await ref
        .read(libraryProvider.notifier)
        .addFromElements(name, selected, id: editorNewId());
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved "$name" to library')));
    }
  }
}
