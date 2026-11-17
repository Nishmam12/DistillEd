import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:margo/core/icons/app_icon.dart';
import 'package:margo/core/icons/phosphor_icons_regular.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../widgets/app_chip_group.dart';
import '../../../../widgets/app_segmented_control.dart';
import '../../../ai/data/embeddings/embedder_spec.dart';
import '../../../ai/data/providers/cloud_presets.dart';
import '../../../ai/data/providers/openai_compatible_provider.dart'
    show CloudModel, CloudModelListException, OpenAiCompatibleProvider;
import '../../../ai/data/rag/embedder_mobile_data_choice.dart';
import '../../../ai/data/llm/hf_token_check.dart';
import '../../../ai/data/providers/model_connection_tester.dart';
import '../../../ai/domain/catalog/provider_preset.dart';
import '../../../ai/domain/catalog/user_connection.dart';
import '../../../ai/data/llm/llm_exceptions.dart';
import '../../../ai/data/llm/llm_model_spec.dart';
import '../../../ai/data/llm/model_storage_cleaner.dart';
import '../../../ai/domain/compute_backend.dart';
import '../../../ai/presentation/ai_providers.dart'
    show
        embedderRolloutResumeProvider,
        embedderRolloutRunnerProvider,
        embedderRolloutStatusProvider,
        localBackendProvider,
        modelConnectionTesterProvider,
        userConnectionsProvider;
import '../../../ai/presentation/rag_corpus_export.dart';
import '../../../audio/data/edge_ai_speech.dart';
import '../../../audio/presentation/speech_model_notifier.dart';
import '../../../audio/presentation/transcription_providers.dart';
import '../../../../editor/state/ink_gesture_providers.dart';
import '../../../../editor/tools/ink_gestures.dart'
    show kGestureModel, kShapesModel;
import '../../../../data/backup/backup_service.dart' show BackupTrigger;
import '../../../backup/backup_controller.dart';
import '../../../backup/restore_list_screen.dart';
import '../../../home/data/repositories/note_repository.dart';
import '../../../home/presentation/widgets/search_popover.dart';
import '../../../summarize/presentation/summarize_providers.dart';

