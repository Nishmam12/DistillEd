// The daily study page (Evernote's Daily Note, Phase 8): once a day, the first
// time Margo is opened, a page named for the day ("Wed 18 Nov") is added to
// the end of a notebook the user chose in Settings. It takes that notebook's
// paper, so the notebook's template is the daily page's template. Off until a
// notebook is chosen.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error_log.dart';
import '../../../editor/state/page_notifier.dart' show pageRepositoryProvider;
import 'home_notifier.dart';

const _kNotebook = 'home.dailyPageNotebook';
const _kLastDay = 'home.dailyPageLastDay';

/// The notebook that gets a page each day; null when off.
class DailyPageNotebookNotifier extends StateNotifier<int?> {
  DailyPageNotebookNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final id = (await SharedPreferences.getInstance()).getInt(_kNotebook);
      if (mounted) state = id;
    } catch (_) {}
  }

  Future<void> set(int? notebookId) async {
    state = notebookId;
    final prefs = await SharedPreferences.getInstance();
    if (notebookId == null) {
      await prefs.remove(_kNotebook);
    } else {
      await prefs.setInt(_kNotebook, notebookId);
    }
  }
}

final dailyPageNotebookProvider =
    StateNotifierProvider<DailyPageNotebookNotifier, int?>(
        (ref) => DailyPageNotebookNotifier());

/// "Wed 18 Nov".
String dailyPageTitle(DateTime day) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${days[day.weekday - 1]} ${day.day} ${months[day.month - 1]}';
}

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Adds today's page if it is due; read once from `app.dart`, and again
/// whenever the app comes back to the front (a new day may have begun).
final dailyPageProvider = Provider<void>((ref) {
  Future<void> ensure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_kNotebook);
      final today = DateTime.now();
      if (id == null || prefs.getString(_kLastDay) == _dayKey(today)) return;
      final notebook = await ref.read(noteRepositoryProvider).getNotebook(id);
      // A notebook deleted or hidden since: nothing is added.
      if (notebook == null || notebook.isInTrash || notebook.hidden) return;
      final pages = ref.read(pageRepositoryProvider);
      final page = await pages.createPage(id);
      await pages.setPageInfo(page.id, title: dailyPageTitle(today));
      await prefs.setString(_kLastDay, _dayKey(today));
      await ref.read(homeNotifierProvider.notifier).loadNotebooks();
    } catch (e, st) {
      unawaited(ErrorLog.record(e, st));
    }
  }

  final listener = AppLifecycleListener(onResume: () => unawaited(ensure()));
  ref.onDispose(listener.dispose);
  unawaited(ensure());
});
