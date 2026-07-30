// Root application widget — applies the light/dark themes and the persisted
// theme mode, and sets up routing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/settings_provider.dart';
import 'router.dart';

class InkFlowApp extends ConsumerWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the two fields that affect the MaterialApp, so unrelated
    // settings edits (the HuggingFace token, say) don't rebuild the whole app.
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final devMode = ref.watch(settingsProvider.select((s) => s.devMode));

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
