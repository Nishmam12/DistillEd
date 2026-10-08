// Entry point — initializes Isar database and launches the app with Riverpod.

import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'features/ai/data/providers/cloud_gateway_provider.dart' show loadDeviceKey;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'data/migration/launch_migration.dart';
import 'data/persistence/library_repository.dart';
import 'data/persistence/lecture_recording_record.dart';
import 'data/persistence/page_text_record.dart';
import 'data/persistence/scene_element_record.dart';
import 'features/ai/data/device/device_health.dart';
import 'features/ai/data/flashcards/flashcard_record.dart';
import 'features/ai/data/memory/concept_mastery_record.dart';
import 'features/ai/data/memory/learning_preferences_record.dart';
import 'features/ai/data/memory/quiz_attempt_record.dart';
import 'features/ai/data/memory/concept_relation_record.dart';
import 'features/ai/data/memory/study_session_record.dart';
import 'features/ai/data/ocr/read_cache_record.dart';
import 'features/ai/data/rag/note_chunk_record.dart';
import 'features/ai/data/study_planner/study_plan_record.dart';
import 'features/ai/domain/device_state.dart';
import 'features/ai/presentation/ai_providers.dart' show deviceProfileProvider;
import 'features/summarize/data/cache/summary_cache.dart';
import 'editor/state/library_controller.dart';
import 'editor/state/scene_controller.dart';
import 'shared/isar/isar_service.dart';
import 'features/home/domain/models/folder.dart';
import 'features/home/domain/models/notebook.dart';
import 'features/home/domain/models/note_page.dart';
import 'core/theme/ink_palette.dart';

/// Debug only: prints how many rows each collection holds, so an Isar upgrade
/// can be checked against the old build on the same device (plan, phase 2.2).
/// Phase 4.5 reuses it.
Future<void> _logCollectionCounts(Isar isar) async {
  final counts = <String, int>{
    'Notebook': await isar.collection<Notebook>().count(),
    'NotePage': await isar.collection<NotePage>().count(),
    'SceneElementRecord': await isar.collection<SceneElementRecord>().count(),
    'AppMeta': await isar.collection<AppMeta>().count(),
    'SummaryCache': await isar.collection<SummaryCache>().count(),
    'FlashcardRecord': await isar.collection<FlashcardRecord>().count(),
    'ConceptMasteryRecord':
        await isar.collection<ConceptMasteryRecord>().count(),
    'QuizAttemptRecord': await isar.collection<QuizAttemptRecord>().count(),
    'LearningPreferencesRecord':
        await isar.collection<LearningPreferencesRecord>().count(),
    'StudySessionRecord': await isar.collection<StudySessionRecord>().count(),
    'NoteChunkRecord': await isar.collection<NoteChunkRecord>().count(),
    'ConceptRelationRecord':
        await isar.collection<ConceptRelationRecord>().count(),
    'StudyPlanRecord': await isar.collection<StudyPlanRecord>().count(),
    'PageTextRecord': await isar.collection<PageTextRecord>().count(),
    'Folder': await isar.collection<Folder>().count(),
    'LectureRecordingRecord':
        await isar.collection<LectureRecordingRecord>().count(),
    'ReadCacheRecord': await isar.collection<ReadCacheRecord>().count(),
  };
  debugPrint('[IsarCounts] $counts');
}

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
  final isar = await IsarService.openDatabase([
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
    // Additive, like the collections above: a cache of vision reads, so no
    // existing data is touched and nothing needs migrating.
    ReadCacheRecordSchema,
  ]);
  if (kDebugMode) await _logCollectionCounts(isar);

  // One-time, gated, non-destructive migration of legacy page content into the
  // unified store. Never throws (legacy data and the old screens keep working).
  await runLaunchMigration();

  await loadDeviceKey();

  final appDocsPath = (await getApplicationDocumentsDirectory()).path;

  // How much of the on-device AI pipeline this device is given, from its total
  // RAM. Read once, before the first frame, so providers can use it
  // synchronously; a reading that cannot be made leaves the full profile, so
  // nobody is degraded on the strength of nothing.
  final profile = chooseProfile(
      totalRamBytes: (await DeviceHealth().read()).totalRamBytes);

  runApp(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        deviceProfileProvider.overrideWithValue(profile),
        appDocsPathProvider.overrideWithValue(appDocsPath),
        libraryRepositoryProvider.overrideWithValue(
          FileLibraryRepository(File('$appDocsPath/inkflow_library.json')),
        ),
      ],
      child: const InkFlowApp(),
    ),
  );
}
