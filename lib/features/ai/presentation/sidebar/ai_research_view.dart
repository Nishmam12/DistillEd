// The sidebar's Research surface (Phase 3, Loop 3.4): a free-form question
// box whose answer may come from Calculator / Wikipedia / Web Search rather
// than the model's own words — the opposite of "Ask your notes", which
// refuses to look anywhere but the notes. Query-box shape mirrors
// `ai_ask_view.dart`; the confirm-cloud gate and cloud badge mirror
// `ai_explain_view.dart` (Research has no local route, so every request
// goes through that gate).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../ai_providers.dart';
import '../research_notifier.dart';

class AiResearchView extends ConsumerStatefulWidget {
  /// Hands the answer text to the editor's text-insertion path.
  final ValueChanged<String> onInsertNote;
  const AiResearchView({super.key, required this.onInsertNote});

  @override
  ConsumerState<AiResearchView> createState() => _AiResearchViewState();
}

class _AiResearchViewState extends ConsumerState<AiResearchView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
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
    ref.read(researchNotifierProvider.notifier).ask(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(researchNotifierProvider);
    final busy = state is ResearchStreaming;
    final showQueryBox = state is! ResearchConfirmCloud;
    final fromCloud = state is ResearchStreaming || state is ResearchReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(fromCloud: fromCloud),
        const SizedBox(height: 8),
        if (showQueryBox) ...[
          _queryBox(enabled: !busy),
          const SizedBox(height: 12),
        ],
        Flexible(child: _body(state)),
      ],
    );
  }

  Widget _header({required bool fromCloud}) {
    return Row(
      children: [
        const Icon(Icons.manage_search, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Research',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
        ),
        if (fromCloud) const _CloudBadge(),
        IconButton(
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
          onPressed: () => ref.read(researchNotifierProvider.notifier).reset(),
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
        hintText: 'e.g. What\'s 18% of 245?',
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
              size: 20, color: enabled ? AppColors.accent : AppColors.textMuted),
          onPressed: enabled ? _submit : null,
        ),
      ),
    );
  }

  Widget _body(ResearchState state) {
    return switch (state) {
      ResearchComposing() || ResearchIdle() => const _Hint(),
      ResearchConfirmCloud() => _ConfirmCloudBody(state: state),
      ResearchStreaming(:final text, :final toolsUsed) => _Answer(
          text: text,
          toolsUsed: toolsUsed,
          streaming: true,
          onInsertNote: widget.onInsertNote,
          onStop: () => ref.read(researchNotifierProvider.notifier).stop(),
        ),
      ResearchReady(:final text, :final toolsUsed) => _Answer(
          text: text,
          toolsUsed: toolsUsed,
          streaming: false,
          onInsertNote: widget.onInsertNote,
        ),
      ResearchError() => _ErrorBody(state: state),
      ResearchUnavailable() => const _Centered(
          icon: Icons.cloud_off_outlined,
          title: 'Research needs cloud access',
          subtitle: 'Research uses tools (calculator, lookups, web search) '
              'that only work through the cloud tier. Allow cloud use in '
              'Settings to use this feature.',
        ),
    };
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      icon: Icons.lightbulb_outline,
      title: 'Ask anything',
      subtitle: 'Research can reach beyond your notes — arithmetic, '
          'encyclopedia lookups, and web search — using the cloud tier.',
    );
  }
}

/// The answer text plus which tools it drew on.
class _Answer extends StatelessWidget {
  final String text;
  final List<String> toolsUsed;
  final bool streaming;
  final ValueChanged<String> onInsertNote;

  /// Abandons an in-flight run. Only supplied (and only shown) while
  /// [streaming]; null on the settled answer.
  final VoidCallback? onStop;

  const _Answer({
    required this.text,
    required this.toolsUsed,
    required this.streaming,
    required this.onInsertNote,
    this.onStop,
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
                if (toolsUsed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tool in toolsUsed) _ToolUsedChip(tool),
                    ],
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
    // While streaming, the only actions that make sense are "wait" or "stop"
    // — Insert/Copy operate on a finished answer, so they're held back until
    // the run settles rather than shown disabled.
    if (streaming) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accentSoft),
          ),
          const SizedBox(width: 8),
          const Text('Researching…',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          TextButton.icon(
            onPressed: onStop,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.stop_circle_outlined,
                size: 18, color: AppColors.accent),
            label: const Text('Stop',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      );
    }
    return Row(
      children: [
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
            onPressed:
                trimmed.isEmpty ? null : () => onInsertNote(trimmed),
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

class _ToolUsedChip extends StatelessWidget {
  final String toolName;
  const _ToolUsedChip(this.toolName);

  static const _icons = {
    'calculator': Icons.calculate_outlined,
    'wikipedia': Icons.menu_book_outlined,
    'web_search': Icons.public,
  };

  static const _labels = {
    'calculator': 'Calculator',
    'wikipedia': 'Wikipedia',
    'web_search': 'Web search',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icons[toolName] ?? Icons.build_outlined,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(_labels[toolName] ?? toolName,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Same visual language as `ai_explain_view.dart`'s cloud indicator —
/// "genuinely noticeable, not buried" per the phase spec's privacy rule.
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
  final ResearchConfirmCloud state;
  const _ConfirmCloudBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(researchNotifierProvider.notifier);
    final subtitle = state.isFirstEver
        ? 'Research can use tools — a calculator, Wikipedia, and web '
            'search — that only work through the cloud tier, so this '
            'question (and only this one) would be sent there to answer. '
            'Nothing else about your notebook leaves the device, and '
            "you'll see this prompt every time unless you change it in "
            'Settings.'
        : 'This question would be sent to the cloud to answer.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Centered(
          icon: Icons.cloud_outlined,
          title: 'Use the cloud for this?',
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
              onPressed: notifier.confirmCloudAndAsk,
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
  final ResearchError state;
  const _ErrorBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(researchNotifierProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Centered(
          icon: Icons.error_outline,
          title: "Couldn't answer that just now",
          subtitle: state.message,
        ),
        const SizedBox(height: 14),
        if (state.retryable)
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
  const _Centered({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
