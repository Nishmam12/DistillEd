part of 'settings_screen.dart';

class _HuggingFaceTokenDialog extends StatefulWidget {
  final String initial;
  const _HuggingFaceTokenDialog({required this.initial});

  @override
  State<_HuggingFaceTokenDialog> createState() =>
      _HuggingFaceTokenDialogState();
}

class _HuggingFaceTokenDialogState extends State<_HuggingFaceTokenDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

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
      backgroundColor: context.colors.surface,
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
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
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
                    context,
                    'https://huggingface.co/settings/tokens/new'
                    '?tokenType=read',
                  ),
                  child: const Text('Create a read token'),
                ),
                TextButton(
                  onPressed: () => _openHuggingFace(
                    context,
                    EmbedderSpec.active.modelPageUrl,
                  ),
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
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.colors.accent),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text('Save', style: TextStyle(color: context.colors.onAccent)),
        ),
      ],
    );
  }
}

/// Shared chrome for the settings screens: the 42px title bar, the saved footer
/// and the header-less cards are all drawn from here so the two screens match.
PreferredSizeWidget settingsAppBar(
  BuildContext context,
  String title, {
  List<Widget> actions = const [],
}) {
  final c = context.colors;
  return AppBar(
    toolbarHeight: 88,
    titleSpacing: 0,
    title: Text(title),
    backgroundColor: c.bgPrimary,
    foregroundColor: c.textPrimary,
    surfaceTintColor: c.bgPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      fontFamily: 'ModulusPro',
      color: c.textPrimary,
      fontSize: 42,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    // Same behaviour as the automatic back button (`maybePop`), drawn with the
    // Phosphor arrow: it has no exported SVG.
    leading: Navigator.of(context).canPop()
        ? IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,
    actions: actions,
  );
}

/// "Settings are saved automatically", shown at the foot of both settings
/// screens. Settings persist on every change, so there is no save button.
class SettingsSavedFooter extends StatelessWidget {
  const SettingsSavedFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        // Material's check glyph: Phosphor has no tick-circle in this build and
        // the exported SVG set does not carry one.
        Icon(Icons.check_circle_outline, size: 20, color: c.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Settings are saved automatically',
            style: TextStyle(
              fontFamily: 'ModulusPro',
              fontSize: 16,
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  /// Card header. Both null for a header-less card (the AI models list).
  final String? icon;
  final String? title;
  final List<Widget> children;

  const _SettingsCard({this.icon, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        // Inset to the text column: 16 padding + 38 icon tile + 12 gap = 66.
        rows.add(Divider(height: 1, indent: 66, color: c.border));
      }
      rows.add(children[i]);
    }

    // Light lifts on a sage-tinted shadow with no outline; dark drops the shadow
    // (invisible on near-black) and draws a hairline instead.
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null && title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  AppIcon(icon!, size: 28, color: c.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontFamily: 'ModulusPro',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...rows,
        ],
      ),
    );
  }
}

/// A switch for one of the ink gestures. Turning it on downloads its (small) ML
/// Kit model; a failed download turns it back off, so it never looks on while
/// doing nothing.
class _InkGestureRow extends ConsumerWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String model;
  final bool value;
  final Future<void> Function(bool) setEnabled;

  const _InkGestureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.model,
    required this.value,
    required this.setEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: (on) async {
          if (!on) {
            await setEnabled(false);
            return;
          }
          final problem = await enableInkGesture(
            setEnabled: setEnabled,
            downloadModel: () => ref
                .read(handwritingRecognitionServiceProvider)
                .ensureModelDownloaded(model),
          );
          if (problem != null && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(problem)));
          }
        },
      ),
    );
  }
}

/// "Summarise lectures": after a transcript, a study summary of its page, made
/// on the device. Only means something while transcripts are on.
class _LectureSummaryRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcribing =
        ref.watch(settingsProvider.select((s) => s.transcribeLectures));
    final on = ref.watch(settingsProvider.select((s) => s.summarizeLectures));
    return _SettingsRow(
      icon: AppIcons.mic,
      title: 'Summarise lectures',
      subtitle: transcribing
          ? 'After a transcript, a study summary of the page, made on this device'
          : 'Needs lecture transcripts on',
      trailing: Switch(
        value: on && transcribing,
        onChanged: transcribing
            ? ref.read(settingsProvider.notifier).setSummarizeLectures
            : null,
      ),
    );
  }
}

/// "Transcribe lectures": a switch whose subtitle follows the speech model's
/// download. Turning it on starts that download; a failed one is retried by
/// tapping the row.
class _LectureTranscriptsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider.select((s) => s.transcribeLectures));
    final model = ref.watch(speechModelProvider);
    final settings = ref.read(settingsProvider.notifier);
    final speech = ref.read(speechModelProvider.notifier);
    // The model state already carries a failure; this only keeps an escaped
    // error from becoming an unhandled async exception.
    Future<void> download() async {
      try {
        await speech.download();
      } catch (_) {}
    }

    return _SettingsRow(
      icon: AppIcons.mic,
      title: 'Transcribe lectures',
      subtitle: lectureTranscriptsSubtitle(on: on, model: model),
      onTap: on && model.phase == SpeechModelPhase.failed ? download : null,
      trailing: Switch(
        value: on,
        onChanged: (value) {
          settings.setTranscribeLectures(value);
          if (value) download();
        },
      ),
    );
  }
}

