// The sidebar's "Ask your notes" surface: a query box, a grounded answer
// streamed from the local model, and the source passages it drew on (each
// tappable to jump to its page). Shown in place of the live context whenever the
// Ask state is active; a close returns to the Context Engine view.
//
// The sources are the trust surface — the whole feature promises the answer
// comes from the user's own notes, so a [1]/[2] citation in the text lines up
// with a numbered source card here, and a grounded "not found" shows no cards
// rather than an unsourced claim.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/embeddings/embedder_spec.dart';
import '../../data/llm/llm_model_spec.dart';
import '../../domain/rag/rag_retriever.dart';
import '../ai_providers.dart';
import '../ask_notes_notifier.dart';
import '../widgets/model_download_progress.dart';

class AiAskView extends ConsumerStatefulWidget {
  /// Hands an answer to the editor's text-insertion path ("insert as note").
  final ValueChanged<String> onInsertNote;

  /// The notebook whose notes are searched.
  final int notebookId;

  /// Jumps to a source passage's page. Optional: when the editor hasn't wired
  /// navigation, source cards still show but aren't tappable.
  final void Function(int pageId)? onJumpToSource;

  const AiAskView({
    super.key,
    required this.onInsertNote,
    required this.notebookId,
    this.onJumpToSource,
  });

  @override
  ConsumerState<AiAskView> createState() => _AiAskViewState();
}

class _AiAskViewState extends ConsumerState<AiAskView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus the box the moment the Ask surface opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    ref
        .read(askNotesNotifierProvider.notifier)
        .ask(q, notebookId: widget.notebookId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(askNotesNotifierProvider);
    final busy = state is AskNotesSearching ||
        state is AskNotesAnswering ||
        state is AskNotesDownloadingModel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context),
        const SizedBox(height: 8),
        // The download view owns the whole surface; the query box would be
        // noise next to a progress bar.
        if (state is! AskNotesDownloadingModel) ...[
          _queryBox(enabled: !busy),
          const SizedBox(height: 12),
        ],
        Flexible(child: _body(state)),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.travel_explore, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Ask your notes',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
        ),
        IconButton(
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
          onPressed: () => ref.read(askNotesNotifierProvider.notifier).reset(),
        ),
      ],
    );
  }

  Widget _queryBox({required bool enabled}) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: enabled,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _submit(),
      minLines: 1,
      maxLines: 3,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'e.g. What did I write about mitosis?',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceHighlight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: 'Ask',
          icon: Icon(Icons.arrow_upward,
              size: 20,
              color: enabled ? AppColors.accent : AppColors.textMuted),
          onPressed: enabled ? _submit : null,
        ),
      ),
    );
  }

  Widget _body(AskNotesState state) {
    return switch (state) {
      AskNotesComposing() || AskNotesIdle() => const _Hint(),
      AskNotesSearching() => const _Centered(
          icon: Icons.travel_explore_outlined,
          title: 'Searching your notes…',
          showSpinner: true,
        ),
      AskNotesAnswering(:final text, :final sources) => _Answer(
          text: text,
          sources: sources,
          streaming: true,
          onInsertNote: widget.onInsertNote,
          onJumpToSource: widget.onJumpToSource,
        ),
      AskNotesAnswered(:final text, :final sources) => _Answer(
          text: text,
          sources: sources,
          streaming: false,
          onInsertNote: widget.onInsertNote,
          onJumpToSource: widget.onJumpToSource,
        ),
      AskNotesNotFound() => const _Centered(
          icon: Icons.search_off_outlined,
          title: "Not in your notes",
          subtitle:
              "I couldn't find anything about that in this notebook. Try "
              'rephrasing, or make sure the pages you mean are written and '
              'indexed.',
        ),
      AskNotesDownloadingModel(:final progress, :final isEmbedder) =>
        _Downloading(progress: progress, isEmbedder: isEmbedder),
      AskNotesError() => _ErrorBody(state: state),
    };
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      icon: Icons.lightbulb_outline,
      title: 'Ask a question about this notebook',
      subtitle: 'Answers are grounded in your own notes and cite the pages '
          'they come from. Everything runs on-device.',
    );
  }
}

/// The answer text plus its source cards.
class _Answer extends StatelessWidget {
  final String text;
  final List<RetrievedChunk> sources;
  final bool streaming;
  final ValueChanged<String> onInsertNote;
  final void Function(int pageId)? onJumpToSource;

