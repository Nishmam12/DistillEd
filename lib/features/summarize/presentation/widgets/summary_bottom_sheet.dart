// Bottom sheet showing the summarization flow: model-download progress,
// distinct loading states, the summary with an expandable recognized-text
// section, and error states with retry / download actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../ai/data/llm/llm_model_spec.dart';
import '../summarize_notifier.dart';

/// Opens the summary sheet. Call after kicking off [SummarizeNotifier.run].
void showSummarySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _SummarySheet(),
  );
}

class _SummarySheet extends ConsumerWidget {
  const _SummarySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(summarizeNotifierProvider);

    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: switch (state) {
            SummarizeIdle() => const _Progress(label: 'Preparing…'),
            SummarizeRecognizing() =>
              const _Progress(label: 'Reading handwriting…'),
            SummarizeSummarizing() => const _Progress(label: 'Summarizing…'),
            SummarizeDownloadingModel(:final progress) =>
              _DownloadProgress(progress: progress, ref: ref),
            SummarizeSuccess() => _SuccessView(state: state),
            SummarizeError() => _ErrorView(state: state, ref: ref),
          },
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String text;
  const _SheetTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final String label;
  const _Progress({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('Summary'),
        const SizedBox(height: 28),
        const CircularProgressIndicator(color: AppColors.accent),
        const SizedBox(height: 16),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final int progress;
  final WidgetRef ref;
  const _DownloadProgress({required this.progress, required this.ref});

  @override
  Widget build(BuildContext context) {
    final sizeGb =
        (LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('Downloading model'),
        const SizedBox(height: 8),
        Text(
          '${LlmModelSpec.active.displayName} · ${sizeGb.toStringAsFixed(1)} GB — one-time download',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceHighlight,
          ),
        ),
        const SizedBox(height: 8),
        Text('$progress%',
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () =>
              ref.read(summarizeNotifierProvider.notifier).cancelModelDownload(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final SummarizeSuccess state;
  const _SuccessView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: _SheetTitle('Summary')),
              if (state.fromCache)
                const _Badge('Cached')
              else if (state.chunked)
                const _Badge('Long note — condensed'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.summary,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Recognized text',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarm,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    state.recognizedText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.accentStrong,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final SummarizeError state;
  final WidgetRef ref;
  const _ErrorView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(summarizeNotifierProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.accentRed, size: 40),
        const SizedBox(height: 12),
        Text(
          state.message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 20),
        if (state.offerModelDownload)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: notifier.downloadModelAndRetry,
            child: Text(
              'Download model '
              '(${(LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB)',
              style: const TextStyle(color: AppColors.textOnAccent),
            ),
          )
        else if (state.retryable)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: notifier.retry,
            child: const Text('Retry',
                style: TextStyle(color: AppColors.textOnAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
