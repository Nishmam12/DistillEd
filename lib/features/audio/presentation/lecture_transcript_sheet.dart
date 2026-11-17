// The lectures recorded on a page, and what was said in them
// (docs/AI_PIPELINE_PLAN.md, item 14): each recording with its transcript as
// timestamped lines, any of which plays the lecture from that moment.
//
// A recording that has not been transcribed offers to be; one that is being
// shows its progress; one that failed says why. The transcripts themselves are
// also part of the page the AI reads (see `PageContent.lectureTranscript`) —
// this sheet is how a student sees and uses them directly.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/geometry/element_bounds.dart';
import '../../../editor/state/editor_tool_controller.dart';
import '../../../editor/state/scene_controller.dart';
import '../../../editor/state/selection_controller.dart';
import '../../../editor/state/viewport_controller.dart';
import '../../ai/presentation/sidebar/ai_sidebar.dart' show startPageFlashcards;

import '../../../core/theme/app_colors.dart';
import '../domain/lecture_recording.dart';
import '../domain/transcript.dart';
import 'lecture_transcription_notifier.dart';
import 'recording_notifier.dart';
import 'audio_providers.dart';
import 'transcription_providers.dart';

/// Opens the transcripts of the lectures recorded on [pageId].
Future<void> showLectureTranscripts(
  BuildContext context, {
  required int notebookId,
  required int pageId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: LectureTranscriptSheet(notebookId: notebookId, pageId: pageId),
      ),
    );

class LectureTranscriptSheet extends ConsumerStatefulWidget {
  final int notebookId;
  final int pageId;

  const LectureTranscriptSheet({
    super.key,
    required this.notebookId,
    required this.pageId,
  });

  @override
  ConsumerState<LectureTranscriptSheet> createState() =>
      _LectureTranscriptSheetState();
}

class _LectureTranscriptSheetState
    extends ConsumerState<LectureTranscriptSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref
        .read(recordingNotifierProvider(widget.notebookId).notifier)
        .loadForPage(widget.pageId));
  }

  @override
  Widget build(BuildContext context) {
    final recordings =
        ref.watch(recordingNotifierProvider(widget.notebookId)).onPage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text('Lecture transcripts',
            style: TextStyle(
              fontFamily: 'ModulusPro',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            )),
        const SizedBox(height: 12),
        if (recordings.isEmpty)
          Text('No lectures recorded on this page yet.',
              style: TextStyle(fontSize: 14, color: context.colors.textSecondary))
        else
          for (final recording in recordings)
            _RecordingSection(
              key: ValueKey(recording.id),
              notebookId: widget.notebookId,
              recording: recording,
            ),
      ],
    );
  }
}

class _RecordingSection extends ConsumerStatefulWidget {
  final int notebookId;
  final LectureRecording recording;

  const _RecordingSection({
    super.key,
    required this.notebookId,
    required this.recording,
  });

  @override
  ConsumerState<_RecordingSection> createState() => _RecordingSectionState();
}

class _RecordingSectionState extends ConsumerState<_RecordingSection> {
  Future<Transcript?>? _transcript;
  TranscriptionPhase? _loadedAtPhase;

