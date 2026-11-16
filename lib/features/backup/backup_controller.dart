// Runs backups when they are due, and holds what Settings shows about them:
// whether one is running, when the last one finished, where it went, and what
// went wrong.
//
// Triggers: the app starting or coming back to the foreground, the user
// leaving a note, and "Back up now". Automatic triggers do nothing unless the
// user switched automatic backup on.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers/settings_provider.dart';
import '../../data/backup/backup_library.dart';
import '../../data/backup/backup_service.dart';
import '../../data/backup/downloads_backup_target.dart';
import '../../data/persistence/page_text_store.dart';
import '../../editor/state/page_notifier.dart';
import '../../editor/state/scene_controller.dart';
import '../home/presentation/home_notifier.dart';

@immutable
class BackupStatus {
  final bool running;
  final BackupState saved;

  /// True when backups landed in the app's own folder (Android 8–9), which a
  /// reinstall erases.
  final bool inAppStorage;

  const BackupStatus({
    this.running = false,
    this.saved = BackupState.empty,
    this.inAppStorage = false,
  });

  BackupStatus copyWith({bool? running, BackupState? saved, bool? inAppStorage}) =>
      BackupStatus(
        running: running ?? this.running,
        saved: saved ?? this.saved,
        inAppStorage: inAppStorage ?? this.inAppStorage,
      );
}

class BackupController extends StateNotifier<BackupStatus> {
  BackupController({
    required this._service,
    required this._settings,
    BackupStateStore? stateStore,
    bool Function()? inAppStorage,
    DateTime Function()? clock,
  })  : _stateStore = stateStore ?? const SharedPrefsBackupStateStore(),
        _inAppStorage = inAppStorage ?? (() => false),
        _clock = clock ?? DateTime.now,
        super(const BackupStatus()) {
    _refresh();
  }

  /// Built on first use: the service reaches the database, which a switched-off
  /// app (or a Settings screen that only shows status) must not touch.
  final BackupService Function() _service;
  final BackupStateStore _stateStore;
  final SettingsState Function() _settings;
  final bool Function() _inAppStorage;
  final DateTime Function() _clock;

  Future<void> _refresh() async {
    final saved = await _stateStore.load();
    if (mounted) state = state.copyWith(saved: saved);
  }

  /// Runs a backup if [trigger] calls for one now. Returns null when nothing
  /// ran (switched off, not due, or one already running).
  Future<BackupReport?> trigger(BackupTrigger trigger) async {
    if (state.running) return null;
    final settings = _settings();
    if (trigger != BackupTrigger.manual &&
        (!settings.loaded || !settings.autoBackup)) {
      return null;
    }
    final saved = await _stateStore.load();
    if (!isBackupDue(
        settings.backupFrequency, saved.lastRunAt, _clock(), trigger)) {
      return null;
    }

    state = state.copyWith(running: true);
    try {
      return await _service().run(force: trigger == BackupTrigger.manual);
    } catch (e, st) {
      // Failed before any notebook could be tried (reading the list itself).
      debugPrint('[Backup] run failed: $e\n$st');
      await _stateStore.save(BackupState(
        records: saved.records,
        lastRunAt: _clock(),
        lastSuccessAt: saved.lastSuccessAt,
        lastError: 'The backup could not run.',
        location: saved.location,
      ));
      return null;
    } finally {
      final after = await _stateStore.load();
      if (mounted) {
        state = BackupStatus(
          running: false,
          saved: after,
          inAppStorage: _inAppStorage(),
        );
      }
    }
  }

  Future<RestoreReport> restore(List<String> paths) => _service().restore(paths);

  /// The backups in the backup folder, newest first.
  Future<List<BackupFile>> available() => _service().available();

  /// Restores backup [name] from the backup folder as a new notebook.
  Future<RestoreReport> restoreNamed(String name) =>
      _service().restoreNamed(name);
}

final _backupTargetProvider =
    Provider<DownloadsBackupTarget>((ref) => DownloadsBackupTarget());

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
      library: AppBackupLibrary(
        notes: ref.watch(noteRepositoryProvider),
        pages: ref.watch(pageRepositoryProvider),
        elements: ref.watch(sceneElementStoreProvider),
        texts: ref.watch(pageTextStoreProvider),
        docsDir: ref.watch(appDocsPathProvider),
      ),
      target: ref.watch(_backupTargetProvider),
      state: const SharedPrefsBackupStateStore(),
      tempDir: () async => (await getTemporaryDirectory()).path,
    ));

final backupControllerProvider =
    StateNotifierProvider<BackupController, BackupStatus>((ref) {
  final target = ref.watch(_backupTargetProvider);
  return BackupController(
    service: () => ref.read(backupServiceProvider),
    settings: () => ref.read(settingsProvider),
    inAppStorage: () => target.savedToAppStorage,
  );
});

/// Checks for a due backup once settings have loaded, and whenever the app
/// comes back to the foreground. Read once from the app root.
final backupLifecycleProvider = Provider<void>((ref) {
  void check() {
    // Nothing is built unless backup is on: the backup service reaches the
    // database, which a switched-off app need not touch for this.
    if (!ref.read(settingsProvider).autoBackup) return;
    unawaited(ref
        .read(backupControllerProvider.notifier)
        .trigger(BackupTrigger.appResumed));
  }
  final listener = AppLifecycleListener(onResume: check);
  ref.onDispose(listener.dispose);
  ref.listen<bool>(settingsProvider.select((s) => s.loaded), (was, loaded) {
    if (loaded && was != true) check();
  }, fireImmediately: true);
});
