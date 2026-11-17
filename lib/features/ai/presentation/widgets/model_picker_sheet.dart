// Where the student chooses who answers: auto, the on-device model, or a cloud
// model.
//
// Two rules shape it.
//   • Picking a cloud model never switches cloud AI on by itself. With cloud AI
//     off the student is asked first, and a yes turns on "auto" — on-device
//     first — never "cloud first", which also changes where pages are read.
//   • The pick is about ANSWERS only. The footer says so, because "I picked my
//     own model" is easily read as "everything now uses it", and reading and
//     analysing pages in the background deliberately does not.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/catalog/ai_model_entry.dart';
import '../../domain/catalog/answer_route.dart';
import '../ai_providers.dart';

/// Opens the model picker over [context].
Future<void> showModelPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ModelPickerSheet(),
    );

/// What the header button and its tooltip call the current pick.
String answerModelLabel(String answerModelId, List<AiModelEntry> catalogue) {
  if (answerModelId == kAnswerLocal) return 'On-device (Gemma)';
  for (final entry in catalogue) {
    if (entry.id == answerModelId && entry.pickable) return entry.displayName;
  }
  return 'Auto';
}

/// The button in the AI panel's header that opens the picker. Its tooltip names
/// who is answering now, and it takes the accent colour while that is a cloud
/// model, so a glance says whether what is asked next leaves the device.
class AnswerModelButton extends ConsumerWidget {
  const AnswerModelButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final route = resolveAnswerRoute(
      aiMode: settings.aiMode,
      privacy: settings.cloudPrivacy,
      answerModelId: settings.answerModelId,
      catalogue: ref.watch(modelCatalogueProvider),
    );
    final label = switch (route) {
      LocalOnly() => 'the on-device model',
      LocalFirst() => 'Auto (on-device first)',
      CloudDirect(:final model) => model.displayName,
    };
    return IconButton(
      key: const ValueKey('aiPanelModelPicker'),
      tooltip: 'Answering with $label. Tap to change',
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(
        Icons.psychology_outlined,
        size: 20,
        color: route is CloudDirect
            ? context.colors.accent
            : context.colors.textSecondary,
      ),
      onPressed: () => showModelPicker(context),
    );
  }
}

class _ModelPickerSheet extends ConsumerStatefulWidget {
  const _ModelPickerSheet();

  @override
  ConsumerState<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<_ModelPickerSheet> {
  /// True when the stored pick named a model that can no longer answer. Said
  /// once, here, and the stored pick is reset so it is not said again.
  bool _pickWasLost = false;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(settingsProvider).answerModelId;
    if (!answerChoiceIsUsable(stored, ref.read(modelCatalogueProvider))) {
      _pickWasLost = true;
      // After the first frame: a provider must not be changed while building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(settingsProvider.notifier).setAnswerModelId(kAnswerAuto);
      });
    }
  }

  Future<void> _pick(String id, {AiModelEntry? cloud}) async {
    final notifier = ref.read(settingsProvider.notifier);
    if (cloud != null && !ref.read(settingsProvider).cloudAiEnabled) {
      final turnOn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn on cloud AI?'),
          content: Text(
            'Cloud AI is off, so nothing you ask leaves this device. Turn it '
            'on to answer with ${cloud.displayName}? You are still asked '
            'before anything is sent.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (turnOn != true) return;
      await notifier.setCloudAiEnabled(true);
    }
    await notifier.setAnswerModelId(id);
    if (mounted) Navigator.of(context).maybePop();
  }

  void _addAnAi() {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).maybePop();
    router?.push('/settings/models/add');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final catalogue = ref.watch(modelCatalogueProvider);
    final cloudOn = settings.cloudAiEnabled;
    final current = answerChoiceIsUsable(settings.answerModelId, catalogue)
        ? settings.answerModelId
        : kAnswerAuto;

    final mine = [
      for (final e in catalogue)
        if (e.source == ModelSource.userKey) e,
    ];
    final margo = [
      for (final e in catalogue)
        if (e.source == ModelSource.margo) e,
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Answer with',
                  style: TextStyle(
                    fontFamily: 'ModulusPro',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (_pickWasLost)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'The model you picked is no longer available, so this is '
                    'back on Auto.',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              _Choice(
                title: 'Auto',
                subtitle: 'On your device first',
                selected: current == kAnswerAuto,
                onTap: () => _pick(kAnswerAuto),
              ),
              _Choice(
                title: 'On-device (Gemma)',
                subtitle: 'Nothing you ask leaves this device',
                selected: current == kAnswerLocal,
                onTap: () => _pick(kAnswerLocal),
              ),
              for (final entry in mine)
                _Choice(
                  title: entry.displayName,
                  subtitle: cloudOn
                      ? 'Your key · ${entry.host ?? 'cloud'}'
                      : 'Your key · cloud AI is off, tap to turn it on',
                  selected: current == entry.id,
                  onTap: () => _pick(entry.id, cloud: entry),
                ),
              for (final entry in margo)
                _Choice(
                  title: entry.displayName,
                  subtitle: entry.locked ? 'Premium · Coming soon' : 'Coming soon',
                  selected: false,
                  onTap: entry.pickable
                      ? () => _pick(entry.id, cloud: entry)
                      : null,
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addAnAi,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add an AI with your own key'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'This is who answers what you ask: questions, explanations, '
                  'summaries, quizzes and flashcards. Reading and analysing '
                  'your pages in the background stays on this device and never '
                  'uses your key.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;

  /// Null for a model that cannot be picked yet.
  final VoidCallback? onTap;

  const _Choice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? c.accent : c.textSecondary,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: enabled ? c.textPrimary : c.textSecondary,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: c.textSecondary),
      ),
    );
  }
}
