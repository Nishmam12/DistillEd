// Entry point — initializes Isar database and launches the app with Riverpod.

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'features/ai/data/providers/cloud_gateway_provider.dart' show loadDeviceKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/startup_failure_app.dart';
import 'core/error_log.dart';
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
import 'core/theme/app_colors.dart';
import 'core/theme/margo_theme.dart';

/// Every Isar collection the app stores. The one list both the database open
/// and the debug counts read, so a new collection cannot be registered in one
/// and forgotten in the other. Isar auto-migrates additive changes: a new
/// schema appended here needs no migration.
const _schemas = <CollectionSchema<dynamic>>[
  NotebookSchema,
  NotePageSchema,
  SceneElementRecordSchema,
  AppMetaSchema,
  SummaryCacheSchema,
  FlashcardRecordSchema,
  ConceptMasteryRecordSchema,
  QuizAttemptRecordSchema,
  LearningPreferencesRecordSchema,
  NoteChunkRecordSchema,
  ConceptRelationRecordSchema,
  StudyPlanRecordSchema,
  PageTextRecordSchema,
  FolderSchema,
  LectureRecordingRecordSchema,
  // A cache of vision reads.
  ReadCacheRecordSchema,
];

/// Debug only: prints how many rows each collection holds, so an Isar upgrade
/// can be checked against the old build on the same device (plan, phase 2.2).
/// Phase 4.5 reuses it.
Future<void> _logCollectionCounts(Isar isar) async {
  final counts = <String, int>{
    for (final s in _schemas)
      // Isar's only untyped lookup; fine for a debug readout, and it keeps
      // this map from being a second list to maintain.
      // ignore: invalid_use_of_protected_member
      s.name: await isar.getCollectionByNameInternal(s.name)!.count(),
  };
  debugPrint('[IsarCounts] $counts');
}

/// Bundled fonts/icons whose licences require their notice to ship with the app
/// (OFL §2, MIT). They appear on the About > Licenses page.
void _registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (package, asset) in const [
      ('Poppins', 'assets/licenses/Poppins-OFL.txt'),
      ('Nunito', 'assets/licenses/Nunito-OFL.txt'),
      ('Phosphor Icons', 'assets/licenses/Phosphor-MIT.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        package,
      ], await rootBundle.loadString(asset));
    }
  });
}

/// Gives queued scene writes a chance to land when the app is sent to the
/// background or closed. Best effort: the OS may end the process first, and a
/// write that never completes is then lost, as it was before this existed.
class _FlushPendingWrites with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(SceneController.flushAll());
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerAssetLicenses();
  WidgetsBinding.instance.addObserver(_FlushPendingWrites());

  // 1. Synchronous Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    } else {
      unawaited(ErrorLog.record(details.exception, details.stack));
      debugPrint('Caught FlutterError: ${details.exception}');
    }
  };

  // 2. Asynchronous unhandled Dart errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Caught Async Error: $error\n$stack');
    } else {
      unawaited(ErrorLog.record(error, stack));
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
    final theme =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark
            ? MargoTheme.dark
            : MargoTheme.light;
    final c = theme.extension<AppColors>()!;
    return Material(
      color: c.bgPrimary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode ? details.exception.toString() : 'An unexpected error occurred. The app will try to recover.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  };

  await _boot();
}

/// Opens the database, migrates, and starts the app. Re-runnable: when the
/// database cannot be opened the user gets a screen with a retry instead of a
/// frozen splash.
Future<void> _boot() async {
  // Something on screen at once: opening the database and migrating a large
  // library can take a while, and a blank window reads as a hang.
  runApp(const _BootSplash());
  try {
    await _openAndRun();
  } catch (error, stack) {
    unawaited(ErrorLog.record(error, stack));
    runApp(StartupFailureApp(error: error, retry: _boot));
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}

Future<void> _openAndRun() async {

  // Open Isar with all collection schemas before the app starts. The new
  // unified collections (SceneElementRecord/AppMeta) are additive — Isar
  // auto-migrates the on-disk schema and existing Notebook/NotePage data is
  // untouched.
  final isar = await IsarService.openDatabase(_schemas);
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
      retry: (_, _) => null,
      overrides: [
        deviceProfileProvider.overrideWithValue(profile),
        appDocsPathProvider.overrideWithValue(appDocsPath),
        libraryRepositoryProvider.overrideWithValue(
          FileLibraryRepository(File('$appDocsPath/margo_library.json')),
        ),
      ],
      child: const MargoApp(),
    ),
  );
}
