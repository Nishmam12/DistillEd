import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../ai/data/embeddings/embedder_adapter.dart';
import '../../../ai/data/embeddings/embedder_spec.dart';
import '../../../ai/data/llm/llm_exceptions.dart';
import '../../../ai/data/llm/llm_model_spec.dart';
import '../../../home/data/repositories/note_repository.dart';
import '../../../summarize/presentation/summarize_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _SectionHeader('Appearance'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Use dark theme across the app',
                trailing: Switch(
                  value: settings.darkMode,
                  onChanged: notifier.toggleDarkMode,
                ),
              ),
            ],
          ),
          const _SectionHeader('Notes'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.delete_outline,
                title: 'Trash',
                subtitle: 'Restore deleted notes for '
                    '${NoteRepository.trashRetention.inDays} days',
                trailing: IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => context.push('/trash'),
                ),
              ),
            ],
          ),
          const _SectionHeader('Export Defaults'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.image_outlined,
                title: 'Format',
                subtitle: 'Default format when exporting notebooks',
                trailing: _FormatToggle(
                  value: settings.exportDefault,
                  onChanged: notifier.setExportDefault,
                ),
              ),
            ],
          ),
          const _SectionHeader('AI'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.cloud_outlined,
                title: 'Cloud AI',
                subtitle:
                    'Allow very long notes to be summarized in the cloud. '
                    'When off, notes never leave this device.',
                trailing: Switch(
                  value: settings.cloudAiEnabled,
                  onChanged: notifier.setCloudAiEnabled,
                ),
              ),
              _SettingsRow(
                icon: Icons.translate,
                title: 'Handwriting Language',
                subtitle: 'Language used to read your notes',
                trailing: _LanguageToggle(
                  value: settings.recognitionLanguage,
                  onChanged: notifier.setRecognitionLanguage,
                ),
              ),
              _SettingsRow(
                icon: Icons.key_outlined,
                title: 'HuggingFace Token',
                subtitle: settings.hasHuggingFaceToken
                    ? 'Added — gated models can be downloaded'
                    : 'Needed for gated models like EmbeddingGemma. Your own '
                        'token, kept on this device.',
                trailing: TextButton(
                  onPressed: () => _editHuggingFaceToken(context, ref),
                  child: Text(
                    settings.hasHuggingFaceToken ? 'Change' : 'Add',
                    style: const TextStyle(color: AppColors.accentStrong),
                  ),
                ),
              ),
            ],
          ),
          const _SectionHeader('AI Models'),
          const _AiModelsCard(),
          const _SectionHeader('Developer'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.terminal,
                title: 'Developer Mode',
                subtitle: 'Show performance metrics overlay',
                trailing: Switch(
                  value: settings.devMode,
                  onChanged: notifier.toggleDevMode,
                ),
              ),
              if (settings.devMode)
                _SettingsRow(
                  icon: Icons.brush_outlined,
                  title: 'Canvas 2.0 (dev)',
                  subtitle: 'Preview the rebuilt drawing canvas',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => context.push('/canvas-demo'),
                ),
            ],
          ),
          const _SectionHeader('About'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.info_outline,
                title: 'About DistillEd',
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                ),
                onTap: () => context.push('/about'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prompts for the user's own HuggingFace token and stores it. A blank result
/// clears it; cancelling changes nothing.
Future<void> _editHuggingFaceToken(BuildContext context, WidgetRef ref) async {
  final current = ref.read(settingsProvider).huggingFaceToken;
  final token = await showDialog<String>(
    context: context,
    builder: (_) => _HuggingFaceTokenDialog(initial: current),
  );
  if (token == null) return;
  await ref.read(settingsProvider.notifier).setHuggingFaceToken(token);
}

class _HuggingFaceTokenDialog extends StatefulWidget {
  final String initial;
  const _HuggingFaceTokenDialog({required this.initial});

  @override
  State<_HuggingFaceTokenDialog> createState() =>
      _HuggingFaceTokenDialogState();
}

class _HuggingFaceTokenDialogState extends State<_HuggingFaceTokenDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  /// Hidden by default — it's a credential, and settings get shown to other
  /// people over a shoulder more often than you'd think.
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('HuggingFace Token'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Some models — like EmbeddingGemma, which powers searching your '
            'notes — are gated: HuggingFace asks you to accept the licence '
            'first.\n\n'
            'Accept it on the model page, create a read token, and paste it '
            'here. It stays on this device and is only ever sent to '
            'HuggingFace to download the model.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'hf_…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscured ? 'Show' : 'Hide',
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.accentRed)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save',
              style: TextStyle(color: AppColors.textOnAccent)),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 64));
      }
      rows.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentWash,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LanguageToggle({required this.value, required this.onChanged});

  static const _options = [('en', 'English'), ('bn', 'বাংলা')];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _options.map((option) {
        final (code, label) = option;
        final selected = value == code;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onChanged(code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentWash : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Shows the downloaded state of the on-device LLM and the handwriting
/// language models, with delete actions to reclaim storage.
class _AiModelsCard extends ConsumerStatefulWidget {
  const _AiModelsCard();

  @override
  ConsumerState<_AiModelsCard> createState() => _AiModelsCardState();
}

class _AiModelsCardState extends ConsumerState<_AiModelsCard> {
  /// Bumped after a delete so the FutureBuilders re-query install status.
  int _refresh = 0;

  @override
  Widget build(BuildContext context) {
    final downloads = ref.read(modelDownloadManagerProvider);
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final sizeGb =
        LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);

    return _SettingsCard(
      children: [
        _modelRow(
          key: ValueKey('llm-$_refresh'),
          icon: Icons.psychology_outlined,
          title: '${LlmModelSpec.active.displayName} (summarization)',
          sizeLabel: '${sizeGb.toStringAsFixed(1)} GB',
          isInstalled: downloads.isInstalled,
          confirmDelete: true,
          onDelete: downloads.delete,
        ),
        _EmbeddingModelRow(
          key: ValueKey('embed-$_refresh'),
          onChanged: () => setState(() => _refresh++),
        ),
        _modelRow(
          key: ValueKey('en-$_refresh'),
          icon: Icons.draw_outlined,
          title: 'English handwriting model',
          sizeLabel: '~20 MB',
          isInstalled: () => recognition.isModelDownloaded('en'),
          onDelete: () => recognition.deleteModel('en'),
        ),
        _modelRow(
          key: ValueKey('bn-$_refresh'),
          icon: Icons.draw_outlined,
          title: 'Bangla handwriting model',
          sizeLabel: '~20 MB',
          isInstalled: () => recognition.isModelDownloaded('bn'),
          onDelete: () => recognition.deleteModel('bn'),
        ),
      ],
    );
  }

  Widget _modelRow({
    required Key key,
    required IconData icon,
    required String title,
    required String sizeLabel,
    required Future<bool> Function() isInstalled,
    required Future<void> Function() onDelete,
    bool confirmDelete = false,
  }) {
    return FutureBuilder<bool>(
      key: key,
      future: isInstalled(),
      builder: (context, snapshot) {
        final installed = snapshot.data ?? false;
        final checking = !snapshot.hasData && !snapshot.hasError;
        return _SettingsRow(
          icon: icon,
          title: title,
          subtitle: checking
              ? 'Checking…'
              : installed
                  ? '$sizeLabel · Downloaded'
                  : 'Not downloaded — fetched on first use',
          trailing: installed
              ? IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.textSecondary),
                  tooltip: 'Delete model',
                  onPressed: () => _delete(onDelete, confirmDelete, title),
                )
              : null,
        );
      },
    );
  }

  Future<void> _delete(
      Future<void> Function() onDelete, bool confirm, String title) async {
    if (confirm) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete model?'),
          content: Text(
              '$title will be removed from this device. It will need to be '
              'downloaded again to summarize notes offline.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.accentRed)),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    await onDelete();
    if (mounted) setState(() => _refresh++);
  }
}

/// The embedding model row. Unlike the fetch-on-first-use rows above, this
/// model is gated and large, so its download is explicit: a button when a token
/// is set, guidance to add one when it isn't, live progress while running, and
/// a delete once installed.
class _EmbeddingModelRow extends ConsumerStatefulWidget {
  /// Called after a state change (download finished, deleted) so the parent can
  /// re-query every model row's install status.
  final VoidCallback onChanged;

  const _EmbeddingModelRow({super.key, required this.onChanged});

  @override
  ConsumerState<_EmbeddingModelRow> createState() => _EmbeddingModelRowState();
}

class _EmbeddingModelRowState extends ConsumerState<_EmbeddingModelRow> {
  int? _progress; // non-null while downloading
  String? _error;

  static const _spec = EmbedderSpec.active;

  Future<void> _download() async {
    final manager = ref.read(embedderDownloadManagerProvider);
    setState(() {
      _progress = 0;
      _error = null;
    });
    final sub = manager.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    try {
      await manager.download();
      if (mounted) widget.onChanged(); // flips the row to "Downloaded"
    } on EmbedderTokenRequiredException catch (e) {
      _fail(e.message);
    } on InsufficientStorageException catch (e) {
      _fail(e.message);
    } on ModelDownloadCancelledException {
      _fail('Download cancelled.');
    } on LlmException catch (e) {
      _fail(e.message);
    } finally {
      await sub.cancel();
      if (mounted) setState(() => _progress = null);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _delete() async {
    await ref.read(embedderDownloadManagerProvider).delete();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = _spec.approxSizeBytes / (1024 * 1024);
    final sizeLabel = '${sizeMb.round()} MB';
    // The effective token, so a local dev token (debug only) also enables the
    // download — not just a token typed into Settings.
    final hasToken = ref.watch(huggingFaceTokenProvider).isNotEmpty;

    if (_progress != null) {
      return _SettingsRow(
        icon: Icons.travel_explore_outlined,
        title: '${_spec.displayName} (search)',
        subtitle: 'Downloading… $_progress%',
        trailing: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: (_progress! > 0) ? _progress! / 100 : null,
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: ref.read(embedderDownloadManagerProvider).isInstalled(),
      builder: (context, snapshot) {
        final installed = snapshot.data ?? false;
        final checking = !snapshot.hasData && !snapshot.hasError;

        final String subtitle;
        if (_error != null) {
          subtitle = _error!;
        } else if (checking) {
          subtitle = 'Checking…';
        } else if (installed) {
          subtitle = '$sizeLabel · Downloaded';
        } else if (!hasToken) {
          subtitle = 'Add a HuggingFace token above to download';
        } else {
          subtitle = '$sizeLabel · Powers semantic search across your notes';
        }

        return _SettingsRow(
          icon: Icons.travel_explore_outlined,
          title: '${_spec.displayName} (search)',
          subtitle: subtitle,
          trailing: installed
              ? IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.textSecondary),
                  tooltip: 'Delete model',
                  onPressed: _delete,
                )
              : TextButton(
                  onPressed: hasToken ? _download : null,
                  child: const Text('Download'),
                ),
        );
      },
    );
  }
}

class _FormatToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FormatToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: SettingsNotifier.exportFormats.map((f) {
        final selected = value == f;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentWash : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
