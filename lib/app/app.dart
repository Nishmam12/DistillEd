// Root application widget — applies theme and sets up routing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/settings_provider.dart';
import 'router.dart';

class InkFlowApp extends ConsumerStatefulWidget {
  const InkFlowApp({super.key});

  @override
  ConsumerState<InkFlowApp> createState() => _InkFlowAppState();
}

class _InkFlowAppState extends ConsumerState<InkFlowApp> {
  Brightness? _lastBrightness;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final brightness = settings.darkMode ? Brightness.dark : Brightness.light;

    // Building the theme installs the matching palette, so the `AppColors`
    // and `NotesPalette` tokens read the right values for the rest of the
    // frame.
    final theme = AppTheme.themeFor(brightness);

    if (_lastBrightness != null && _lastBrightness != brightness) {
      _repaintEverything();
    }
    _lastBrightness = brightness;

    return MaterialApp.router(
      title: 'DistillEd',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: settings.devMode,
      theme: theme,
      routerConfig: appRouter,
    );
  }

  /// Marks every element below the root dirty so the whole tree repaints.
  ///
  /// The app styles itself from `AppColors` / `NotesPalette` statics rather
  /// than `Theme.of(context)`, so a `ThemeData` swap on its own repaints
  /// almost nothing. A rebuild isn't enough either: when a parent rebuilds,
  /// Flutter skips any child whose widget is unchanged, and `const` widgets
  /// are canonicalized, so they always compare equal and keep their old
  /// colors. Re-keying the root doesn't reach them either — GoRouter holds
  /// the route subtrees across a `Router` rebuild, which is how the Notes
  /// header stayed light on a dark canvas.
  ///
  /// Dirtying each element directly sidesteps that skip: an element marked
  /// dirty rebuilds whether or not its widget changed. This is the cost of
  /// theming through globals; if the app ever moves its tokens onto
  /// `Theme.of(context)`, this can go.
  void _repaintEverything() {
    // markNeedsBuild during a build throws, so wait for the frame to end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void dirty(Element e) {
        e.markNeedsBuild();
        e.visitChildren(dirty);
      }

      (context as Element).visitChildren(dirty);
    });
  }
}
