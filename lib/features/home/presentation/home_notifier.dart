// StateNotifier that manages the list of notebooks via NoteRepository.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/note_repository.dart';
import '../domain/models/notebook.dart';
import '../../../shared/isar/isar_service.dart';

class HomeNotifier extends StateNotifier<List<Notebook>> {
  final NoteRepository _repository;

  HomeNotifier(this._repository) : super([]);

  /// Loads all notebooks from the database into state.
  Future<void> loadNotebooks() async {
    state = await _repository.getAllNotebooks();
  }

  /// Creates a new notebook and refreshes the list.
  Future<Notebook> createNotebook(String title, {int templateIndex = 0}) async {
    final notebook = await _repository.createNotebook(title, templateIndex: templateIndex);
    await loadNotebooks();
    return notebook;
  }

  /// Moves a notebook to the trash and refreshes the list.
  ///
  /// Deliberately a soft delete: the home screen's delete used to erase the
  /// notebook immediately with no way back, which is the single most common
  /// data-loss complaint. Permanent deletion lives on the Trash screen.
  Future<void> deleteNotebook(int id) async {
    await _repository.moveToTrash(id);
    await loadNotebooks();
  }

  /// Brings a notebook back from the trash.
  Future<void> restoreNotebook(int id) async {
    await _repository.restoreFromTrash(id);
    await loadNotebooks();
  }

  /// Pins or unpins a notebook. Pinned notes lead every sort order.
  Future<void> setPinned(int id, bool pinned) async {
    await _repository.setPinned(id, pinned);
    await loadNotebooks();
  }

  /// Files a notebook into a folder, or unfiles it when [folderId] is null.
  Future<void> setFolder(int id, int? folderId) async {
    await _repository.setFolder(id, folderId);
    await loadNotebooks();
  }

  /// Replaces a notebook's tags.
  Future<void> setTags(int id, List<String> tags) async {
    await _repository.setTags(id, tags);
    await loadNotebooks();
  }

  /// Purges notebooks whose retention window has passed. Returns the count.
  Future<int> purgeExpiredTrash() => _repository.purgeExpiredTrash();

  /// Startup path: clear out expired trash, then load the live list. Runs once
  /// when the provider is first read, which in practice is app launch.
  Future<void> initialize() async {
    await purgeExpiredTrash();
    await loadNotebooks();
  }

  /// Updates an existing notebook and refreshes the list.
  Future<void> updateNotebook(Notebook notebook) async {
    await _repository.updateNotebook(notebook);
    await loadNotebooks();
  }
}

/// Provider for the NoteRepository, depends on the Isar instance.
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(IsarService.instance);
});

/// Provider for the HomeNotifier, auto-loads notebooks on creation.
final homeNotifierProvider =
    StateNotifierProvider<HomeNotifier, List<Notebook>>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  final notifier = HomeNotifier(repository);
  notifier.initialize();
  return notifier;
});
