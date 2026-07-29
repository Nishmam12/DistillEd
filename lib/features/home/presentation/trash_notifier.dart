// The trash list. Kept separate from [HomeNotifier] so the home screen never
// pays for loading deleted notebooks, and so restoring can refresh both lists.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/note_repository.dart';
import '../domain/models/notebook.dart';
import 'home_notifier.dart';

class TrashNotifier extends StateNotifier<List<Notebook>> {
  final NoteRepository _repository;

  TrashNotifier(this._repository) : super([]);

  Future<void> load() async {
    state = await _repository.getTrashedNotebooks();
  }

  /// Restores a notebook to the home list.
  Future<void> restore(int id) async {
    await _repository.restoreFromTrash(id);
    await load();
  }

  /// Deletes one notebook for good, with everything it owns.
  Future<void> deleteForever(int id) async {
    await _repository.deleteNotebook(id);
    await load();
  }

  /// Deletes everything in the trash. Returns how many went.
  Future<int> emptyTrash() async {
    final count = await _repository.emptyTrash();
    await load();
    return count;
  }

  /// Days left before [notebook] is purged automatically.
  ///
  /// Rounded up, so a note deleted moments ago reads "30 days" rather than 29 —
  /// truncating would under-report the whole window by a day. Clamped at 0 so
  /// an overdue item (the purge runs at launch, so one can sit here briefly)
  /// never shows a negative countdown.
  static int daysUntilPurge(Notebook notebook) {
    final deletedAt = notebook.deletedAt;
    if (deletedAt == null) return NoteRepository.trashRetention.inDays;
    final left = NoteRepository.trashRetention -
        DateTime.now().difference(deletedAt);
    if (left.isNegative) return 0;
    return (left.inMilliseconds / Duration.millisecondsPerDay).ceil();
  }
}

final trashNotifierProvider =
    StateNotifierProvider<TrashNotifier, List<Notebook>>((ref) {
  final notifier = TrashNotifier(ref.watch(noteRepositoryProvider));
  notifier.load();
  return notifier;
});