  const _Answer({
    required this.text,
    required this.sources,
    required this.streaming,
    required this.onInsertNote,
    required this.onJumpToSource,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  trimmed.isEmpty ? 'Thinking…' : trimmed,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('SOURCES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      )),
                  const SizedBox(height: 8),
                  for (var i = 0; i < sources.length; i++)
                    _SourceCard(
                      index: i + 1,
                      pageId: sources[i].chunk.pageId,
                      text: sources[i].chunk.text,
                      onJumpToSource: onJumpToSource,
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _actions(context, trimmed),
      ],
    );
  }

  Widget _actions(BuildContext context, String trimmed) {
    return Row(
      children: [
        if (streaming)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accentSoft),
                ),
                SizedBox(width: 8),
                Text('Writing…',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          )
        else
          IconButton(
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
            onPressed: trimmed.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: trimmed));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                          content: Text('Answer copied'),
                          duration: Duration(seconds: 1)),
                    );
                  },
            icon: const Icon(Icons.copy_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
        const Spacer(),
        Flexible(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: (streaming || trimmed.isEmpty)
                ? null
                : () => onInsertNote(trimmed),
            icon: const Icon(Icons.note_add_outlined,
                size: 18, color: AppColors.textOnAccent),
            label: const Text('Insert as note',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textOnAccent)),
          ),
        ),
      ],
    );
  }
}

/// One numbered source passage. The number matches the `[n]` the model cites in
/// the answer. Tappable to jump to its page when navigation is wired.
class _SourceCard extends StatelessWidget {
  final int index;
  final int pageId;
  final String text;
  final void Function(int pageId)? onJumpToSource;

  const _SourceCard({
    required this.index,
    required this.pageId,
    required this.text,
    required this.onJumpToSource,
  });

  @override
  Widget build(BuildContext context) {
    final snippet = _snippet(text);
    final jump = onJumpToSource;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: jump == null ? null : () => jump(pageId),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accentWash,
                  shape: BoxShape.circle,
                ),
                child: Text('$index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentStrong,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary)),
              ),
              if (jump != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.north_east,
                      size: 14, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A chunk starts with its overlap prefix from the previous chunk; collapse
  /// whitespace and cap length so the card shows a clean lead-in.
  static String _snippet(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= 160 ? collapsed : '${collapsed.substring(0, 160)}…';
  }
}

class _Downloading extends ConsumerWidget {
  final int progress;
  final bool isEmbedder;
  const _Downloading({required this.progress, required this.isEmbedder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name;
    final String size;
    if (isEmbedder) {
      name = EmbedderSpec.active.displayName;
      size = '${(EmbedderSpec.active.approxSizeBytes / (1024 * 1024)).round()} MB';
    } else {
      name = LlmModelSpec.active.displayName;
      size =
          '${(LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Centered(
          icon: Icons.download_outlined,
          title: isEmbedder ? 'Setting up notes search' : 'Setting up AI',
          subtitle: '$name · $size — one-time download',
        ),
        const SizedBox(height: 16),
        ModelDownloadProgress(
          progress: progress,
          onCancel: () =>
              ref.read(askNotesNotifierProvider.notifier).cancelModelDownload(),
        ),
      ],
    );
  }
}

class _ErrorBody extends ConsumerWidget {
  final AskNotesError state;
  const _ErrorBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(askNotesNotifierProvider.notifier);
    final String? downloadLabel;
    if (state.offerModelDownload) {
      if (state.downloadIsEmbedder) {
        final mb = (EmbedderSpec.active.approxSizeBytes / (1024 * 1024)).round();
        downloadLabel = 'Download search model ($mb MB)';
      } else {
        final gb = LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);
        downloadLabel = 'Download model (${gb.toStringAsFixed(1)} GB)';
      }
    } else {
      downloadLabel = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Centered(
          icon: state.offerModelDownload
              ? Icons.auto_awesome_outlined
              : Icons.error_outline,
          title: state.offerModelDownload
              ? 'One quick setup step'
              : "Couldn't answer that just now",
          subtitle: state.message,
        ),
        const SizedBox(height: 14),
        if (downloadLabel != null)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: notifier.downloadModelAndRetry,
            child: Text(downloadLabel,
                style: const TextStyle(color: AppColors.textOnAccent)),
          )
        else if (state.retryable)
          TextButton.icon(
            onPressed: notifier.retry,
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.accent),
            label: const Text('Try again',
                style: TextStyle(color: AppColors.accent)),
          ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool showSpinner;
  const _Centered({
    required this.icon,
    required this.title,
    this.subtitle,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const CircularProgressIndicator(color: AppColors.accent)
          else
            Icon(icon, size: 34, color: AppColors.accentSoft),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
