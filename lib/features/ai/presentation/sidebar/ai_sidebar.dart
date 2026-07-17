// The AI sidebar: the in-editor home for the Live Context Engine and the
// launch surface for every Phase 1 feature (Explain lives here now; Quiz,
// Flashcards land here in later loops).
//
// It coexists with the canvas — a fixed-width right-hand panel on tablet-width
// screens ([AiSidebar]), and a bottom sheet on phone-width ([showAiSidebarSheet]).
// Both show the same body: the live [AiContextView], or the [AiExplainView]
// while an explanation is streaming, plus a Summarize/Explain action footer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../../../editor/state/selection_controller.dart';
import '../../domain/context_engine/page_context.dart';
import '../../domain/features/explainer.dart';
import '../../domain/features/quiz_generator.dart';
import '../ai_providers.dart';
import '../ask_notes_notifier.dart';
import '../explain_notifier.dart';
import '../flashcard_notifier.dart';
import '../flashcards/flashcard_sheet.dart';
import '../quiz_notifier.dart';
import '../quiz/quiz_sheet.dart';
import 'ai_ask_view.dart';
import 'ai_context_view.dart';
import 'ai_explain_view.dart';

/// Width of the docked panel on wide screens.
const double kAiSidebarWidth = 340;

/// At or above this width the sidebar docks beside the canvas; below it, the
/// AI action opens the bottom sheet instead.
const double kAiSidebarBreakpoint = 720;

/// What the sidebar's Summarize action should cover. The sidebar only names the
/// choice (and reads the editor's selection to know which are available); the
/// editor — which owns both the AI platform and the summarize feature — turns
/// it into a request. This keeps `features/ai` free of a dependency on the
/// consumer `features/summarize`.
enum SummarizeScopeChoice { selection, page, notebook }

/// Docked side panel (wide screens). The editor puts this in a [Row] next to
/// the canvas and controls its visibility.
class AiSidebar extends StatelessWidget {
  final ScenePageKey pageKey;
  final VoidCallback onClose;

  /// Launches summarization at the chosen scope (wired by the editor).
  final ValueChanged<SummarizeScopeChoice> onSummarize;

  /// Hands an explanation to the editor's text-insertion path ("insert as note").
  final ValueChanged<String> onInsertNote;

  /// Jumps to a source page from an "Ask your notes" answer. Optional — until
  /// the editor wires page navigation, source cards render but aren't tappable.
  final void Function(int pageId)? onJumpToSource;

  const AiSidebar({
    super.key,
    required this.pageKey,
    required this.onClose,
    required this.onSummarize,
    required this.onInsertNote,
    this.onJumpToSource,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kAiSidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _SidebarHeader(onClose: onClose),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: _SidebarBody(
                  pageKey: pageKey,
                  onInsertNote: onInsertNote,
                  onJumpToSource: onJumpToSource,
                ),
              ),
            ),
            _SidebarFooter(pageKey: pageKey, onSummarize: onSummarize),
          ],
        ),
      ),
    );
  }
}

/// Phone-width presentation: the same body in a bottom sheet.
Future<void> showAiSidebarSheet(
  BuildContext context,
  ScenePageKey pageKey, {
  required ValueChanged<SummarizeScopeChoice> onSummarize,
  required ValueChanged<String> onInsertNote,
  void Function(int pageId)? onJumpToSource,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SidebarHeader(onClose: () => Navigator.of(context).pop()),
            const SizedBox(height: 8),
            Flexible(
                child: _SidebarBody(
              pageKey: pageKey,
              onInsertNote: onInsertNote,
              onJumpToSource: onJumpToSource,
            )),
            _SidebarFooter(pageKey: pageKey, onSummarize: onSummarize),
          ],
        ),
      ),
    ),
  );
}