  /// The saved transcript, read again only when the queue's phase for this
  /// recording changes (so a finished job shows up) — not on every progress tick.
  Future<Transcript?> _transcriptFor(TranscriptionPhase? phase) {
    if (_transcript == null || _loadedAtPhase != phase) {
      _loadedAtPhase = phase;
      _transcript = ref.read(transcriptStoreProvider).load(widget.recording);
    }
    return _transcript!;
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.recording;
    final status =
        ref.watch(lectureTranscriptionProvider.select((m) => m[recording.id]));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(formatLectureWhen(recording.startedAt),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  )),
              const Spacer(),
              Text(LectureRecording.formatOffset(recording.durationMs),
                  style:
                      TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          _body(context, recording, status),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, LectureRecording recording,
      TranscriptionStatus? status) {
    final colors = context.colors;
    TextStyle muted() => TextStyle(fontSize: 13, color: colors.textSecondary);

    if (!recording.isSpeechAudio) {
      return Text(
          'Recorded without transcripts, so there is nothing to transcribe.',
          style: muted());
    }

    switch (status?.phase) {
      case TranscriptionPhase.queued:
        return Text('Waiting to transcribe…', style: muted());
      case TranscriptionPhase.running:
        final percent = ((status!.progress) * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transcribing… $percent%', style: muted()),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: status.progress,
              minHeight: 6,
              color: colors.accent,
              backgroundColor: colors.surfaceSubtle,
            ),
          ],
        );
      case TranscriptionPhase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status!.message ?? "Couldn't transcribe this lecture.",
                style: muted()),
            TextButton(
              onPressed: () => ref
                  .read(lectureTranscriptionProvider.notifier)
                  .enqueue(recording),
              child: const Text('Try again'),
            ),
          ],
        );
      case TranscriptionPhase.done:
      case null:
        break;
    }

    return FutureBuilder<Transcript?>(
      future: _transcriptFor(status?.phase),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        final transcript = snapshot.data;
        if (transcript == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Not transcribed yet.', style: muted()),
              const SizedBox(height: 4),
              FilledButton.tonal(
                onPressed: () => ref
                    .read(lectureTranscriptionProvider.notifier)
                    .enqueue(recording),
                child: const Text('Transcribe'),
              ),
            ],
          );
        }
        if (transcript.isEmpty) {
          return Text('Nothing was said that could be transcribed.',
              style: muted());
        }
        return Column(
          children: [
            _LectureSummary(
                recording: recording, notebookId: widget.notebookId),
            for (final segment in transcript.segments)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _playLine(recording, segment),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                            '[${LectureRecording.formatOffset(segment.startMs)}]',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            )),
                      ),
                      Expanded(
                        child: Text(segment.text,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: colors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Plays the lecture from [segment] and, when ink was written while it was
  /// being said, closes the sheet and shows that ink: selected and in view.
  void _playLine(LectureRecording recording, TranscriptSegment segment) {
    unawaited(ref
        .read(recordingNotifierProvider(widget.notebookId).notifier)
        .playFromStroke(
            recordingId: recording.id, audioOffsetMs: segment.startMs));
    final key = (notebookId: widget.notebookId, pageId: recording.pageId);
    final elements = ref.read(sceneControllerProvider(key));
    final ids = inkDuring(elements,
        recordingId: recording.id,
        fromMs: segment.startMs,
        toMs: segment.endMs);
    if (ids.isEmpty) return;
    Navigator.of(context).pop();

    ref.read(editorToolProvider.notifier).useTool(EditorTool.select);
    ref.read(selectionProvider.notifier).selectMany(ids);
    final wanted = ids.toSet();
    final bounds = elements
        .where((e) => wanted.contains(e.id))
        .map(ElementBounds.of)
        .reduce((a, b) => a.expandToInclude(b));
    final viewport = ref.read(viewportProvider.notifier);
    final size = viewport.viewportSize;
    if (size.isEmpty) return;
    viewport.pan(size.center(Offset.zero) -
        ref.read(viewportProvider).toViewport(bounds.center));
  }
}

/// The study summary made after the lecture was transcribed (a summary of its
/// page, on the device), with "make flashcards". Nothing until there is one.
class _LectureSummary extends ConsumerStatefulWidget {
  final LectureRecording recording;
  final int notebookId;

  const _LectureSummary({required this.recording, required this.notebookId});

  @override
  ConsumerState<_LectureSummary> createState() => _LectureSummaryState();
}

class _LectureSummaryState extends ConsumerState<_LectureSummary> {
  late final Future<String?> _summary =
      ref.read(transcriptStoreProvider).loadSummary(widget.recording);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<String?>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.textSecondary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study summary',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary)),
              const SizedBox(height: 6),
              SelectableText(summary,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: colors.textPrimary)),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => startPageFlashcards(
                  context,
                  ref,
                  (notebookId: widget.notebookId,
                      pageId: widget.recording.pageId),
                ),
                child: const Text('Make flashcards from this lecture'),
              ),
            ],
          ),
        );
      },
    );
  }
}
