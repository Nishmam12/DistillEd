part of 'settings_screen.dart';

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

/// A switch for one of the ink gestures. Turning it on downloads its (small) ML
/// Kit model; a failed download turns it back off, so it never looks on while
/// doing nothing.
class _InkGestureRow extends ConsumerWidget {
  final IconData icon;
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
      icon: PhosphorIconsRegular.microphone,
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
      icon: PhosphorIconsRegular.cellSignalFull,
      title: 'Download model updates on mobile data',
      subtitle: switch (_choice) {
        MobileDataChoice.allow => 'On — updates download on any network',
        MobileDataChoice.wifiOnly => 'Off — updates wait for Wi-Fi',
        MobileDataChoice.ask => 'Not set — you are asked when an update needs it',
      },
      trailing: Switch(value: allow, onChanged: _set),
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

/// Where the AI runs. Mirrors [_ThemeModeRow]: a labelling row, then the
/// segmented control that actually carries the state.
///
/// The subtitles state the privacy consequence of each mode in the mode's own
/// terms, because "Cloud AI: on" told the student nothing about whether their
/// notes were being sent anywhere — the complaint this control exists to fix.
class _AiModeRow extends StatelessWidget {
  final AiProcessingMode value;
  final ValueChanged<AiProcessingMode> onChanged;

  const _AiModeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsRow(
          icon: PhosphorIconsRegular.cloud,
          title: 'AI processing',
          subtitle: switch (value) {
            AiProcessingMode.onDevice =>
              'Everything runs on this device. Notes never leave it.',
            AiProcessingMode.auto =>
              'On-device first; the cloud only when it fails or the note is '
                  'too long.',
            AiProcessingMode.cloudFirst =>
              'The cloud reads your notes directly — faster, but pages are '
                  'sent off this device.',
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: AppSegmentedControl<AiProcessingMode>(
            value: value,
            onChanged: onChanged,
            segments: const [
              AppSegment(
                value: AiProcessingMode.onDevice,
                label: 'On-device',
                icon: PhosphorIconsRegular.deviceMobile,
              ),
              AppSegment(
                value: AiProcessingMode.auto,
                label: 'Auto',
                icon: PhosphorIconsRegular.sparkle,
              ),
              AppSegment(
                value: AiProcessingMode.cloudFirst,
                label: 'Cloud',
                icon: PhosphorIconsRegular.cloud,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