/// The scrolling body. Precedence: the [AiAskView] while a "Ask your notes"
/// query is active, then the streamed [AiExplainView] while an explanation is,
/// otherwise the live [AiContextView] (whose knowledge-gap flags are themselves
/// an Explain trigger). Ask and Explain can't both be active — the footer that
/// launches each is hidden whenever either surface is up.
class _SidebarBody extends ConsumerWidget {
  final ScenePageKey pageKey;
  final ValueChanged<String> onInsertNote;
  final void Function(int pageId)? onJumpToSource;
  const _SidebarBody({
    required this.pageKey,
    required this.onInsertNote,
    this.onJumpToSource,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(askNotesNotifierProvider) is! AskNotesIdle) {
      return AiAskView(
        onInsertNote: onInsertNote,
        notebookId: pageKey.notebookId,
        onJumpToSource: onJumpToSource,
      );
    }
    if (ref.watch(explainNotifierProvider) is! ExplainIdle) {
      return AiExplainView(onInsertNote: onInsertNote);
    }
    return AiContextView(pageKey: pageKey);
  }
}

/// The Summarize / Explain action bar. Hidden while an explanation is on screen
/// (the Explain view carries its own actions), so it never competes with it.
class _SidebarFooter extends ConsumerWidget {
  final ScenePageKey pageKey;
  final ValueChanged<SummarizeScopeChoice> onSummarize;
  const _SidebarFooter({required this.pageKey, required this.onSummarize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asking = ref.watch(askNotesNotifierProvider) is! AskNotesIdle;
    final explaining = ref.watch(explainNotifierProvider) is! ExplainIdle;
    if (asking || explaining) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AskBar(),
              _SummarizeBar(onSummarize: onSummarize),
              _ExplainBar(pageKey: pageKey),
              _QuizBar(pageKey: pageKey),
              _FlashcardBar(pageKey: pageKey),
            ],
          ),
        ),
      ],
    );
  }
}

/// The sidebar's "Ask your notes" launcher: opens the query box (the actual
/// retrieval + answer live entirely in `features/ai`).
class _AskBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ref.read(askNotesNotifierProvider.notifier).startComposing(),
      child: const _ActionChip(
        icon: Icons.travel_explore_outlined,
        label: 'Ask notes',
        enabled: true,
      ),
    );
  }
}

/// The sidebar's Summarize launcher: a menu offering selection / page /
/// notebook scope. "Selected items" only appears when the editor has a live
/// selection ([selectionProvider], read-only). The actual run is delegated to
/// the editor via [onSummarize].
class _SummarizeBar extends ConsumerWidget {
  final ValueChanged<SummarizeScopeChoice> onSummarize;
  const _SummarizeBar({required this.onSummarize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelection = ref.watch(selectionProvider).isNotEmpty;
    return PopupMenuButton<SummarizeScopeChoice>(
      tooltip: 'Summarize',
      position: PopupMenuPosition.under,
      onSelected: onSummarize,
      itemBuilder: (context) => [
        if (hasSelection)
          const PopupMenuItem(
            value: SummarizeScopeChoice.selection,
            child: Text('Selected items'),
          ),
        const PopupMenuItem(
          value: SummarizeScopeChoice.page,
          child: Text('This page'),
        ),
        const PopupMenuItem(
          value: SummarizeScopeChoice.notebook,
          child: Text('Whole notebook'),
        ),
      ],
      child: const _ActionChip(
        icon: Icons.auto_awesome_outlined,
        label: 'Summarize',
        enabled: true,
      ),
    );
  }
}

/// The sidebar's Explain launcher: explains the current selection at a chosen
/// depth. Disabled until the editor has a selection (the other Explain trigger
/// is tapping a knowledge-gap flag in the context view). Resolution and
/// streaming live entirely in `features/ai`; only "insert as note" touches the
/// editor.
class _ExplainBar extends ConsumerWidget {
  final ScenePageKey pageKey;
  const _ExplainBar({required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelection = ref.watch(selectionProvider).isNotEmpty;
    if (!hasSelection) {
      return const Tooltip(
        message: 'Select notes to explain',
        child: _ActionChip(
          icon: Icons.school_outlined,
          label: 'Explain',
          enabled: false,
        ),
      );
    }
    return PopupMenuButton<ExplainMode>(
      tooltip: 'Explain selection',
      position: PopupMenuPosition.under,
      onSelected: (mode) => _explainSelection(ref, mode),
      itemBuilder: (context) => [
        for (final mode in ExplainMode.values)
          PopupMenuItem(value: mode, child: Text(mode.label)),
      ],
      child: const _ActionChip(
        icon: Icons.school_outlined,
        label: 'Explain',
        enabled: true,
      ),
    );
  }

  void _explainSelection(WidgetRef ref, ExplainMode mode) {
    // Capture the concrete services and the selected ids now, so a later retry
    // or mode-change re-reads the same selection safely (no stale WidgetRef).
    final extractor = ref.read(pageContentExtractorProvider);
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final languageCode = ref.read(settingsProvider).recognitionLanguage;
    final ids = ref.read(selectionProvider);
    final pageId = pageKey.pageId;

    ref.read(explainNotifierProvider.notifier).run(ExplainRequest(
          mode: mode,
          resolveContent: () async {
            await recognition.ensureModelDownloaded(languageCode);
            final content = await extractor.extractSelection(pageId, ids,
                languageCode: languageCode);
            return content.combinedText;
          },
        ));
  }
}

/// The sidebar's Quiz launcher: builds a gradeable quiz from the current page
/// (difficulty from the detected level; coding questions only when the page
/// looks like programming) and opens the quiz sheet. Entirely `features/ai`.
class _QuizBar extends ConsumerWidget {
  final ScenePageKey pageKey;
  const _QuizBar({required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _startQuiz(context, ref),
      child: const _ActionChip(
        icon: Icons.quiz_outlined,
        label: 'Quiz',
        enabled: true,
      ),
    );
  }

