// The body of the AI sidebar: renders the live [PageContext] for the current
// page across its states (reading / empty / needs-model / error / ready).
//
// This is the study-aid surface, not a linter — knowledge gaps are gentle
// honey-toned flags, never red errors. Shared verbatim by the tablet side
// panel and the phone bottom sheet ([AiSidebar]).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../data/llm/llm_model_spec.dart';
import '../../domain/ai_provider.dart';
import '../../domain/context_engine/page_context.dart';
import '../../domain/features/explainer.dart';
import '../../domain/features/writing_assistant.dart';
import '../ai_providers.dart';
import '../explain_notifier.dart';

class AiContextView extends ConsumerWidget {
  final ScenePageKey pageKey;
  const AiContextView({super.key, required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pageContextProvider(pageKey));

    // Keep showing the last good context while a re-analysis runs underneath,
    // so the panel never flickers back to a spinner mid-edit.
    final previous = async.valueOrNull;

    // Tapping a knowledge-gap flag explains that undefined term in context —
    // the second Explain trigger (the first is the selection launcher).
    void explainGap(String gap, String topic) {
      ref.read(explainNotifierProvider.notifier).run(ExplainRequest(
            mode: ExplainMode.beginner,
            resolveContent: () async => _gapExplainContent(gap, topic),
          ));
    }

    return switch (async) {
      AsyncData(:final value) when value.isEmpty => const _EmptyState(),
      AsyncData(:final value) => _ContextBody(
          pageKey: pageKey,
          context: value,
          onExplainGap: (g) => explainGap(g, value.currentTopic),
        ),
      AsyncLoading() when previous != null && !previous.isEmpty => _ContextBody(
          pageKey: pageKey,
          context: previous,
          refreshing: true,
          onExplainGap: (g) => explainGap(g, previous.currentTopic),
        ),
      AsyncLoading() => const _ReadingState(),
      AsyncError(:final error) => _ErrorState(pageKey: pageKey, error: error),
      _ => const _ReadingState(),
    };
  }
}

/// Prompt sent when a knowledge-gap flag is tapped: explain the flagged term,
/// grounded in the page's detected topic when there is one.
String _gapExplainContent(String gap, String topic) {
  final where = topic.isEmpty ? '' : ' It appears in notes about "$topic".';
  return 'Explain this concept, which the notes use but never define: '
      '"$gap".$where';
}

class _ReadingState extends StatelessWidget {
  const _ReadingState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.auto_awesome_outlined,
      title: 'Reading your page…',
      subtitle: 'Following along as you write.',
      showSpinner: true,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.edit_note_outlined,
      title: 'Start writing',
      subtitle: "Once there's enough on the page, I'll pick out the topic, "
          'key concepts, and anything left unexplained.',
    );
  }
}

/// Distinguishes "model not downloaded" (an actionable, one-time download)
/// from any other transient failure (a gentle retry).
class _ErrorState extends ConsumerWidget {
  final ScenePageKey pageKey;
  final Object error;
  const _ErrorState({required this.pageKey, required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error is AiModelNotReadyException) {
      return _ModelNotReady(pageKey: pageKey);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _CenteredMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't read the page just now",
          subtitle: 'This is usually momentary.',
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => ref.read(pageContextProvider(pageKey).notifier).refresh(),
          icon: const Icon(Icons.refresh, size: 18, color: AppColors.accent),
          label: const Text('Try again',
              style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }
}

/// The model isn't downloaded yet — offer the one-time download inline, then
/// re-run analysis for this page when it finishes.
class _ModelNotReady extends ConsumerStatefulWidget {
  final ScenePageKey pageKey;
  const _ModelNotReady({required this.pageKey});

  @override
  ConsumerState<_ModelNotReady> createState() => _ModelNotReadyState();
}

class _ModelNotReadyState extends ConsumerState<_ModelNotReady> {
  StreamSubscription<int>? _progressSub;
  int? _progress;
  bool _downloading = false;
  String? _failure;

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    final manager = ref.read(modelDownloadManagerProvider);
    setState(() {
      _downloading = true;
      _failure = null;
      _progress = 0;
    });
    _progressSub?.cancel();
    _progressSub = manager.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    try {
      await manager.download();
      if (!mounted) return;
      // Force a re-run: the previous attempt failed on the missing model.
      await ref.read(pageContextProvider(widget.pageKey).notifier).refresh();
    } catch (e) {
      if (mounted) setState(() => _failure = 'Download failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeGb =
        LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);

    if (_downloading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CenteredMessage(
            icon: Icons.download_outlined,
            title: 'Setting up AI insights',
            subtitle: '${LlmModelSpec.active.displayName} · '
                '${sizeGb.toStringAsFixed(1)} GB — one-time download',
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_progress ?? 0) / 100,
              minHeight: 8,
              color: AppColors.accent,
              backgroundColor: AppColors.surfaceHighlight,
            ),
          ),
          const SizedBox(height: 8),
          Text('${_progress ?? 0}%',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CenteredMessage(
          icon: Icons.auto_awesome_outlined,
          title: 'Turn on AI insights',
          subtitle: 'A one-time ${sizeGb.toStringAsFixed(1)} GB on-device model '
              'reads your notes privately — nothing leaves your device.',
        ),
        if (_failure != null) ...[
          const SizedBox(height: 8),
          Text(_failure!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.accentRed)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _download,
          child: Text('Download model (${sizeGb.toStringAsFixed(1)} GB)',
              style: const TextStyle(color: AppColors.textOnAccent)),
        ),
      ],
    );
  }
}

