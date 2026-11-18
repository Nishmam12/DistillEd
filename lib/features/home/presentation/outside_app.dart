// Margo outside the app (docs/COMPETITOR_UPGRADE_PLAN.md, Phase 7), the Dart
// half of android/.../Outside.kt:
// - launches from an app shortcut, the Quick Settings tile, a widget or a
//   reminder arrive here and open the right screen;
// - whenever the app is left (and once at start) the study reminders and the
//   widgets' data are worked out and handed to Android, which shows them
//   while Margo is closed.
// Hidden notebooks never reach either.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/error_log.dart';
import '../../../core/providers/settings_provider.dart';
import '../domain/study_today.dart';
import 'home_notifier.dart';
import 'note_cards_provider.dart';
import 'recent_notebooks.dart';
import 'study_today_providers.dart';

const _launch = MethodChannel('com.margo.margo/launch');
const _outside = MethodChannel('com.margo.margo/outside');

/// Takes launch actions; read once from `app.dart`.
final launchIntakeProvider = Provider<void>((ref) {
  Future<void> take() async {
    try {
      final raw = await _launch.invokeMapMethod<String, Object?>('take');
      if (raw == null) return;
      await _handle(ref, raw['action'] as String?, raw['notebookId'] as int?);
    } on MissingPluginException {
      // Not Android, or a test.
    } catch (e, st) {
      unawaited(ErrorLog.record(e, st));
    }
  }

  _launch.setMethodCallHandler((call) async {
    if (call.method == 'arrived') await take();
  });
  ref.onDispose(() => _launch.setMethodCallHandler(null));
  // After the first frame, so the router and Home exist.
  WidgetsBinding.instance.addPostFrameCallback((_) => take());
});

String _today() {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = DateTime.now();
  return '${d.day} ${months[d.month - 1]}';
}

Future<void> _handle(Ref ref, String? action, int? notebookId) async {
  final home = ref.read(homeNotifierProvider.notifier);
  Future<void> open(String location, int id) async {
    unawaited(ref.read(recentNotebooksProvider.notifier).record(id));
    await appRouter.push(location);
    ref.invalidate(studyNotebooksProvider); // reviews may have happened
  }

  Future<void> fresh(String title, [String? start]) async {
    final notebook = await home.createNotebook('$title, ${_today()}');
    await open(
        '/note2/${notebook.id}${start == null ? '' : '?start=$start'}',
        notebook.id);
  }

  switch (action) {
    case 'new_note':
      await fresh('Note');
    case 'scan':
      await fresh('Scan', 'scan');
    case 'record':
      await fresh('Lecture', 'record');
    case 'open' when notebookId != null:
      await open('/note2/$notebookId', notebookId);
    case 'review':
      // A reminder names its notebook; the shortcut and widget take the one
      // with the most cards due.
      var id = notebookId;
      if (id == null) {
        await home.loadNotebooks();
        ref.invalidate(studyNotebooksProvider);
        final now = DateTime.now();
        final due = [
          for (final n in await ref.read(studyNotebooksProvider.future))
            (id: n.id, due: dueBy(n.cardDue, now)),
        ]..sort((a, b) => b.due.compareTo(a.due));
        if (due.isEmpty || due.first.due == 0) {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('No cards are due')));
          }
          return;
        }
        id = due.first.id;
      }
      await open('/note2/$id/review', id);
  }
}

/// Hands the reminders and the widgets' data to Android at start and each
/// time the app is left; read once from `app.dart`.
final outsideSyncProvider = Provider<void>((ref) {
  Future<void> sync() async {
    try {
      ref.invalidate(studyNotebooksProvider);
      final notebooks = await ref.read(studyNotebooksProvider.future);
      final now = DateTime.now();
      final reminders = ref.read(settingsProvider).studyReminders
          ? planReminders(notebooks, now)
          : const <StudyReminder>[];
      await _outside.invokeMethod<void>('reminders',
          jsonEncode([for (final r in reminders) r.toMap()]));

      final cards = await ref.read(noteCardsProvider.future);
      final pinned = [
        for (final c in cards)
          if (c.pinned && !c.hidden) c,
      ].firstOrNull;
      final text = pinned?.previewText.trim() ?? '';
      await _outside.invokeMethod<void>('widgets', {
        'due': notebooks.fold(0, (s, n) => s + dueBy(n.cardDue, now)),
        'pinnedId': pinned?.id,
        'pinnedTitle': pinned?.title,
        'pinnedText': text.length > 400 ? text.substring(0, 400) : text,
      });
    } on MissingPluginException {
      // Not Android, or a test.
    } catch (e, st) {
      unawaited(ErrorLog.record(e, st));
    }
  }

  final listener = AppLifecycleListener(onPause: () => unawaited(sync()));
  ref.onDispose(listener.dispose);
  ref.listen<bool>(settingsProvider.select((s) => s.studyReminders),
      (_, _) => unawaited(sync()));
  ref.listen<bool>(settingsProvider.select((s) => s.loaded), (was, loaded) {
    if (loaded && was != true) unawaited(sync());
  }, fireImmediately: true);
});

/// Asks Android for the notification permission (Android 13+). True when
/// reminders can be shown.
Future<bool> askNotificationPermission() async {
  try {
    return await _outside.invokeMethod<bool>('askNotifications') ?? false;
  } on MissingPluginException {
    return true;
  }
}