  void _startQuiz(BuildContext context, WidgetRef ref) {
    final extractor = ref.read(pageContentExtractorProvider);
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final languageCode = ref.read(settingsProvider).recognitionLanguage;
    final pageId = pageKey.pageId;

    final context0 = ref.read(pageContextProvider(pageKey)).valueOrNull;
    final level = context0?.estimatedLevel ?? KnowledgeLevel.intermediate;
    final allowCoding =
        context0 != null && QuizGenerator.looksLikeProgramming(context0);

    ref.read(quizNotifierProvider.notifier).generate(QuizRequest(
          level: level,
          allowCoding: allowCoding,
          notebookId: pageKey.notebookId,
          pageId: pageId,
          // The page's concepts, so each graded question can be attributed back
          // to what it actually tested (Phase 2 Learning Memory).
          concepts: context0?.keyConcepts ?? const [],
          resolveText: () async {
            await recognition.ensureModelDownloaded(languageCode);
            final content =
                await extractor.extractPage(pageId, languageCode: languageCode);
            return content.combinedText;
          },
        ));
    showQuizSheet(context);
  }
}

/// The sidebar's Flashcards launcher: builds (and persists) a deck from the
/// current page's concepts + definitions, then opens the deck sheet.
class _FlashcardBar extends ConsumerWidget {
  final ScenePageKey pageKey;
  const _FlashcardBar({required this.pageKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _startCards(context, ref),
      child: const _ActionChip(
        icon: Icons.style_outlined,
        label: 'Cards',
        enabled: true,
      ),
    );
  }

  void _startCards(BuildContext context, WidgetRef ref) {
    final extractor = ref.read(pageContentExtractorProvider);
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final languageCode = ref.read(settingsProvider).recognitionLanguage;
    final pageContext =
        ref.read(pageContextProvider(pageKey)).valueOrNull ?? PageContext.empty;
    final pageId = pageKey.pageId;

    ref.read(flashcardNotifierProvider.notifier).generate(FlashcardRequest(
          notebookId: pageKey.notebookId,
          pageId: pageId,
          context: pageContext,
          resolveText: () async {
            await recognition.ensureModelDownloaded(languageCode);
            final content =
                await extractor.extractPage(pageId, languageCode: languageCode);
            return content.combinedText;
          },
        ));
    showFlashcardSheet(context);
  }
}

/// A pill-styled action trigger shared by the Summarize/Explain launchers.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? AppColors.accentStrong : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: enabled ? AppColors.accentWash : AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _SidebarHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          const Text('AI insights',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          const Spacer(),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