/// Whether a new search model may download over mobile data. Off means it waits
/// for Wi-Fi; switching on lets a waiting download go ahead at once.
class _MobileDataRow extends ConsumerStatefulWidget {
  const _MobileDataRow();

  @override
  ConsumerState<_MobileDataRow> createState() => _MobileDataRowState();
}

class _MobileDataRowState extends ConsumerState<_MobileDataRow> {
  MobileDataChoice _choice = MobileDataChoice.ask;

  @override
  void initState() {
    super.initState();
    loadMobileDataChoice().then((c) {
      if (mounted) setState(() => _choice = c);
    });
  }

  Future<void> _set(bool allow) async {
    final choice = allow ? MobileDataChoice.allow : MobileDataChoice.wifiOnly;
    setState(() => _choice = choice);
    await saveMobileDataChoice(choice);
    ref.invalidate(embedderRolloutResumeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final allow = _choice == MobileDataChoice.allow;
    return _SettingsRow(
      icon: AppIcons.cloud,
      title: 'Download model updates on mobile data',
      subtitle: switch (_choice) {
        MobileDataChoice.allow => 'On - updates download on any network',
        MobileDataChoice.wifiOnly => 'Off - updates wait for Wi-Fi',
        MobileDataChoice.ask =>
          'Not set - you are asked when an update needs it',
      },
      trailing: Switch(value: allow, onChanged: _set),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  /// An [AppIcons] name, drawn in the accent on a 38px circle.
  final String icon;
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
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: AppIcon(icon, size: 20, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row titles take `textPrimary`, never `accent`: a card of
                  // gold titles signals nothing (THEME_SPEC.md, "Color hierarchy").
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'ModulusPro',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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

/// Theme picker: the segmented control, then a preview drawn from the live
/// tokens so the choice shows what it will look like before it is kept.
class _ThemeModeRow extends StatelessWidget {
  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  const _ThemeModeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SET-09. Wired straight to `SettingsNotifier.setThemeMode`, which
          // updates state and persists in one call.
          AppSegmentedControl<AppThemeMode>(
            value: value,
            onChanged: onChanged,
            segments: const [
              AppSegment(value: AppThemeMode.system, label: 'System'),
              AppSegment(value: AppThemeMode.light, label: 'Light'),
              AppSegment(value: AppThemeMode.dark, label: 'Dark'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ThemeSwatch(color: c.bgPrimary),
                    const SizedBox(width: 5),
                    // Light matches the mockup (pale sage). In dark,
                    // surfaceSubtle is within a few shades of the card, so
                    // the swatch shows the sage accent the caption names.
                    _ThemeSwatch(color: dark ? c.accent : c.surfaceSubtle),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  dark ? 'Dark sage' : 'Warm white with Sage accents',
                  style: TextStyle(
                    fontFamily: 'ModulusPro',
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final Color color;
  const _ThemeSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      // The hairline keeps a swatch visible when its colour is close to the
      // card's, as bgPrimary is in dark.
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.border),
      ),
    );
  }
}

/// Where the AI runs. A labelling row, then the segmented control that carries
/// the state.
///
/// The subtitles state the privacy consequence of each mode in the mode's own
/// terms, because "Cloud AI: on" told the student nothing about whether their
/// notes were being sent anywhere.
class _AiModeRow extends StatelessWidget {
  final AiProcessingMode value;
  final ValueChanged<AiProcessingMode> onChanged;

  /// A cloud mode does nothing without a key, so the row says so. Waits for
  /// [loaded]: before the keystore is read, every key looks missing.
  final bool hasCloudKey;
  final bool loaded;

  const _AiModeRow({
    required this.value,
    required this.onChanged,
    required this.hasCloudKey,
    required this.loaded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsRow(
          icon: AppIcons.cloud,
          title: 'AI processing',
          subtitle: switch (value) {
            AiProcessingMode.onDevice =>
              'Everything runs on this device. Notes never leave it.',
            AiProcessingMode.auto =>
              'On-device first; the cloud only when it fails or the note is '
                  'too long.',
            AiProcessingMode.cloudFirst =>
              'The cloud reads your notes directly. Faster, but pages are '
                  'sent off this device.',
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSegmentedControl<AiProcessingMode>(
                value: value,
                onChanged: onChanged,
                segments: const [
                  AppSegment(
                    value: AiProcessingMode.onDevice,
                    label: 'On-device',
                  ),
                  AppSegment(value: AiProcessingMode.auto, label: 'Auto'),
                  AppSegment(
                    value: AiProcessingMode.cloudFirst,
                    label: 'Cloud',
                  ),
                ],
              ),
              if (loaded && value.allowsCloud && !hasCloudKey) ...[
                const SizedBox(height: 8),
                Text(
                  'Cloud modes need a key. Add one under Cloud AI provider.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