/// The real content: topic, level, concepts, gaps, definitions, and any live
/// Writing Assistant suggestions.
class _ContextBody extends StatelessWidget {
  final ScenePageKey pageKey;
  final PageContext context;
  final bool refreshing;

  /// Called when a knowledge-gap flag is tapped (null → flags aren't tappable).
  final ValueChanged<String>? onExplainGap;
  const _ContextBody({
    required this.pageKey,
    required this.context,
    this.refreshing = false,
    this.onExplainGap,
  });

  @override
  Widget build(BuildContext buildContext) {
    final c = context;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('CURRENT TOPIC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  )),
              const Spacer(),
              if (refreshing)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accentSoft),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.currentTopic.isEmpty ? 'Not sure yet' : c.currentTopic,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (c.subtopics.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(c.subtopics.join('  ·  '),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 14),
          _LevelIndicator(level: c.estimatedLevel, confidence: c.confidence),
          if (c.keyConcepts.isNotEmpty) ...[
            const _SectionLabel('Key concepts'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final concept in c.keyConcepts) _ConceptChip(concept)],
            ),
          ],
          if (c.knowledgeGaps.isNotEmpty) ...[
            const _SectionLabel('Worth revisiting'),
            const SizedBox(height: 8),
            for (final gap in c.knowledgeGaps)
              _GapFlag(
                gap,
                onTap: onExplainGap == null ? null : () => onExplainGap!(gap),
              ),
          ],
          if (c.definitions.isNotEmpty) ...[
            const _SectionLabel('Definitions on this page'),
            const SizedBox(height: 8),
            for (final entry in c.definitions.entries)
              _DefinitionRow(term: entry.key, definition: entry.value),
          ],
          _WritingSection(pageKey: pageKey),
        ],
      ),
    );
  }
}

/// Live, dismissible Writing Assistant suggestions on the typed text. Renders
/// nothing when there are none — a quiet study aid, never a nagging linter.
class _WritingSection extends ConsumerWidget {
  final ScenePageKey pageKey;
  const _WritingSection({required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(writingSuggestionsProvider(pageKey));
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Writing suggestions'),
        const SizedBox(height: 8),
        for (final s in suggestions)
          _SuggestionCard(
            suggestion: s,
            onDismiss: () => ref
                .read(writingSuggestionsProvider(pageKey).notifier)
                .dismiss(s),
          ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final WritingSuggestion suggestion;
  final VoidCallback onDismiss;
  const _SuggestionCard({required this.suggestion, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.kind.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    )),
                const SizedBox(height: 3),
                Text(s.message,
                    style: const TextStyle(
                        fontSize: 13, height: 1.35, color: AppColors.textPrimary)),
                if (s.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('“${s.excerpt}”',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      )),
                ],
                if (s.replacement.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text.rich(TextSpan(
                    style: const TextStyle(fontSize: 12, height: 1.3),
                    children: [
                      const TextSpan(
                          text: 'Try: ',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted)),
                      TextSpan(
                          text: s.replacement,
                          style: const TextStyle(color: AppColors.accentStrong)),
                    ],
                  )),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 0),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          )),
    );
  }
}

class _LevelIndicator extends StatelessWidget {
  final KnowledgeLevel level;
  final double confidence;
  const _LevelIndicator({required this.level, required this.confidence});

  static const _labels = {
    KnowledgeLevel.beginner: 'Beginner',
    KnowledgeLevel.intermediate: 'Intermediate',
    KnowledgeLevel.advanced: 'Advanced',
  };

  @override
  Widget build(BuildContext context) {
    final index = level.index;
    return Row(
      children: [
        for (var i = 0; i < KnowledgeLevel.values.length; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= index ? AppColors.accent : AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i < KnowledgeLevel.values.length - 1) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        Text(_labels[level]!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
      ],
    );
  }
}

class _ConceptChip extends StatelessWidget {
  final String label;
  const _ConceptChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentPurpleWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.accentPurpleStrong,
          )),
    );
  }
}

/// A knowledge gap — a gentle honey-toned nudge, deliberately NOT a red error.
/// When [onTap] is set, tapping it asks Explain to unpack the term in context.
class _GapFlag extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _GapFlag(this.text, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentYellowWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.lightbulb_outline,
                size: 16, color: AppColors.accentYellow),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, height: 1.35, color: AppColors.textPrimary)),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.school_outlined,
                  size: 15, color: AppColors.accentYellow),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

class _DefinitionRow extends StatelessWidget {
  final String term;
  final String definition;
  const _DefinitionRow({required this.term, required this.definition});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
              fontSize: 13, height: 1.4, color: AppColors.textPrimary),
          children: [
            TextSpan(
                text: '$term — ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(
                text: definition,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showSpinner;
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const CircularProgressIndicator(color: AppColors.accent)
          else
            Icon(icon, size: 36, color: AppColors.accentSoft),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
