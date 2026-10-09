import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/icons/phosphor_icons_regular.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/ink_colors.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../widgets/app_chip_group.dart';
import '../../../../widgets/app_segmented_control.dart';
import '../../../ai/data/embeddings/embedder_dry_run_copy.dart';
import '../../../ai/data/embeddings/embedder_spec.dart';
import '../../../ai/data/rag/embedder_mobile_data_choice.dart';
import '../../../ai/data/llm/hf_token_check.dart';
import '../../../ai/data/llm/llm_exceptions.dart';
import '../../../ai/data/llm/llm_model_spec.dart';
import '../../../ai/data/llm/model_storage_cleaner.dart';
import '../../../ai/domain/compute_backend.dart';
import '../../../ai/presentation/ai_providers.dart'
    show
        dryRunCopyInstalledProvider,
        embedderRolloutResumeProvider,
        embedderRolloutRunnerProvider,
        embedderRolloutStatusProvider,
        localBackendProvider;
import '../../../ai/presentation/rag_corpus_export.dart';
import '../../../audio/data/edge_ai_speech.dart';
import '../../../audio/presentation/speech_model_notifier.dart';
import '../../../audio/presentation/transcription_providers.dart';
import '../../../../editor/state/ink_gesture_providers.dart';
import '../../../../editor/tools/ink_gestures.dart' show kGestureModel, kShapesModel;
import '../../../home/data/repositories/note_repository.dart';
import '../../../summarize/presentation/summarize_providers.dart';

part 'settings_widgets.dart';
part 'settings_ai_models.dart';
part 'settings_maintenance.dart';

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
          const _SectionHeader('Pen'),
          _SettingsCard(
            children: [
              // SET-16. Draw-to-shape: hold the pen at the end of a stroke.
              _InkGestureRow(
                icon: PhosphorIconsRegular.shapes,
                title: 'Snap shapes',
                subtitle: 'Hold the pen still at the end of a rectangle, circle, '
                    'triangle or arrow and it snaps to a clean shape. Undo '
                    'brings your drawing back.',
                model: kShapesModel,
                value: settings.snapShapes,
                setEnabled: notifier.setSnapShapes,
              ),
              // SET-17. Scribble-to-erase.
              _InkGestureRow(
                icon: PhosphorIconsRegular.eraser,
                title: 'Scribble to erase',
                subtitle: 'Scrub back and forth over something to wipe it out. '
                    'Undo brings it back.',
                model: kGestureModel,
                value: settings.scribbleErase,
                setEnabled: notifier.setScribbleErase,
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
              // SET-12. Three-way, because the old switch could not express the
              // difference students actually asked about: "on" never meant
              // "use the cloud", only "you may fall back to it".
              _AiModeRow(
                value: settings.aiMode,
                onChanged: notifier.setAiMode,
              ),
              // SET-13.
              _SettingsRow(
                icon: PhosphorIconsRegular.translate,
                title: 'Handwriting Language',
                subtitle: 'Language used to read your notes',
                trailing: AppChipGroup<String>(
                  value: settings.recognitionLanguage,
                  // 'bn-Latn' is Bangla written in English letters ("ami bhalo achi") — its
                  // own ML Kit model, which reads those words far better than the
                  // English one does.
                  options: const [
                    ('en', 'English'),
                    ('bn', 'বাংলা'),
                    ('bn-Latn', 'Banglish'),
                  ],
                  onChanged: notifier.setRecognitionLanguage,
                ),
              ),
              // SET-15. Lecture transcripts: the switch makes new recordings
              // WAV (the format the speech model reads) and downloads the
              // model; a lecture is transcribed on the device after it stops.
              _LectureTranscriptsRow(),
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

