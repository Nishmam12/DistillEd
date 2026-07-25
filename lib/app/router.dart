// GoRouter configuration — defines all app routes.

import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/presentation/screens/notes_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/about_screen.dart';
import '../editor/ui/scene_editor_screen.dart';
import '../editor/ui/notebook_editor_screen.dart';
import '../editor/ui/notebook_book_view_screen.dart';
import '../features/ai/presentation/knowledge_graph/knowledge_graph_screen.dart';
import '../features/ai/presentation/study_planner/study_planner_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const NotesScreen(),
    ),
    // Canvas 2.0 — the unified drawing engine, now the default editor.
    GoRoute(
      path: '/note2/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return NotebookEditorScreen(notebookId: id);
      },
      routes: [
        GoRoute(
          path: 'book',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return NotebookBookViewScreen(notebookId: id);
          },
        ),
        GoRoute(
          path: 'graph',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return KnowledgeGraphScreen(notebookId: id);
          },
        ),
        GoRoute(
          path: 'plan',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return StudyPlannerScreen(notebookId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    // Dev-only: unified canvas playground (Phase 2). Surfaced from Settings when
    // Developer Mode is enabled.
    GoRoute(
      path: '/canvas-demo',
      builder: (context, state) => const SceneEditorScreen(),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) => appRouter);
