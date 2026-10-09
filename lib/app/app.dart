// Root application widget — applies the light/dark themes and the persisted
// theme mode, and sets up routing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/settings_provider.dart';
import '../features/ai/presentation/ai_providers.dart';
import '../features/ai/data/embeddings/embedder_spec.dart';
import '../features/ai/data/rag/embedder_mobile_data_choice.dart';
import 'router.dart';

class InkFlowApp extends ConsumerWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the two fields that affect the MaterialApp, so unrelated
    // settings edits (the HuggingFace token, say) don't rebuild the whole app.
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final devMode = ref.watch(settingsProvider.select((s) => s.devMode));

    ref.read(modelLifecycleReleaserProvider);
    ref.read(embedderRolloutResumeProvider); // starts/resumes an embedder switch
    ref.listen(embedderMobileDataPromptProvider, (_, asking) {
      if (!asking) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;
        final mb = (EmbedderSpec.active.approxSizeBytes / (1024 * 1024)).round();
        final useMobile = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Download the updated search model?'),
            content: Text(
                'Searching your notes needs a new $mb MB model. You are on '
                'mobile data. Download it now, or wait until you are on Wi-Fi?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Wait for Wi-Fi')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Use mobile data')),
            ],
          ),
        );
        await saveMobileDataChoice(
            useMobile == true ? MobileDataChoice.allow : MobileDataChoice.wifiOnly);
        ref.read(embedderMobileDataPromptProvider.notifier).state = false;
        ref.invalidate(embedderRolloutResumeProvider);
      });
    });

    return MaterialApp.router(
      title: 'DistillEd',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: devMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode.toThemeMode,
      routerConfig: appRouter,
    );
  }
}
