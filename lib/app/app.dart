// Root application widget — applies theme and sets up routing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/settings_provider.dart';
import 'router.dart';

class InkFlowApp extends ConsumerWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'DistillEd',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: settings.devMode,
      theme: AppTheme.warmTheme,
      routerConfig: appRouter,
    );
  }
}
