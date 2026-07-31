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

import '../../../../core/theme/ink_colors.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../data/embeddings/embedder_spec.dart';
import '../../data/llm/llm_model_spec.dart';
import '../../domain/ai_scope.dart';
import '../../domain/quality/ai_quality_guard.dart';
import '../../domain/rag/rag_retriever.dart';
import '../ai_providers.dart';
import '../ask_notes_notifier.dart';
import '../widgets/ai_scope_picker.dart';
import '../widgets/answer_tier_banner.dart';
import '../widgets/math_text.dart';
import '../widgets/model_download_progress.dart';

class AiAskView extends ConsumerStatefulWidget {
  /// Hands an answer to the editor's text-insertion path ("insert as note").
  final ValueChanged<String> onInsertNote;

  /// The page the question is being asked from — its notebook is what gets
  /// searched, and its import group is what "Whole PDF" resolves to.
  final ScenePageKey pageKey;

  /// Jumps to a source passage's page. Optional: when the editor hasn't wired
  /// navigation, source cards still show but aren't tappable.
  final void Function(int pageId)? onJumpToSource;

  const AiAskView({
    super.key,
    required this.onInsertNote,
    required this.pageKey,
    this.onJumpToSource,
  });

  int get notebookId => pageKey.notebookId;

  @override
  ConsumerState<AiAskView> createState() => _AiAskViewState();
}

