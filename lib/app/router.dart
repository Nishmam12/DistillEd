// GoRouter configuration — defines all app routes.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_motion.dart';
import '../features/home/presentation/screens/notes_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/about_screen.dart';
import '../editor/ui/scene_editor_screen.dart';
import '../editor/ui/notebook_editor_screen.dart';
import '../editor/ui/notebook_book_view_screen.dart';
import '../features/ai/presentation/knowledge_graph/knowledge_graph_screen.dart';
import '../features/ai/presentation/study_planner/study_planner_screen.dart';

CustomTransitionPage<void> _fluidPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.standard,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasized,
        reverseCurve: AppMotion.emphasized.flipped,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _fluidPage(
        state: state,
        child: const NotesScreen(),
      ),
    ),
    // Canvas 2.0 — the unified drawing engine, now the default editor.
    GoRoute(
      path: '/note2/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return _fluidPage(
          state: state,
          child: NotebookEditorScreen(notebookId: id),
        );
      },
      routes: [
        GoRoute(
          path: 'book',
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return _fluidPage(
              state: state,
              child: NotebookBookViewScreen(notebookId: id),
            );
          },
        ),
        GoRoute(
          path: 'graph',
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return _fluidPage(
              state: state,
              child: KnowledgeGraphScreen(notebookId: id),
            );
          },
        ),
        GoRoute(
          path: 'plan',
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return _fluidPage(
              state: state,
              child: StudyPlannerScreen(notebookId: id),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _fluidPage(
        state: state,
        child: const SettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) => _fluidPage(
        state: state,
        child: const AboutScreen(),
      ),
    ),
    // Dev-only: unified canvas playground (Phase 2). Surfaced from Settings when
    // Developer Mode is enabled.
    GoRoute(
      path: '/canvas-demo',
      pageBuilder: (context, state) => _fluidPage(
        state: state,
        child: const SceneEditorScreen(),
      ),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) => appRouter);
