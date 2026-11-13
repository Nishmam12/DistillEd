// "Figures on this page": what the AI understood of each chart, diagram and
// picture, shown so it can be checked and put right.
//
// A figure the AI misread used to be invisible: the wrong description sat in
// the index and quietly bent every answer that touched it. Each one is listed
// here with its picture, the reading, who read it and whether the reading
// could be confirmed, plus three ways to change it — read it again, ask the
// stronger model, or write what it shows yourself.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/persistence/page_text_store.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../domain/ai_exception.dart';
import '../../domain/figure.dart';
import '../../domain/figure_detail.dart';
import '../../domain/scene_graph_figure.dart';
import '../ai_providers.dart';
import '../page_figures.dart';
import '../widgets/math_text.dart';

class AiFiguresStrip extends ConsumerWidget {
  final ScenePageKey pageKey;
  const AiFiguresStrip({super.key, required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final figures = ref.watch(pageFiguresProvider(pageKey.pageId));
    if (figures.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text('FIGURES ON THIS PAGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: context.colors.textSecondary,
              )),
        ),
        for (var i = 0; i < figures.length; i++)
          _FigureCard(
            // A new reading of the same figure keeps its card (and picture).
            key: ValueKey('${figures[i].pinKey}|${figures[i].bounds}|$i'),
            pageKey: pageKey,
            figure: figures[i],
          ),
      ],
    );
  }
}

/// Who read a figure, in the student's terms.
@visibleForTesting
String figureReaderLabel(FigureDescription figure, {required String localModelId}) {
  if (figure.modelId == kSceneGraphModelId) return 'Read exactly';
  if (figure.modelId == kUserFigureModelId) return 'Your description';
  if (figure.modelId.isEmpty || figure.modelId == localModelId) {
    return 'Read on device';
  }
  return 'Read by cloud AI';
}

class _FigureCard extends ConsumerStatefulWidget {
  final ScenePageKey pageKey;
  final FigureDescription figure;
  const _FigureCard({super.key, required this.pageKey, required this.figure});

  @override
  ConsumerState<_FigureCard> createState() => _FigureCardState();
}

class _FigureCardState extends ConsumerState<_FigureCard> {
  late final Future<Uint8List?> _picture = ref
      .read(pageContentExtractorProvider)
      .figureImage(widget.pageKey.pageId, widget.figure);

  /// What is running ('Reading again…'), or null.
  String? _busy;

  /// Why the last action changed nothing, or null.
  String? _note;

  FigureDescription get _figure => widget.figure;
  int get _pageId => widget.pageKey.pageId;

  /// Shape-read figures are exact and have nothing to change; a figure with
  /// nowhere to keep a new reading cannot be changed.
  bool get _editable =>
      _figure.modelId != kSceneGraphModelId && _figure.pinKey.isNotEmpty;

  Future<void> _reread({required bool onCloud}) async {
    setState(() {
      _busy = onCloud ? 'Asking the cloud…' : 'Reading again…';
      _note = null;
    });
    String? note;
    try {
      final read = await ref
          .read(pageContentExtractorProvider)
          .rereadFigure(_pageId, _figure, onCloud: onCloud);
      if (read == null) {
        note = onCloud
            ? "The cloud couldn't read this one just now."
            : "Couldn't get a new reading. The old one is kept.";
      } else {
        _replace(read);
      }
    } on AiModelNotReadyException {
      note = 'The on-device model needs to be downloaded first.';
    } catch (_) {
      note = "Couldn't read this just now.";
    }
    if (mounted) {
      setState(() {
        _busy = null;
        _note = note;
      });
    }
  }

  Future<void> _fix() async {
    final edited = await showDialog<({String title, String summary})>(
      context: context,
      builder: (_) => _FixFigureDialog(figure: _figure),
    );
    if (edited == null || !mounted) return;
    final corrected = await ref
        .read(pageContentExtractorProvider)
        .correctFigure(_figure, title: edited.title, summary: edited.summary);
    _replace(corrected);
  }

