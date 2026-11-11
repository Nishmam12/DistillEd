part of 'notebook_editor_screen.dart';

/// Bottom sheet to pick the page template and paper colour. Selections apply
/// live (the parent persists them and rebuilds the canvas) so the sheet can
/// stay open while the user tries combinations.
class _BackgroundSheet extends StatefulWidget {
  final TemplateType template;
  final Color paperColor;
  final bool pageMode;
  final ValueChanged<TemplateType> onTemplate;
  final ValueChanged<Color> onColor;
  final ValueChanged<bool> onPageMode;

  const _BackgroundSheet({
    required this.template,
    required this.paperColor,
    required this.pageMode,
    required this.onTemplate,
    required this.onColor,
    required this.onPageMode,
  });

  @override
  State<_BackgroundSheet> createState() => _BackgroundSheetState();
}

class _BackgroundSheetState extends State<_BackgroundSheet> {
  static const _papers = <Color>[
    PaperColors.paperWhite,
    PaperColors.paperCream,
    PaperColors.paperBlush,
  ];

  late TemplateType _template = widget.template;
  late Color _color = widget.paperColor;
  late bool _pageMode = widget.pageMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Layout', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.all_out),
                  label: Text('Infinite'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.insert_drive_file_outlined),
                  label: Text('Single page'),
                ),
              ],
              selected: {_pageMode},
              onSelectionChanged: (s) {
                setState(() => _pageMode = s.first);
                widget.onPageMode(s.first);
              },
            ),
            const SizedBox(height: 20),
            Text('Paper template', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in TemplateType.values)
                  ChoiceChip(
                    avatar: Icon(t.iconData, size: 18),
                    label: Text(t.displayName),
                    selected: _template == t,
                    onSelected: (_) {
                      setState(() => _template = t);
                      widget.onTemplate(t);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Paper color', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final c in _papers)
                  GestureDetector(
                    onTap: () {
                      setState(() => _color = c);
                      widget.onColor(c);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color.toARGB32() == c.toARGB32()
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          width: _color.toARGB32() == c.toARGB32() ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Start/stop lecture recording. Red and pulsing while live, so it is never
/// ambiguous whether the microphone is on.
class _RecordButton extends ConsumerStatefulWidget {
  final int notebookId;
  final int pageId;

  const _RecordButton({required this.notebookId, required this.pageId});

  @override
  ConsumerState<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<_RecordButton> {
  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void didUpdateWidget(_RecordButton old) {
    super.didUpdateWidget(old);
    // Another page: its recordings are the ones to offer a transcript for.
    if (old.pageId != widget.pageId) _loadRecordings();
  }

  void _loadRecordings() => Future.microtask(
    () => ref
        .read(recordingNotifierProvider(widget.notebookId).notifier)
        .loadForPage(widget.pageId),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingNotifierProvider(widget.notebookId));
    final notifier = ref.read(
      recordingNotifierProvider(widget.notebookId).notifier,
    );

    // Surface a failure once, then clear it — a permission refusal should say
    // so rather than leaving a button that silently does nothing.
    ref.listen(recordingNotifierProvider(widget.notebookId), (_, next) {
      final error = next.error;
      if (error == null || !mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      notifier.clearError();
    });

    // Say when a lecture on this page has been transcribed, or could not be.
    ref.listen(lectureTranscriptionProvider, (previous, next) {
      if (!mounted) return;
      for (final notice in transcriptionNotices(
        previous: previous,
        next: next,
        onPage: state.onPage,
      )) {
        _toastTranscript(notice);
      }
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.onPage.isNotEmpty)
          IconButton(
            tooltip: 'Lecture transcripts',
            icon: const Icon(Icons.subtitles_outlined),
            onPressed: () => showLectureTranscripts(
              context,
              notebookId: widget.notebookId,
              pageId: widget.pageId,
            ),
          ),
        IconButton(
          tooltip: state.isRecording ? 'Stop recording' : 'Record lecture',
          icon: state.isRecording
              ? Icon(
                  Icons.stop_circle,
                  color: Theme.of(context).colorScheme.error,
                )
              : const AppIcon(AppIcons.mic),
          onPressed: () async {
            if (state.isRecording) {
              unawaited(notifier.stop(widget.pageId));
              return;
            }
            // Asked first, so the transcript is made in the language the lecture
            // is in. Backing out records nothing.
            final language = await pickLectureLanguage(context);
            if (language == null || !mounted) return;
            unawaited(notifier.start(widget.pageId, language: language));
          },
        ),
      ],
    );
  }

  void _toastTranscript(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _PageNavBar extends StatelessWidget {
  final int index;
  final int count;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onAdd;
  final VoidCallback onManage;

  const _PageNavBar({
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
    required this.onAdd,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
            ),
            // Tapping the counter opens the same menu as the explicit button,
            // so the gesture is available without being the only affordance.
            InkWell(
              onTap: onManage,
              onLongPress: onManage,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('Page ${index + 1} / $count'),
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add page',
              icon: const Icon(Icons.add),
              onPressed: onAdd,
            ),
            IconButton(
              tooltip: 'Page options',
              icon: const Icon(Icons.more_vert),
              onPressed: onManage,
            ),
          ],
        ),
      ),
    );
  }
}

/// Floats over the canvas while just-added pictures are being positioned:
/// says how, and offers the three ways to finish.
class _PlacementBar extends StatelessWidget {
  final int count;
  final VoidCallback onDone;
  final VoidCallback onOwnPage;
  final VoidCallback onRemove;

  const _PlacementBar({
    required this.count,
    required this.onDone,
    required this.onOwnPage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final many = count > 1;
    return Material(
      key: const ValueKey('placementBar'),
      color: context.colors.surface,
      elevation: 3,
      shape: StadiumBorder(side: BorderSide(color: context.colors.border)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                many
                    ? 'Drag to move · corners to resize'
                    : 'Drag to move · corner to resize',
              ),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
            ),
            TextButton.icon(
              onPressed: onOwnPage,
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: Text(many ? 'Own pages' : 'Own page'),
            ),
            FilledButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the PDF import sheet returns: which pages (1-based, inclusive) and
/// where they go.
typedef PdfImportOptions = ({int first, int last, bool afterCurrent});

/// Asked after a PDF is picked: which pages to bring in, and whether they go
/// after the page the user is on or at the end of the notebook.
class PdfImportSheet extends StatefulWidget {
  final String fileName;
  final int pageCount;

  const PdfImportSheet({
    super.key,
    required this.fileName,
    required this.pageCount,
  });

  @override
  State<PdfImportSheet> createState() => _PdfImportSheetState();
}

class _PdfImportSheetState extends State<PdfImportSheet> {
  late RangeValues _range = RangeValues(1, widget.pageCount.toDouble());
  bool _afterCurrent = true;

  int get _first => _range.start.round();
  int get _last => _range.end.round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.pageCount;
    final chosen = _last - _first + 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$n page${n == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
            if (n > 1) ...[
              const SizedBox(height: 16),
              Text(
                _first == 1 && _last == n
                    ? 'All pages'
                    : 'Pages $_first–$_last',
              ),
              RangeSlider(
                min: 1,
                max: n.toDouble(),
                divisions: n - 1,
                values: _range,
                labels: RangeLabels('$_first', '$_last'),
                onChanged: (v) => setState(() => _range = v),
              ),
            ],
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('After this page')),
                ButtonSegment(value: false, label: Text('At the end')),
              ],
              selected: {_afterCurrent},
              onSelectionChanged: (v) =>
                  setState(() => _afterCurrent = v.first),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('pdfImportConfirm'),
                  onPressed: () => Navigator.of(context).pop<PdfImportOptions>((
                    first: _first,
                    last: _last,
                    afterCurrent: _afterCurrent,
                  )),
                  child: Text('Import $chosen page${chosen == 1 ? '' : 's'}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while a PDF's pages are being rendered: how far it has got, and a
/// way to stop.
class _ImportProgressDialog extends StatefulWidget {
  final ValueNotifier<(int, int)> progress;
  final VoidCallback onCancel;

  const _ImportProgressDialog({required this.progress, required this.onCancel});

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  bool _stopping = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importing PDF'),
      content: ValueListenableBuilder<(int, int)>(
        valueListenable: widget.progress,
        builder: (_, value, _) {
          final (done, total) = value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: total == 0 ? null : done / total),
              const SizedBox(height: 12),
              Text(
                _stopping
                    ? 'Stopping…'
                    : 'Page ${done.clamp(0, total)} of $total',
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _stopping
              ? null
              : () {
                  setState(() => _stopping = true);
                  widget.onCancel();
                },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
