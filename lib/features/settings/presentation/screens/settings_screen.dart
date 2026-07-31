import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/ink_colors.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../widgets/app_chip_group.dart';
import '../../../../widgets/app_segmented_control.dart';
import '../../../ai/data/embeddings/embedder_spec.dart';
import '../../../ai/data/llm/hf_token_check.dart';
import '../../../ai/data/llm/llm_exceptions.dart';
import '../../../ai/data/llm/llm_model_spec.dart';
import '../../../ai/data/llm/model_storage_cleaner.dart';
import '../../../home/data/repositories/note_repository.dart';
import '../../../summarize/presentation/summarize_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final c = context.colors;

    return Scaffold(
      // SET-01. The app bar is set explicitly rather than left to the theme,
      // because the app-wide ThemeData is still the pre-migration warm skin —
      // this screen is the first one on the navy/gold tokens.
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: c.bgPrimary,
        foregroundColor: c.accent,
        surfaceTintColor: c.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: c.accent,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        // Same behaviour as the automatic back button (`maybePop`), drawn with
        // the Phosphor arrow so the chrome matches the row glyphs.
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowLeft),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      backgroundColor: c.bgPrimary,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _SectionHeader('Appearance'),
          _SettingsCard(
            children: [
              _ThemeModeRow(
                value: settings.themeMode,
                onChanged: notifier.setThemeMode,
              ),
            ],
          ),
          const _SectionHeader('Notes'),
          _SettingsCard(
            children: [
              // SET-10. Navigation unchanged.
              _SettingsRow(
                icon: PhosphorIconsRegular.trash,
                title: 'Trash',
                subtitle: 'Restore deleted notes for '
                    '${NoteRepository.trashRetention.inDays} days',
                trailing: IconButton(
                  icon: Icon(PhosphorIconsRegular.caretRight,
                      color: c.textSecondary),
                  onPressed: () => context.push('/trash'),
                ),
              ),
            ],
          ),
          const _SectionHeader('Export Defaults'),
          _SettingsCard(
            children: [
              // SET-11.
              _SettingsRow(
                icon: PhosphorIconsRegular.image,
                title: 'Format',
                subtitle: 'Default format when exporting notebooks',
                trailing: AppChipGroup<String>(
                  value: settings.exportDefault,
                  options: [
                    for (final f in SettingsNotifier.exportFormats) (f, f),
                  ],
                  onChanged: notifier.setExportDefault,
                ),
              ),
            ],
          ),
          const _SectionHeader('AI'),
          _SettingsCard(
            children: [
              // SET-12. Presentation only — `setCloudAiEnabled` is untouched.
              _SettingsRow(
                icon: PhosphorIconsRegular.cloud,
                title: 'Cloud AI',
                subtitle:
                    'Allow very long notes to be summarized in the cloud. '
                    'When off, notes never leave this device.',
                trailing: _AccentSwitch(
                  value: settings.cloudAiEnabled,
                  onChanged: notifier.setCloudAiEnabled,
                ),
              ),
              // SET-13.
              _SettingsRow(
                icon: PhosphorIconsRegular.translate,
                title: 'Handwriting Language',
                subtitle: 'Language used to read your notes',
                trailing: AppChipGroup<String>(
                  value: settings.recognitionLanguage,
                  options: const [('en', 'English'), ('bn', 'বাংলা')],
                  onChanged: notifier.setRecognitionLanguage,
                ),
              ),
              // SET-14. Presentation only — token storage and verification are
              // untouched; only the button's colour and the chevron are new.
              _SettingsRow(
                icon: PhosphorIconsRegular.key,
                title: 'HuggingFace Token',
                subtitle: settings.hasHuggingFaceToken
                    ? 'Added — gated models can be downloaded'
                    : 'Needed for gated models like EmbeddingGemma. Your own '
                        'token, kept on this device.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _editHuggingFaceToken(context, ref),
                      child: Text(
                        settings.hasHuggingFaceToken ? 'Change' : 'Add',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ),
                    Icon(PhosphorIconsRegular.caretRight,
                        size: 18, color: c.textSecondary),
                  ],
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
                icon: PhosphorIconsRegular.terminalWindow,
                title: 'Developer Mode',
                subtitle: 'Show performance metrics overlay',
                trailing: _AccentSwitch(
                  value: settings.devMode,
                  onChanged: notifier.toggleDevMode,
                ),
              ),
              if (settings.devMode)
                _SettingsRow(
                  icon: PhosphorIconsRegular.paintBrush,
                  title: 'Canvas 2.0 (dev)',
                  subtitle: 'Preview the rebuilt drawing canvas',
                  trailing: Icon(
                    PhosphorIconsRegular.caretRight,
                    color: c.textSecondary,
                  ),
                  onTap: () => context.push('/canvas-demo'),
                ),
            ],
          ),
          const _SectionHeader('About'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: PhosphorIconsRegular.info,
                title: 'About DistillEd',
                trailing: Icon(
                  PhosphorIconsRegular.caretRight,
                  color: c.textSecondary,
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
  if (!context.mounted) return;

  // Verify the paste immediately rather than letting a typo hide until a
  // 185 MB download dies on it. Reads the token back so the check sees the
  // same sanitised string the download will (`sanitizeToken` strips the
  // whitespace and quotes a browser copy tends to bring along).
  final saved = ref.read(settingsProvider).huggingFaceToken;
  if (saved.isEmpty) return; // cleared — nothing to verify
  final info = await ref.read(huggingFaceIdentityProvider).whoami(saved);
  if (!context.mounted) return;

  final String? message = switch (info.status) {
    HfTokenStatus.valid when info.username != null =>
      'Token verified — signed in as ${info.username}.',
    HfTokenStatus.valid => 'Token verified.',
    HfTokenStatus.invalid =>
      "HuggingFace didn't recognise that token. Check it was copied whole.",
    // Offline or timed out. Saying nothing beats accusing a good token, and
    // the download will re-check anyway.
    HfTokenStatus.unknown => null,
  };
  if (message == null) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Opens [url] in a browser, or tells the user where to go if none exists.
///
/// Every HuggingFace hand-off routes through here so that a device without a
/// browser degrades to a readable URL instead of a button that does nothing.
Future<void> _openHuggingFace(BuildContext context, String url) async {
  final opened = await openExternalUrl(url);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Could not open a browser. Visit $url'),
      action: SnackBarAction(
        label: 'Copy',
        onPressed: () => Clipboard.setData(ClipboardData(text: url)),
      ),
      duration: const Duration(seconds: 8),
    ),
  );
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
      backgroundColor: context.ink.surface,
      title: const Text('HuggingFace Token'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Some models — like EmbeddingGemma, which powers searching your '
            'notes — are gated: HuggingFace asks you to accept the licence '
            'first.\n\n'
            'Both steps happen in your browser, where you are already signed '
            'in. Your token stays on this device and is only ever sent to '
            'HuggingFace to download the model.',
            style: TextStyle(fontSize: 13, color: context.ink.textSecondary),
          ),
          const SizedBox(height: 4),
          // The two steps as taps rather than instructions. Previously this
          // paragraph told the user to visit a page the app gave them no way
          // to reach — and HuggingFace accepts a licence ONLY from a browser,
          // so there is no in-app alternative to offer.
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              children: [
                TextButton(
                  onPressed: () => _openHuggingFace(
                      context, 'https://huggingface.co/settings/tokens/new'
                          '?tokenType=read'),
                  child: const Text('Create a read token'),
                ),
                TextButton(
                  onPressed: () => _openHuggingFace(
                      context, EmbedderSpec.active.modelPageUrl),
                  child: const Text('Accept the licence'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
            child: Text('Remove',
                style: TextStyle(color: context.ink.accentRed)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(color: context.ink.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.ink.accent),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text('Save',
              style: TextStyle(color: context.ink.textOnAccent)),
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
      // SET-02. Section headers are tier-1 accent: there are a handful per
      // screen and each labels a group, so they do not compete the way a
      // repeated row title would.
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          color: context.colors.accent,
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
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        // SET-15. Inset to the text column, not full-bleed: 16 padding +
        // 36 icon tile + 12 gap = 64, so the rule starts under the title and
        // the icon column reads as one continuous strip.
        rows.add(Divider(height: 1, indent: 64, color: c.border));
      }
      rows.add(children[i]);
    }

    // SET-03 / SET-16. Light lifts on a soft shadow with no outline; dark drops
    // the shadow entirely and draws a 1px hairline instead. A shadow on
    // near-black is invisible, so carrying it over would leave dark-mode cards
    // with no edge at all.
    //
    // THEME_SPEC.md defines no shadow token, so the tint is derived from
    // `accent` rather than invented: navy at 6%/4% in light. See the report's
    // spec-gap note.
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: c.border) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
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
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // SET-04. Icon tiles are single-instance chrome — one per row, each
            // labelling a different setting — so they keep the accent without
            // the wall-of-gold problem that repeated titles would have.
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SET-05. `textPrimary`, NOT `accent`. In dark this is cream
                  // (#E6E2DB) over a grey description. The mockup shows gold
                  // titles here; THEME_SPEC.md § "Color hierarchy" overrides it
                  // — thirty gold titles in a list signal nothing.
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
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

/// SET-12. A [Switch] on the spec's tokens.
///
/// THEME_SPEC.md § asymmetries, "Toggle (Cloud AI), on": `accent` track with a
/// WHITE thumb in light and a DARK thumb in dark. That is exactly what
/// `onAccent` means — the colour that sits on a filled accent surface — so the
/// thumb reads the token rather than branching on brightness.
class _AccentSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AccentSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: c.onAccent,
      activeTrackColor: c.accent,
      inactiveThumbColor: c.textSecondary,
      inactiveTrackColor: c.surfaceSubtle,
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.accent : c.border,
      ),
    );
  }
}

