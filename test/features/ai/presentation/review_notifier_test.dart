// The review session: queue snapshotting, reveal-before-grade, and persistence
// of each grade.

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/data/flashcards/flashcard_store.dart';
import 'package:inkflow/features/ai/domain/flashcards/spaced_repetition.dart';
import 'package:inkflow/features/ai/domain/models/flashcard.dart';
import 'package:inkflow/features/ai/presentation/flashcards/review_notifier.dart';

final _now = DateTime(2026, 7, 29, 10);

Flashcard _card(String front, {ReviewSchedule? schedule}) => Flashcard(
      front: front,
      back: 'back of $front',
      notebookId: 1,
      pageId: 10,
      createdAt: _now,
      schedule: schedule ?? ReviewSchedule.fresh,
    );

class FakeStore implements FlashcardStore {
  final List<Flashcard> cards;

  /// Every card handed to updateSchedule, in order.
  final List<Flashcard> saved = [];

  FakeStore(this.cards);

  @override
  Future<List<Flashcard>> forNotebook(int notebookId) async => List.of(cards);

  @override
  Future<List<Flashcard>> forPage(int pageId) async => List.of(cards);

  @override
  Future<List<Flashcard>> dueForNotebook(int notebookId, DateTime now) async =>
      selectDue(cards, now);

  @override
  Future<void> updateSchedule(Flashcard card) async {
    saved.add(card);
    final i = cards.indexWhere((c) => c.identityKey == card.identityKey);
    if (i >= 0) cards[i] = card;
  }

  @override
  Future<void> replaceForPage(int n, int p, List<Flashcard> c) async {}
}

ReviewNotifier _notifier(FakeStore store) =>
    ReviewNotifier(store: store, notebookId: 1, now: () => _now);

void main() {
  test('starts on the first due card, unrevealed', () async {
    final notifier = _notifier(FakeStore([_card('a'), _card('b')]));

    await notifier.start();

    final state = notifier.state as ReviewInProgress;
    expect(state.total, 2);
    expect(state.current.front, 'a');
    expect(state.revealed, isFalse);
    expect(state.completed, 0);
  });

  test('an empty deck is caught up', () async {
    final notifier = _notifier(FakeStore([]));

    await notifier.start();

    expect(notifier.state, isA<ReviewCaughtUp>());
  });

  test('a deck with nothing due reports when the next card returns', () async {
    final scheduled =
        ReviewSchedule.fresh.afterReview(ReviewGrade.easy, now: _now);
    final notifier = _notifier(FakeStore([_card('a', schedule: scheduled)]));

    await notifier.start();

    final state = notifier.state as ReviewCaughtUp;
    expect(state.nextDueAt, scheduled.dueAt);
  });

  test('grading is refused until the answer is shown', () async {
    final store = FakeStore([_card('a')]);
    final notifier = _notifier(store);
    await notifier.start();

    await notifier.grade(ReviewGrade.good);

    expect(store.saved, isEmpty);
    expect((notifier.state as ReviewInProgress).index, 0);
  });

  test('reveal then grade advances and persists', () async {
    final store = FakeStore([_card('a'), _card('b')]);
    final notifier = _notifier(store);
    await notifier.start();

    notifier.reveal();
    expect((notifier.state as ReviewInProgress).revealed, isTrue);
    await notifier.grade(ReviewGrade.good);

    final state = notifier.state as ReviewInProgress;
    expect(state.current.front, 'b');
    expect(state.revealed, isFalse, reason: 'next card starts face down');
    expect(state.completed, 1);
    expect(store.saved.single.front, 'a');
    expect(store.saved.single.schedule.repetitions, 1);
  });

  test('grading the last card finishes the session', () async {
    final notifier = _notifier(FakeStore([_card('only')]));
    await notifier.start();

    notifier.reveal();
    await notifier.grade(ReviewGrade.good);

    expect((notifier.state as ReviewFinished).reviewed, 1);
  });

  test('a card graded "again" stays in this session\'s queue', () async {
    // The queue is snapshotted, so failing a card does not silently drop it
    // just because its new due date is tomorrow.
    final store = FakeStore([_card('a'), _card('b')]);
    final notifier = _notifier(store);
    await notifier.start();

    notifier.reveal();
    await notifier.grade(ReviewGrade.again);

    final state = notifier.state as ReviewInProgress;
    expect(state.total, 2, reason: 'queue length is fixed for the session');
    expect(state.current.front, 'b');
  });

  test('each grade is persisted with the right schedule', () async {
    final store = FakeStore([_card('a'), _card('b')]);
    final notifier = _notifier(store);
    await notifier.start();

    notifier.reveal();
    await notifier.grade(ReviewGrade.again);
    notifier.reveal();
    await notifier.grade(ReviewGrade.easy);

    expect(store.saved, hasLength(2));
    expect(store.saved[0].schedule.repetitions, 0, reason: 'again resets');
    expect(store.saved[1].schedule.repetitions, 1, reason: 'easy passes');
  });

  test('revealing twice is harmless', () async {
    final notifier = _notifier(FakeStore([_card('a')]));
    await notifier.start();

    notifier.reveal();
    notifier.reveal();

    expect((notifier.state as ReviewInProgress).revealed, isTrue);
  });
}
