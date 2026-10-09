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

  void _loadRecordings() => Future.microtask(() => ref
      .read(recordingNotifierProvider(widget.notebookId).notifier)
      .loadForPage(widget.pageId));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingNotifierProvider(widget.notebookId));
    final notifier =
        ref.read(recordingNotifierProvider(widget.notebookId).notifier);

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
          previous: previous, next: next, onPage: state.onPage)) {
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
          icon: Icon(
            state.isRecording
                ? Icons.stop_circle
                : PhosphorIconsRegular.microphone,
            color: state.isRecording ? context.ink.accentRed : null,
          ),
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

  void _toastTranscript(String message) => ScaffoldMessenger.of(context)
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
