// Drives one spaced-repetition review session over a notebook's due cards.
//
// The queue is snapshotted when the session starts rather than re-queried after
// every answer: a card graded `again` becomes due tomorrow, so a live query
// would drop it mid-session, and one graded `good` would otherwise let the
// list shift under the learner between taps.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/flashcards/flashcard_store.dart';
import '../../domain/flashcards/spaced_repetition.dart';
import '../../domain/models/flashcard.dart';
import '../ai_providers.dart';

/// What the session is showing.
sealed class ReviewState {
  const ReviewState();
}

class ReviewLoading extends ReviewState {
  const ReviewLoading();
}

/// No cards are due — the deck is caught up.
class ReviewCaughtUp extends ReviewState {
  /// Cards in the deck that are not yet due, so the UI can say when to return.
  final DateTime? nextDueAt;

  const ReviewCaughtUp({this.nextDueAt});
}

class ReviewInProgress extends ReviewState {
  final List<Flashcard> queue;
  final int index;

  /// Whether the back of the current card is showing.
  final bool revealed;

  /// How many cards have been graded this session.
  final int completed;

  const ReviewInProgress({
    required this.queue,
    required this.index,
    required this.revealed,
    required this.completed,
  });

  Flashcard get current => queue[index];
  int get remaining => queue.length - index;
  int get total => queue.length;

  ReviewInProgress copyWith({int? index, bool? revealed, int? completed}) =>
      ReviewInProgress(
        queue: queue,
        index: index ?? this.index,
        revealed: revealed ?? this.revealed,
        completed: completed ?? this.completed,
      );
}

/// The session finished — every due card was graded.
class ReviewFinished extends ReviewState {
  final int reviewed;

  const ReviewFinished({required this.reviewed});
}

class ReviewNotifier extends StateNotifier<ReviewState> {
  final FlashcardStore _store;
  final int _notebookId;
  final DateTime Function() _now;

  ReviewNotifier({
    required FlashcardStore store,
    required int notebookId,
    DateTime Function() now = DateTime.now,
  })  : _store = store,
        _notebookId = notebookId,
        _now = now,
        super(const ReviewLoading());

  Future<void> start() async {
    state = const ReviewLoading();
    final now = _now();
    final due = await _store.dueForNotebook(_notebookId, now);
    if (!mounted) return;

    if (due.isEmpty) {
      state = ReviewCaughtUp(nextDueAt: await _nextDueAt());
      return;
    }
    state = ReviewInProgress(
      queue: due,
      index: 0,
      revealed: false,
      completed: 0,
    );
  }

  /// Shows the answer. Grading is only offered after the learner has committed
  /// to an attempt — self-grading before seeing the back is meaningless.
  void reveal() {
    final current = state;
    if (current is! ReviewInProgress || current.revealed) return;
    state = current.copyWith(revealed: true);
  }

  /// Grades the current card and advances.
  Future<void> grade(ReviewGrade grade) async {
    final current = state;
    if (current is! ReviewInProgress || !current.revealed) return;

    await _store.updateSchedule(current.current.graded(grade, now: _now()));
    if (!mounted) return;

    final next = current.index + 1;
    final completed = current.completed + 1;
    state = next >= current.queue.length
        ? ReviewFinished(reviewed: completed)
        : current.copyWith(index: next, revealed: false, completed: completed);
  }

  /// The soonest a not-yet-due card comes back, for the caught-up message.
  Future<DateTime?> _nextDueAt() async {
    final all = await _store.forNotebook(_notebookId);
    DateTime? soonest;
    for (final card in all) {
      final due = card.schedule.dueAt;
      if (due == null) continue;
      if (soonest == null || due.isBefore(soonest)) soonest = due;
    }
    return soonest;
  }
}

final reviewNotifierProvider = StateNotifierProvider.autoDispose
    .family<ReviewNotifier, ReviewState, int>((ref, notebookId) {
  final notifier = ReviewNotifier(
    store: ref.watch(flashcardStoreProvider),
    notebookId: notebookId,
  );
  notifier.start();
  return notifier;
});