part 'settings_widgets.dart';
part 'settings_ai_models.dart';
part 'settings_cloud_models.dart';
part 'settings_maintenance.dart';
part 'settings_backup.dart';
part 'ai_models_screen.dart';
part 'settings_cloud.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final c = context.colors;

    final appearance = _SettingsCard(
      icon: AppIcons.brush,
      title: 'Appearance',
      children: [
        _ThemeModeRow(
          value: settings.themeMode,
          onChanged: notifier.setThemeMode,
        ),
      ],
    );

    final aiAndHandwriting = _SettingsCard(
      icon: AppIcons.flashCircle,
      title: 'AI & Handwriting',
      children: [
        // SET-12. Three-way, because "on" never meant "use the cloud", only
        // "you may fall back to it".
        _AiModeRow(
          value: settings.aiMode,
          onChanged: notifier.setAiMode,
          hasCloudKey: settings.hasCloudKey,
          loaded: settings.loaded,
        ),
        // SET-13.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SettingsRow(
              icon: AppIcons.languageCircle,
              title: 'Handwriting Language',
              subtitle: 'Language used to read your notes',
            ),
            // Below the label: three chips are wider than a trailing slot leaves.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppChipGroup<String>(
                  value: settings.recognitionLanguage,
                  // 'bn-Latn' is Bangla written in English letters
                  // ("ami bhalo achi"), with its own ML Kit model.
                  options: const [
                    ('en', 'English'),
                    ('bn', 'বাংলা'),
                    ('bn-Latn', 'Banglish'),
                  ],
                  onChanged: notifier.setRecognitionLanguage,
                ),
              ),
            ),
          ],
        ),
        // SET-15. Lecture transcripts: the switch makes new recordings WAV and
        // downloads the model; a lecture is transcribed on the device after it
        // stops.
        _LectureTranscriptsRow(),
        _LectureSummaryRow(),
        // The model downloads and the HuggingFace token live on their own screen.
        _SettingsRow(
          icon: AppIcons.flashCircle,
          title: 'AI Models',
          subtitle: 'Select which models can be downloaded',
          onTap: () => context.push('/settings/models'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage',
                style: TextStyle(
                  fontFamily: 'ModulusPro',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: 6),
              AppIcon(AppIcons.arrowRight, size: 20, color: c.textSecondary),
            ],
          ),
        ),
      ],
    );

    final pen = _SettingsCard(
      icon: AppIcons.brush,
      title: 'Pen',
      children: [
        _SettingsRow(
          icon: AppIcons.brush,
          title: 'Draw with finger',
          subtitle: settings.fingerDraws
              ? 'One finger draws. Two fingers scroll and zoom.'
              : 'Only the pen draws. One finger scrolls the page.',
          trailing: _AccentSwitch(
            value: settings.fingerDraws,
            onChanged: notifier.setFingerDraws,
          ),
          onTap: () => notifier.setFingerDraws(!settings.fingerDraws),
        ),
        _SettingsRow(
          icon: AppIcons.brush,
          title: 'Straighten lines',
          subtitle: 'Hold the pen still at the end of a line and it '
              'straightens. Undo brings your line back.',
          trailing: _AccentSwitch(
            value: settings.straightenLines,
            onChanged: notifier.setStraightenLines,
          ),
          onTap: () => notifier.setStraightenLines(!settings.straightenLines),
        ),
        _SettingsRow(
          icon: AppIcons.brush,
          title: 'Snap highlighter to text',
          subtitle: 'Highlight over the printed words of a PDF page or a '
              'photo and the mark lines up with them. Undo brings your '
              'stroke back.',
          trailing: _AccentSwitch(
            value: settings.snapHighlighter,
            onChanged: notifier.setSnapHighlighter,
          ),
          onTap: () => notifier.setSnapHighlighter(!settings.snapHighlighter),
        ),
        // SET-16. Draw-to-shape: hold the pen at the end of a stroke.
        _InkGestureRow(
          icon: AppIcons.addCircle,
          title: 'Snap shapes',
          subtitle:
              'Hold the pen still at the end of a rectangle, circle, '
              'triangle or arrow and it snaps to a clean shape. Undo '
              'brings your drawing back.',
          model: kShapesModel,
          value: settings.snapShapes,
          setEnabled: notifier.setSnapShapes,
        ),
        // SET-17. Scribble-to-erase.
        _InkGestureRow(
          icon: AppIcons.brush,
          title: 'Scribble to erase',
          subtitle:
              'Scrub back and forth over something to wipe it out. '
              'Undo brings it back.',
          model: kGestureModel,
          value: settings.scribbleErase,
          setEnabled: notifier.setScribbleErase,
        ),
      ],
    );

    final exportDefaults = _SettingsCard(
      icon: AppIcons.export,
      title: 'Export defaults',
      children: [
        // SET-11.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Default format when exporting notebooks',
                style: TextStyle(
                  fontFamily: 'ModulusPro',
                  fontSize: 14,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              AppChipGroup<String>(
                value: settings.exportDefault,
                options: [
                  for (final f in SettingsNotifier.exportFormats) (f, f),
                ],
                onChanged: notifier.setExportDefault,
              ),
            ],
          ),
        ),
      ],
    );

    final notesAndStorage = _SettingsCard(
      icon: AppIcons.trash,
      title: 'Notes & Storage',
      children: [
        // SET-10. Navigation unchanged.
        _SettingsRow(
          icon: AppIcons.trash,
          title: 'Trash',
          subtitle:
              'Restore deleted notes for '
              '${NoteRepository.trashRetention.inDays} days',
          onTap: () => context.push('/trash'),
          trailing: AppIcon(
            AppIcons.arrowRight,
            size: 20,
            color: c.textSecondary,
          ),
        ),
      ],
    );

    final about = _SettingsCard(
      icon: AppIcons.infoCircle,
      title: 'About margo',
      children: [
        _SettingsRow(
          icon: AppIcons.infoCircle,
          title: 'About Margo',
          onTap: () => context.push('/about'),
          trailing: AppIcon(
            AppIcons.arrowRight,
            size: 20,
            color: c.textSecondary,
          ),
        ),
      ],
    );

    // Developer tools are debug-only; release builds never show them.
    final developer = _SettingsCard(
      icon: AppIcons.setting,
      title: 'Developer',
      children: [
        _SettingsRow(
          icon: AppIcons.setting,
          title: 'Developer Mode',
          subtitle: 'Show performance metrics overlay',
          trailing: _AccentSwitch(
            value: settings.devMode,
            onChanged: notifier.toggleDevMode,
          ),
        ),
        if (settings.devMode)
          _SettingsRow(
            icon: AppIcons.brush,
            title: 'Canvas 2.0 (dev)',
            subtitle: 'Preview the rebuilt drawing canvas',
            trailing: AppIcon(
              AppIcons.arrowRight,
              size: 20,
              color: c.textSecondary,
            ),
            onTap: () => context.push('/canvas-demo'),
          ),
        if (settings.devMode)
          _SettingsRow(
            icon: AppIcons.setting,
            title: 'Figure benchmark (dev)',
            subtitle: 'Measure how well the AI reads figures',
            trailing: AppIcon(
              AppIcons.arrowRight,
              size: 20,
              color: c.textSecondary,
            ),
            onTap: () => context.push('/figure-benchmark'),
          ),
      ],
    );

    // Backup sits under AI on the left: it balances the columns and keeps the
    // one setting that protects every note near the top.
    final left = [appearance, aiAndHandwriting, const _BackupSection()];
    final right = [
      pen,
      exportDefaults,
      notesAndStorage,
      about,
      if (kDebugMode) developer,
    ];

    return Scaffold(
      appBar: settingsAppBar(
        context,
        'Settings',
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchPopoverButton(
                onOpenNote: (note) => context.push('/note2/${note.id}'),
              ),
              const SizedBox(width: 8),
              AppIconButton(
                AppIcons.profile,
                size: 36,
                tooltip: 'About',
                onPressed: () => context.push('/about'),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      backgroundColor: c.bgPrimary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final gutter = wide ? 63.0 : 16.0;
          final cards = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 619,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _spaced(left),
                      ),
                    ),
                    const SizedBox(width: 27),
                    Expanded(
                      flex: 508,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _spaced(right),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _spaced([...left, ...right]),
                );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cards,
                const SizedBox(height: 24),
                const SettingsSavedFooter(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Puts a gap between cards, and none before the first.
List<Widget> _spaced(List<Widget> cards) => [
  for (var i = 0; i < cards.length; i++) ...[
    if (i > 0) const SizedBox(height: 24),
    cards[i],
  ],
];

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
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Prompts for the cloud AI provider, model and key. The dialog checks a new
/// key before it closes, so whatever comes back is saved as is: the provider
/// first, then the key, so [SettingsState.hasCloudKey] turns true last.
Future<void> _editCloudProvider(BuildContext context, WidgetRef ref) async {
  final s = ref.read(settingsProvider);
  final result = await showDialog<CloudProviderResult>(
    context: context,
    builder: (_) => CloudProviderDialog(
      presetId: s.cloudPresetId,
      baseUrl: s.cloudBaseUrl,
      model: s.cloudModel,
      hasKey: s.cloudApiKey.trim().isNotEmpty,
    ),
  );
  if (result == null) return;
  final notifier = ref.read(settingsProvider.notifier);
  if (result.clearKey) {
    final removed = await notifier.setCloudApiKey('');
    if (!removed && context.mounted) {
      _showCloudSnack(context, 'Could not remove the key from this device.');
    }
    return;
  }
  // A key saved for another provider must never be live against the new one,
  // not even for the moment between the two saves below: clear it first.
  final providerChanged = result.presetId != s.cloudPresetId ||
      result.baseUrl != s.cloudBaseUrl;
  if (providerChanged && result.newKey != null) {
    final cleared = await notifier.setCloudApiKey('');
    if (!cleared) {
      // Saving the new provider now would pair the old key with it, if the
      // keystore refuses this delete but later reads the old key back.
      if (context.mounted) {
        _showCloudSnack(
          context,
          'Could not clear the old key on this device, so the provider was not changed.',
        );
      }
      return;
    }
  }
  await notifier.setCloudProvider(
    presetId: result.presetId,
    baseUrl: result.baseUrl,
    model: result.model,
    contextTokens: result.contextTokens,
  );
  final newKey = result.newKey;
  if (newKey == null) return;
  final ok = await notifier.setCloudApiKey(newKey);
  if (ok || !context.mounted) return;
  _showCloudSnack(
    context,
    'Could not save the key on this device. It will last until the app closes.',
  );
}

void _showCloudSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Opens [url] in a browser, or tells the user where to go if none exists.
///
/// Every HuggingFace and cloud key page hand-off routes through here so that a device without a
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