  /// Shows [next] in place of this card's figure, then has the page's search
  /// index and answers pick it up.
  void _replace(FigureDescription next) {
    final figures = ref.read(pageFiguresProvider(_pageId).notifier);
    figures.state = [
      for (final f in figures.state) identical(f, _figure) || f == _figure ? next : f,
    ];
    unawaited(republishPageFigures(ref, widget.pageKey));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final f = _figure;
    final cloudOffered = _editable &&
        ref.watch(settingsProvider.select((s) => s.cloudAiEnabled)) &&
        ref.watch(figureAnalyzerProvider).hasCloud;
    final heading = f.title.trim().isNotEmpty
        ? f.title.trim()
        : f.kind == FigureKind.unknown
            ? 'Figure'
            : '${f.kind.name[0].toUpperCase()}${f.kind.name.substring(1)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(picture: _picture),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      f.summary.trim(),
                      style: TextStyle(
                          fontSize: 13, height: 1.35, color: colors.textPrimary),
                    ),
                    if (f.insight.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Shows: ${f.insight.trim()}',
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: colors.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (f.latex.isNotEmpty) ...[
            const SizedBox(height: 8),
            // One formula per line, drawn as maths; a line the renderer cannot
            // draw shows as its source (see MathText).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MathText(
                f.latex.split('\n').map((l) => '\$\$$l\$\$').join('\n'),
                style: TextStyle(fontSize: 15, color: colors.textPrimary),
              ),
            ),
          ],
          if (f.table != null) ...[
            const SizedBox(height: 8),
            _TableView(table: f.table!),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(figureReaderLabel(f,
                  localModelId:
                      ref.watch(localAiProvider).capabilities.modelId)),
              if (f.isUncertain)
                const _Badge('Not confirmed', warning: true)
              else if (f.grounding != null &&
                  f.modelId != kSceneGraphModelId)
                const _Badge('Labels match the page'),
            ],
          ),
          if (f.isUncertain) ...[
            const SizedBox(height: 6),
            Text(
              "The labels in this reading weren't found on the page, so it may "
              'be wrong. Read it again or fix it below.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
          if (_busy != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.accent),
              ),
              const SizedBox(width: 8),
              Text(_busy!,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            ]),
          ] else if (_editable) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                _Action('Re-read', Icons.refresh,
                    () => _reread(onCloud: false)),
                if (cloudOffered)
                  _Action('Ask the cloud', Icons.cloud_outlined,
                      () => _reread(onCloud: true)),
                _Action('Fix it', Icons.edit_outlined, _fix),
              ],
            ),
          ],
          if (_note != null) ...[
            const SizedBox(height: 4),
            Text(_note!,
                style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Makes a changed figure count everywhere: reads the page again (served from
/// what is already remembered, plus the replaced reading), saves its search
/// text and queues it for the Ask index. Failing is harmless — the next read
/// of the page does the same.
Future<void> republishPageFigures(WidgetRef ref, ScenePageKey key) async {
  try {
    final extractor = ref.read(pageContentExtractorProvider);
    final pageText = ref.read(pageTextStoreProvider);
    final index = ref.read(ragIndexSchedulerProvider);
    final figures = ref.read(pageFiguresProvider(key.pageId).notifier);
    final content = await extractor.extractPage(
      key.pageId,
      languageCode: ref.read(settingsProvider).recognitionLanguage,
      useVision: true,
    );
    await pageText.save(
      notebookId: key.notebookId,
      pageId: key.pageId,
      text: content.combinedText,
      indexText: content.combinedTextWithFigures,
    );
    index.schedule(
      notebookId: key.notebookId,
      pageId: key.pageId,
      text: content.combinedTextWithFigures,
    );
    if (figures.mounted) figures.state = content.figures;
  } catch (_) {
    // See above.
  }
}

class _Thumbnail extends StatelessWidget {
  final Future<Uint8List?> picture;
  const _Thumbnail({required this.picture});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 64,
        height: 64,
        color: Colors.white,
        child: FutureBuilder<Uint8List?>(
          future: picture,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return Icon(Icons.insert_chart_outlined,
                  color: context.colors.textSecondary);
            }
            return Image.memory(
              bytes,
              fit: BoxFit.contain,
              cacheWidth: 192,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Icon(Icons.insert_chart_outlined,
                  color: context.colors.textSecondary),
            );
          },
        ),
      ),
    );
  }
}

/// A read table, as a grid. Scrolls sideways rather than squeezing: the panel
/// is narrow and a squeezed table is unreadable.
class _TableView extends StatelessWidget {
  final FigureTable table;
  const _TableView({required this.table});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget cell(String text, {bool heading = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: heading ? FontWeight.w600 : FontWeight.w400,
                color: colors.textPrimary,
              )),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(
            color: colors.textSecondary.withValues(alpha: 0.3), width: 0.5),
        children: [
          TableRow(children: [
            for (final c in table.columns) cell(c, heading: true),
          ]),
          for (final row in table.rows)
            TableRow(children: [for (final c in row) cell(c)]),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool warning;
  const _Badge(this.text, {this.warning = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warning ? scheme.errorContainer : context.colors.accentMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: warning ? scheme.onErrorContainer : context.colors.accent,
          )),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Action(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.colors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontSize: 13),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _FixFigureDialog extends StatefulWidget {
  final FigureDescription figure;
  const _FixFigureDialog({required this.figure});

  @override
  State<_FixFigureDialog> createState() => _FixFigureDialogState();
}

class _FixFigureDialogState extends State<_FixFigureDialog> {
  late final _title = TextEditingController(text: widget.figure.title);
  late final _summary = TextEditingController(text: widget.figure.summary);

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What does this figure show?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your description replaces the AI\'s reading. Summaries, answers '
              'and quizzes will use it from now on.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _summary,
              decoration: const InputDecoration(labelText: 'What it shows'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 8,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _summary.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  (title: _title.text.trim(), summary: _summary.text.trim())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