class _AiAskViewState extends ConsumerState<AiAskView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// What the next question may read.
  ///
  /// Defaults to the whole notebook, and to the whole PDF when this page came
  /// from one. Asking your notes a question is normally a "somewhere in here"
  /// question — unlike Explain or Summarize, which act on what is in front of
  /// you — so scoping down to a single page by default would turn most useful
  /// questions into a "not found". An imported document is the tighter, more
  /// obviously-intended unit when the student is sitting inside one, so it wins
  /// where it applies; both narrower scopes stay one tap away.
  AiScopeKind? _chosenKind;

  AiScopeKind _kindFor(ScopePage? group) =>
      _chosenKind ??
      (group == null ? AiScopeKind.notebook : AiScopeKind.importGroup);

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

  Future<void> _submit() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    final group = ref.read(pageImportGroupProvider(widget.pageKey)).valueOrNull;
    // Resolved to concrete page ids ONCE, here, and carried with the question:
    // re-deriving it later could widen what an in-flight answer was allowed to
    // read (see domain/ai_scope.dart).
    final scope = await ref.read(aiScopeResolverProvider).resolve(
          kind: _kindFor(group),
          notebookId: widget.pageKey.notebookId,
          pageId: widget.pageKey.pageId,
        );
    if (!mounted) return;
    ref
        .read(askNotesNotifierProvider.notifier)
        .ask(q, notebookId: widget.notebookId, scope: scope);
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
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: AiScopePicker(
              pageKey: widget.pageKey,
              value: _kindFor(
                  ref.watch(pageImportGroupProvider(widget.pageKey)).valueOrNull),
              enabled: !busy,
              onChanged: (kind) => setState(() => _chosenKind = kind),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Flexible(child: _body(state)),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.travel_explore, size: 18, color: context.ink.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Ask your notes',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.ink.textPrimary,
              )),
        ),
        IconButton(
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          icon: Icon(Icons.close, size: 18, color: context.ink.textSecondary),
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
      style: TextStyle(fontSize: 14, color: context.ink.textPrimary),
      decoration: InputDecoration(
        hintText: 'e.g. What did I write about mitosis?',
        hintStyle: TextStyle(color: context.ink.textMuted, fontSize: 13),
        filled: true,
        fillColor: context.ink.surfaceHighlight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: 'Ask',
          icon: Icon(Icons.arrow_upward,
              size: 20,
              color: enabled ? context.ink.accent : context.ink.textMuted),
          onPressed: enabled ? _submit : null,
        ),
      ),
    );
  }

  Widget _body(AskNotesState state) {
    return switch (state) {
      AskNotesComposing() || AskNotesIdle() => const _Hint(),
      AskNotesNotice(:final message) => _Centered(
          icon: Icons.check_circle_outline,
          title: message,
        ),
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
      AskNotesAnswered(
        :final text,
        :final sources,
        :final tier,
        :final canRetryOnCloud
      ) =>
        _Answer(
          text: text,
          sources: sources,
          streaming: false,
          onInsertNote: widget.onInsertNote,
          onJumpToSource: widget.onJumpToSource,
          tier: tier,
          // Offered only when the guard said a cloud run is both possible and
          // permitted — under `askEachTime` this button IS the user's consent,
          // and nothing reaches the network until it is pressed.
          onVerifyWithCloud: canRetryOnCloud
              ? () => ref
                  .read(askNotesNotifierProvider.notifier)
                  .verifyWithCloud()
              : null,
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

  /// Which model produced this — drives the cloud badge / low-confidence
  /// warning above the answer.
  final AnswerTier tier;
  final VoidCallback? onVerifyWithCloud;

  const _Answer({
    required this.text,
    required this.sources,
    required this.streaming,
    required this.onInsertNote,
    required this.onJumpToSource,
    this.tier = AnswerTier.local,
    this.onVerifyWithCloud,
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
                // Above the answer, not below it: a warning a student reads
                // after they have already taken the answer in has done half
                // its job.
                if (tier != AnswerTier.local) ...[
                  AnswerTierBanner(
                    tier: tier,
                    onVerifyWithCloud: onVerifyWithCloud,
                  ),
                  const SizedBox(height: 12),
                ],
                // Formulas render as maths rather than as raw LaTeX — a note
                // about the quadratic formula is exactly the kind of thing
                // someone asks their notes about. Prose is unaffected (see
                // math_text.dart).
                MathText(
                  trimmed.isEmpty ? 'Thinking…' : trimmed,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: context.ink.textPrimary,
                  ),
                ),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('SOURCES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: context.ink.textMuted,
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
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.ink.accentSoft),
                ),
                const SizedBox(width: 8),
                Text('Writing…',
                    style: TextStyle(
                        fontSize: 12, color: context.ink.textSecondary)),
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
            icon: Icon(Icons.copy_outlined,
                size: 18, color: context.ink.textSecondary),
          ),
        const Spacer(),
        Flexible(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: context.ink.accent),
            onPressed: (streaming || trimmed.isEmpty)
                ? null
                : () => onInsertNote(trimmed),
            icon: Icon(Icons.note_add_outlined,
                size: 18, color: context.ink.textOnAccent),
            label: Text('Insert as note',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.ink.textOnAccent)),
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
            color: context.ink.surfaceHighlight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.ink.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.ink.accentWash,
                  shape: BoxShape.circle,
                ),
                child: Text('$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.ink.accentStrong,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                // The source snippet is the student's own note text, which may
                // itself hold a formula the extractor read as LaTeX.
                child: MathLabel(snippet,
                    maxLines: 2,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: context.ink.textSecondary)),
              ),
              if (jump != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.north_east,
                      size: 14, color: context.ink.textMuted),
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
            style: FilledButton.styleFrom(backgroundColor: context.ink.accent),
            onPressed: notifier.downloadModelAndRetry,
            child: Text(downloadLabel,
                style: TextStyle(color: context.ink.textOnAccent)),
          )
        else if (state.retryable)
          TextButton.icon(
            onPressed: notifier.retry,
            icon: Icon(Icons.refresh, size: 18, color: context.ink.accent),
            label: Text('Try again',
                style: TextStyle(color: context.ink.accent)),
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
            CircularProgressIndicator(color: context.ink.accent)
          else
            Icon(icon, size: 34, color: context.ink.accentSoft),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.ink.textPrimary,
              )),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: context.ink.textSecondary)),
          ],
        ],
      ),
    );
  }
}
