part of 'settings_screen.dart';

/// The AI models screen: the HuggingFace token, then every model that can be
/// downloaded. Reached from the "AI Models" row on the settings page.
///
/// This is a part of the settings library rather than a free-standing file
/// because the model rows and the token dialog are private to it.
class AiModelsScreen extends ConsumerWidget {
  const AiModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final c = context.colors;

    return Scaffold(
      appBar: settingsAppBar(context, 'AI Models'),
      backgroundColor: c.bgPrimary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 910),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AiModelsCard(
                  leading: [
                    // SET-14. Token storage and verification are unchanged; only
                    // the row's place and styling are new.
                    _SettingsRow(
                      icon: AppIcons.key,
                      title: 'HuggingFace Token',
                      subtitle: settings.hasHuggingFaceToken
                          ? 'Added - gated models can be downloaded'
                          : 'Needed for gated models like EmbeddingGemma. Your '
                                'own token, kept on this device.',
                      trailing: TextButton(
                        onPressed: () => _editHuggingFaceToken(context, ref),
                        child: Text(
                          settings.hasHuggingFaceToken ? 'Change' : 'Add',
                          style: TextStyle(
                            fontFamily: 'ModulusPro',
                            fontWeight: FontWeight.w600,
                            color: c.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SettingsSavedFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
