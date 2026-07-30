// Entry point — initializes Isar database and launches the app with Riverpod.

import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'data/migration/launch_migration.dart';
import 'data/persistence/library_repository.dart';
import 'data/persistence/lecture_recording_record.dart';
import 'data/persistence/page_text_record.dart';
import 'data/persistence/scene_element_record.dart';
import 'features/ai/data/flashcards/flashcard_record.dart';
import 'features/ai/data/memory/concept_mastery_record.dart';
import 'features/ai/data/memory/learning_preferences_record.dart';
import 'features/ai/data/memory/quiz_attempt_record.dart';
import 'features/ai/data/memory/concept_relation_record.dart';
import 'features/ai/data/memory/study_session_record.dart';
import 'features/ai/data/rag/note_chunk_record.dart';
import 'features/ai/data/study_planner/study_plan_record.dart';
import 'features/summarize/data/cache/summary_cache.dart';
import 'editor/state/library_controller.dart';
import 'editor/state/scene_controller.dart';
import 'shared/isar/isar_service.dart';
import 'features/home/domain/models/folder.dart';
import 'features/home/domain/models/notebook.dart';
import 'features/home/domain/models/note_page.dart';
import 'core/theme/ink_palette.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Synchronous Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In production, log to a file or crashlytics here
      debugPrint('Caught FlutterError: ${details.exception}');
    }
  };

  // 2. Asynchronous unhandled Dart errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Caught Async Error: $error\n$stack');
    } else {
      // Log to file or crashlytics
      debugPrint('Caught Async Error: $error');
    }
    return true; // prevent default fatal crash behavior
  };

  // 3. UI Error Boundary (Replace the scary red screen of death)
  //
  // This runs when the widget tree has failed, so it cannot read the theme —
  // there may not be a usable one. It reads the platform brightness directly
  // instead, which is the one thing still guaranteed to be available, so a
  // crash screen in dark mode isn't a flash of cream.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final p =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark
            ? InkPalette.dark
            : InkPalette.light;
    return Material(
      color: p.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: p.accentRed, size: 48),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode ? details.exception.toString() : 'An unexpected error occurred. The app will try to recover.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Open Isar with all collection schemas before the app starts. The new
  // unified collections (SceneElementRecord/AppMeta) are additive — Isar
  // auto-migrates the on-disk schema and existing Notebook/NotePage data is
  // untouched.
  await IsarService.openDatabase([
    NotebookSchema,
    NotePageSchema,
    SceneElementRecordSchema,
    AppMetaSchema,
    SummaryCacheSchema,
    FlashcardRecordSchema,
    ConceptMasteryRecordSchema,
    QuizAttemptRecordSchema,
    LearningPreferencesRecordSchema,
    StudySessionRecordSchema,
    NoteChunkRecordSchema,
    ConceptRelationRecordSchema,
    StudyPlanRecordSchema,
    PageTextRecordSchema,
    FolderSchema,
    LectureRecordingRecordSchema,
  ]);

  // One-time, gated, non-destructive migration of legacy page content into the
  // unified store. Never throws (legacy data and the old screens keep working).
  await runLaunchMigration();

  final appDocsPath = (await getApplicationDocumentsDirectory()).path;

  runApp(
    ProviderScope(
      overrides: [
        appDocsPathProvider.overrideWithValue(appDocsPath),
        libraryRepositoryProvider.overrideWithValue(
          FileLibraryRepository(File('$appDocsPath/inkflow_library.json')),
        ),
      ],
      child: const InkFlowApp(),
    ),
  );
}
