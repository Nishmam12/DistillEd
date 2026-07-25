// The sidebar's Explain surface: renders a streamed explanation in place of the
// live context, with a mode selector (re-run at a different depth), an "insert
// as note" action that hands the text back to the editor, and a close that
// returns to the Context Engine view.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/llm/llm_model_spec.dart';
import '../../domain/features/explainer.dart';
import '../../domain/routing/intelligent_router.dart' show CloudTier;
import '../ai_providers.dart';
import '../explain_notifier.dart';
import '../widgets/model_download_progress.dart';

class AiExplainView extends ConsumerWidget {
  /// Hands the explanation text to the editor's text-insertion path.
  final ValueChanged<String> onInsertNote;
  const AiExplainView({super.key, required this.onInsertNote});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(explainNotifierProvider);

    return switch (state) {
      ExplainPreparing() => const _Header(
          child: _Centered(
            icon: Icons.menu_book_outlined,
            title: 'Reading your selection…',
            showSpinner: true,
          ),
        ),
      ExplainDownloadingModel(:final progress) =>
        _Header(child: _Downloading(progress: progress)),
      ExplainStreaming(:final text, :final mode, :final fromCloud) => _Header(
          mode: mode,
          fromCloud: fromCloud,
          child: _Body(
            text: text,
            streaming: true,
            onInsertNote: onInsertNote,
          ),
        ),
      ExplainReady(:final text, :final mode, :final fromCloud) => _Header(
          mode: mode,
          fromCloud: fromCloud,
          child: _Body(
            text: text,
            streaming: false,
            onInsertNote: onInsertNote,
          ),
        ),
      ExplainConfirmCloud() =>
        _Header(child: _ConfirmCloudBody(state: state)),
      ExplainError() => _Header(child: _ErrorBody(state: state)),
      ExplainIdle() => const SizedBox.shrink(),
    };
  }
}

/// Shared chrome: a title row with an optional mode selector and a close that
/// returns to the live context view.
class _Header extends ConsumerWidget {
  final Widget child;
  final ExplainMode? mode;

  /// Persistent, hard-to-miss indicator per the phase spec's "clearly
  /// indicate when cloud AI is being used" privacy rule.
  final bool fromCloud;
  const _Header({required this.child, this.mode, this.fromCloud = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.school_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Explain',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ),
            if (fromCloud) const _CloudBadge(),
            if (mode != null) _ModeSelector(mode: mode!),
            IconButton(
              tooltip: 'Close',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close,
                  size: 18, color: AppColors.textSecondary),
              onPressed: () =>
                  ref.read(explainNotifierProvider.notifier).reset(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(child: child),
      ],
    );
  }
}

class _ModeSelector extends ConsumerWidget {
  final ExplainMode mode;
  const _ModeSelector({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<ExplainMode>(
      tooltip: 'Explanation style',
      position: PopupMenuPosition.under,
      onSelected: (m) =>
          ref.read(explainNotifierProvider.notifier).changeMode(m),
      itemBuilder: (context) => [
        for (final m in ExplainMode.values)
          PopupMenuItem(
            value: m,
            child: Row(
              children: [
                Icon(
                  m == mode ? Icons.check : Icons.tune,
                  size: 16,
                  color: m == mode ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(m.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accentWash,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mode.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentStrong,
                )),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: AppColors.accentStrong),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  final bool streaming;
  final ValueChanged<String> onInsertNote;
  const _Body({
    required this.text,
    required this.streaming,
    required this.onInsertNote,
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
            child: SelectableText(
              trimmed.isEmpty ? 'Thinking…' : trimmed,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
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
                              content: Text('Explanation copied'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                icon: const Icon(Icons.copy_outlined,
                    size: 18, color: AppColors.textSecondary),
              ),
            const Spacer(),
            Flexible(
              child: FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.accent),
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
        ),
      ],
    );
  }
}

/// Small, hard-to-miss "this used the cloud" pill — deliberately not hidden
/// behind a tooltip or icon-only affordance (the spec requires it be
/// "genuinely noticeable, not buried").
class _CloudBadge extends StatelessWidget {
  const _CloudBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentWash,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentSoft),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_outlined, size: 13, color: AppColors.accentStrong),
          SizedBox(width: 4),
          Text('Cloud',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accentStrong,
              )),
        ],
      ),
    );
  }
}

/// Pauses before a cloud call for the user's explicit yes/no — "never
/// silently send to cloud". The first-ever call gets a longer, more
/// educational explanation; later ones are terser.
class _ConfirmCloudBody extends ConsumerWidget {
  final ExplainConfirmCloud state;
  const _ConfirmCloudBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(explainNotifierProvider.notifier);
    final tierLabel =
        state.tier == CloudTier.frontier ? 'a frontier cloud model' : 'a cloud model';
    final subtitle = state.isFirstEver
        ? 'This passage is long enough that explaining it well needs more '
            'than the on-device model can do — so this one request (and only '
            'this one) would be sent to $tierLabel to answer. Nothing else '
            'about your notebook leaves the device, and you\'ll see this '
            'prompt every time unless you change it in Settings.'
        : 'This would be sent to $tierLabel to answer.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Centered(
          icon: Icons.cloud_outlined,
          title: 'Use the cloud for this one?',
          subtitle: subtitle,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: notifier.cancelCloud,
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: notifier.confirmCloudAndRun,
              child: const Text('Send',
                  style: TextStyle(color: AppColors.textOnAccent)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBody extends ConsumerWidget {
  final ExplainError state;
  const _ErrorBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(explainNotifierProvider.notifier);
    final sizeGb = LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Centered(
          icon: state.offerModelDownload
              ? Icons.auto_awesome_outlined
              : Icons.cloud_off_outlined,
          title: state.offerModelDownload
              ? 'Turn on AI insights'
              : "Couldn't explain that just now",
          subtitle: state.message,
        ),
        const SizedBox(height: 14),
        if (state.offerModelDownload)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: notifier.downloadModelAndRetry,
            child: Text('Download model (${sizeGb.toStringAsFixed(1)} GB)',
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

class _Downloading extends ConsumerWidget {
  final int progress;
  const _Downloading({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeGb = LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Centered(
          icon: Icons.download_outlined,
          title: 'Setting up AI insights',
          subtitle: '${LlmModelSpec.active.displayName} · '
              '${sizeGb.toStringAsFixed(1)} GB — one-time download',
        ),
        const SizedBox(height: 16),
        ModelDownloadProgress(
          progress: progress,
          onCancel: () =>
              ref.read(explainNotifierProvider.notifier).cancelModelDownload(),
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