/// Theme picker. Laid out as a full-width segmented control below the row
/// rather than as a trailing pill group, because three labelled options plus a
/// title do not fit across a phone.
class _ThemeModeRow extends StatelessWidget {
  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  const _ThemeModeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SET-08. The moon is fixed rather than tracking the current mode: it
        // labels the SETTING ("theme"), and the segmented control below already
        // shows which mode is active. A glyph that changed with the value said
        // the same thing twice and read as a state indicator you could not tap.
        _SettingsRow(
          icon: PhosphorIconsRegular.moon,
          title: 'Theme',
          subtitle: switch (value) {
            AppThemeMode.system => 'Follow system',
            AppThemeMode.light => 'Always light',
            AppThemeMode.dark => 'Always dark',
          },
        ),
        // SET-09. Wired straight to `SettingsNotifier.setThemeMode`, which
        // updates state and persists to SharedPreferences in one call — so the
        // app re-themes live and the choice survives a restart.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: AppSegmentedControl<AppThemeMode>(
            value: value,
            onChanged: onChanged,
            segments: const [
              AppSegment(
                value: AppThemeMode.system,
                label: 'System',
                icon: PhosphorIconsRegular.gear,
              ),
              AppSegment(
                value: AppThemeMode.light,
                label: 'Light',
                icon: PhosphorIconsRegular.sun,
              ),
              AppSegment(
                value: AppThemeMode.dark,
                label: 'Dark',
                icon: PhosphorIconsRegular.moon,
              ),
            ],
          ),
        ),
      ],
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
          icon: PhosphorIconsRegular.brain,
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
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'English handwriting model',
          sizeLabel: '~20 MB',
          isInstalled: () => recognition.isModelDownloaded('en'),
          onDelete: () => recognition.deleteModel('en'),
        ),
        _modelRow(
          key: ValueKey('bn-$_refresh'),
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'Bangla handwriting model',
          sizeLabel: '~20 MB',
          isInstalled: () => recognition.isModelDownloaded('bn'),
          onDelete: () => recognition.deleteModel('bn'),
        ),
        _ReclaimSpaceRow(
          key: ValueKey('reclaim-$_refresh'),
          onChanged: () => setState(() => _refresh++),
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
                  icon: Icon(PhosphorIconsRegular.trash,
                      color: context.colors.textSecondary),
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
              child: Text('Delete',
                  style: TextStyle(color: context.ink.accentRed)),
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

/// What is actually on disk for the embedding model.
enum _InstallState {
  /// Both files present — ready to use.
  installed,

  /// Exactly one file present, left by a failed attempt. Costs real space
  /// (the model file is ~171 MB of the ~175 MB pair) while being unusable.
  partial,

  /// Nothing downloaded.
  absent,
}

class _EmbeddingModelRowState extends ConsumerState<_EmbeddingModelRow>
    with WidgetsBindingObserver {
  int? _progress; // non-null while downloading

  /// The typed failure, not just its text, so `build` can offer the fix that
  /// matches it — a licence problem needs a link to HuggingFace, a dead token
  /// needs the Change button above.
  LlmException? _failure;

  /// Set while the user is away accepting the licence in a browser. Their
  /// return is the signal to re-check: without this the app would sit on a
  /// stale error until they thought to press Retry, which is exactly the
  /// friction the browser hand-off was meant to remove.
  bool _awaitingLicence = false;

  static const _spec = EmbedderSpec.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingLicence) return;
    _awaitingLicence = false;
    _resumeAfterLicence();
  }

  /// Re-asks HuggingFace whether access was granted, and just carries on if it
  /// was. `gated: auto` repos grant access the moment the form is submitted,
  /// so by the time the Custom Tab is dismissed this usually succeeds.
  Future<void> _resumeAfterLicence() async {
    if (!mounted) return;
    setState(() => _failure = null);
    // download() re-runs the same preflight probe, so a still-unaccepted
    // licence lands back on the licence error rather than starting a doomed
    // 185 MB transfer.
    await _download();
  }

  /// Held in state rather than created inside `build`.
  ///
  /// These are platform-channel round trips behind plugin initialization.
  /// Building the future inline meant every rebuild — each progress tick,
  /// theme change, or parent `setState` — fired a fresh one and snapped the
  /// row back to "Checking…" while it resolved. It is recomputed only when
  /// something can actually have changed the answer.
  late Future<_InstallState> _installedCheck = _checkInstalled();

  Future<_InstallState> _checkInstalled() async {
    final manager = ref.read(embedderDownloadManagerProvider);
    if (await manager.isInstalled()) return _InstallState.installed;
    if (await manager.isPartiallyInstalled()) return _InstallState.partial;
    return _InstallState.absent;
  }

  void _refreshInstalled() =>
      setState(() => _installedCheck = _checkInstalled());

  Future<void> _download() async {
    final manager = ref.read(embedderDownloadManagerProvider);
    setState(() {
      _progress = 0;
      _failure = null;
    });
    final sub = manager.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    try {
      await manager.download();
      if (mounted) widget.onChanged(); // flips the row to "Downloaded"
    } on LlmException catch (e) {
      // Every typed download failure — auth, licence, rate limit, storage,
      // network — already carries a message written for the user, so one arm
      // covers them all. See `download_failure.dart`.
      _fail(e);
    } finally {
      await sub.cancel();
      if (mounted) {
        setState(() => _progress = null);
        // A failed download can still have landed one of the two files; re-ask
        // rather than assuming the row's state is unchanged.
        _refreshInstalled();
      }
    }
  }

  void _fail(LlmException failure) {
    if (mounted) setState(() => _failure = failure);
  }

  /// Hands the user to HuggingFace to accept the licence, then waits for them
  /// to come back (see [didChangeAppLifecycleState]).
  Future<void> _acceptLicence(String url) async {
    // Armed before launching, not after: the app can be backgrounded the
    // instant the Custom Tab appears, and a flag set afterwards could miss the
    // resume entirely.
    _awaitingLicence = true;
    final opened = await openExternalUrl(url);
    if (opened) return;
    _awaitingLicence = false;
    if (!mounted) return;
    await _openHuggingFace(context, url); // shows the copyable fallback
  }

  Future<void> _delete() async {
    await ref.read(embedderDownloadManagerProvider).delete();
    if (!mounted) return;
    setState(() => _failure = null);
    _refreshInstalled();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = _spec.approxSizeBytes / (1024 * 1024);
    final sizeLabel = '${sizeMb.round()} MB';
    // The effective token, so a local dev token (debug only) also enables the
    // download — not just a token typed into Settings.
    final hasToken = ref.watch(huggingFaceTokenProvider).isNotEmpty;
    // Settings load from SharedPreferences asynchronously. Until that lands the
    // token reads as '' even when one is stored, so treat "not loaded yet" as
    // unknown rather than as "no token" — otherwise the row briefly tells a
    // user who HAS a token to go add one, and disables the button under them.
    final settingsLoaded = ref.watch(settingsProvider).loaded;

    if (_progress != null) {
      return _SettingsRow(
        icon: PhosphorIconsRegular.magnifyingGlass,
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

    return FutureBuilder<_InstallState>(
      future: _installedCheck,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _InstallState.absent;
        final checking =
            !settingsLoaded || (!snapshot.hasData && !snapshot.hasError);
        final installed = state == _InstallState.installed;
        final partial = state == _InstallState.partial;

        // A gated-model failure the user can fix in one tap, rather than by
        // re-examining a token that is usually fine.
        final licenceUrl = switch (_failure) {
          ModelLicenceNotAcceptedException(:final modelPageUrl) => modelPageUrl,
          ModelTokenScopeException(:final modelPageUrl) => modelPageUrl,
          _ => null,
        };

        final String subtitle;
        if (_failure != null) {
          subtitle = _failure!.message;
        } else if (checking) {
          subtitle = 'Checking…';
        } else if (installed) {
          subtitle = '$sizeLabel · Downloaded';
        } else if (partial) {
          // Say the space is recoverable, because nothing else in the UI would
          // reveal that a failed attempt is still holding most of it.
          subtitle = 'Download incomplete — finish it, or delete to free space';
        } else if (!hasToken) {
          subtitle = 'Add a HuggingFace token above to download';
        } else {
          subtitle = '$sizeLabel · Powers semantic search across your notes';
        }

        return _SettingsRow(
          icon: PhosphorIconsRegular.magnifyingGlass,
          title: '${_spec.displayName} (search)',
          subtitle: subtitle,
          trailing: installed
              ? IconButton(
                  icon: Icon(PhosphorIconsRegular.trash,
                      color: context.colors.textSecondary),
                  tooltip: 'Delete model',
                  onPressed: _delete,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A half-finished attempt is the only not-installed state
                    // that occupies space, so it is the only one that also
                    // gets a delete.
                    if (partial && !checking)
                      IconButton(
                        icon: Icon(PhosphorIconsRegular.trash,
                            color: context.colors.textSecondary),
                        tooltip: 'Delete partial download',
                        onPressed: _delete,
                      ),
                    // Leads, because when it is shown it is the ONLY thing
                    // that unblocks the download — retrying without accepting
                    // the licence just reproduces the same error.
                    if (licenceUrl != null)
                      TextButton(
                        onPressed: () => _acceptLicence(licenceUrl),
                        child: Text(
                          _failure is ModelTokenScopeException
                              ? 'Fix token'
                              : 'Accept licence',
                          style: TextStyle(color: context.colors.accent),
                        ),
                      ),
                    TextButton(
                      // Disabled only once we KNOW there is no token — a
                      // pending settings load must not look like a missing one.
                      onPressed:
                          (hasToken && settingsLoaded) ? _download : null,
                      child: Text(
                        (_failure != null || partial) ? 'Retry' : 'Download',
                        style: TextStyle(
                          // Disabled must read as disabled in BOTH modes: the
                          // enabled accent against `textSecondary` at 40%.
                          color: (hasToken && settingsLoaded)
                              ? context.colors.accent
                              : context.colors.textSecondary
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Offers to reclaim model files sitting on disk that no installed model
/// claims — see [ModelStorageCleaner] for how they come about.
///
/// Renders NOTHING when there is nothing to reclaim, which is the normal case.
/// A permanently-visible "0 B to free" row would be noise in a settings screen,
/// and this is a recovery affordance, not a feature.
class _ReclaimSpaceRow extends ConsumerStatefulWidget {
  /// Called after a cleanup so the parent re-queries every model row — freeing
  /// space can change what is installed.
  final VoidCallback onChanged;

  const _ReclaimSpaceRow({super.key, required this.onChanged});

  @override
  ConsumerState<_ReclaimSpaceRow> createState() => _ReclaimSpaceRowState();
}

class _ReclaimSpaceRowState extends ConsumerState<_ReclaimSpaceRow> {
  /// Cached for the same reason as the model rows': this is a directory scan
  /// behind a platform channel, not something to re-run on every rebuild.
  late Future<List<OrphanedModelFile>> _orphans = _findOrphans();

  bool _busy = false;
  String? _error;

  Future<List<OrphanedModelFile>> _findOrphans() =>
      ref.read(modelStorageCleanerProvider).findOrphans();

  Future<void> _cleanup(List<OrphanedModelFile> orphans) async {
    final freed = orphans.fold<int>(0, (sum, o) => sum + o.sizeBytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.ink.surface,
        title: const Text('Free up space?'),
        content: Text(
          '${orphans.length} leftover file${orphans.length == 1 ? '' : 's'} '
          '(${_formatBytes(freed)}) will be deleted. These are remnants of '
          'downloads that did not finish — the models you have installed are '
          'not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: context.ink.accentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(modelStorageCleanerProvider).cleanup();
      if (!mounted) return;
      setState(() => _orphans = _findOrphans());
      widget.onChanged();
    } on LlmException catch (e) {
      // Includes the refuse-to-delete guard, whose message is the whole point
      // of it firing — surface it rather than silently doing nothing.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    if (bytes >= 1024 * mb) {
      return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / mb).round()} MB';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrphanedModelFile>>(
      future: _orphans,
      builder: (context, snapshot) {
        final orphans = snapshot.data ?? const <OrphanedModelFile>[];
        // Stay invisible until there is genuinely something to offer. A failed
        // scan returns empty too, which is the right silence: we have nothing
        // useful to say and nothing safe to do.
        if (orphans.isEmpty && _error == null) return const SizedBox.shrink();

        final freed = orphans.fold<int>(0, (sum, o) => sum + o.sizeBytes);
        return _SettingsRow(
          icon: PhosphorIconsRegular.broom,
          title: 'Leftover download files',
          subtitle: _error ??
              '${_formatBytes(freed)} from downloads that did not finish',
          trailing: _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed:
                      orphans.isEmpty ? null : () => _cleanup(orphans),
                  child: const Text('Free up'),
                ),
        );
      },
    );
  }
}

