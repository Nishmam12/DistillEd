// The spaced-repetition review session: one due card at a time, reveal, then
// self-grade. Replaces flipping through the whole deck every time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/ink_colors.dart';
import '../../domain/flashcards/spaced_repetition.dart';
import '../../domain/models/flashcard.dart';
import 'review_notifier.dart';

class ReviewScreen extends ConsumerWidget {
  final int notebookId;

  const ReviewScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewNotifierProvider(notebookId));

    return Scaffold(
      backgroundColor: context.ink.surface,
      appBar: AppBar(
        backgroundColor: context.ink.surface,
        title: const Text('Review'),
        actions: [
          if (state is ReviewInProgress)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${state.index + 1} / ${state.total}',
                  style: TextStyle(color: context.ink.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: switch (state) {
        ReviewLoading() =>
          Center(child: CircularProgressIndicator(color: context.ink.accent)),
        ReviewCaughtUp(:final nextDueAt) => _CaughtUp(nextDueAt: nextDueAt),
        ReviewFinished(:final reviewed) => _Finished(reviewed: reviewed),
        ReviewInProgress() => _Session(notebookId: notebookId, state: state),
      },
    );
  }
}

class _Session extends ConsumerWidget {
  final int notebookId;
  final ReviewInProgress state;

  const _Session({required this.notebookId, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reviewNotifierProvider(notebookId).notifier);
    final card = state.current;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: state.completed / state.total,
              backgroundColor: context.ink.border,
              color: context.ink.accent,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _CardFace(card: card, revealed: state.revealed),
            ),
            const SizedBox(height: 16),
            if (!state.revealed)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: notifier.reveal,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.ink.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Show answer'),
                ),
              )
            else
              _GradeButtons(
                card: card,
                onGrade: notifier.grade,
              ),
          ],
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final Flashcard card;
  final bool revealed;

  const _CardFace({required this.card, required this.revealed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.ink.accentWash,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.ink.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.front,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: context.ink.textPrimary,
              ),
            ),
            if (revealed) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              Text(
                card.back,
                style: TextStyle(
                  fontSize: 18,
                  color: context.ink.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The four SM-2 grades, each labelled with the interval it would produce — so
/// the choice is informed rather than a guess at what "Hard" costs.
class _GradeButtons extends StatelessWidget {
  final Flashcard card;
  final Future<void> Function(ReviewGrade) onGrade;

  const _GradeButtons({required this.card, required this.onGrade});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: [
        for (final grade in ReviewGrade.values) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => onGrade(grade),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: grade == ReviewGrade.again
                    ? context.ink.accentRed
                    : context.ink.textPrimary,
              ),
              child: Column(
                children: [
                  Text(grade.label, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    _intervalLabel(card.schedule.afterReview(grade, now: now)),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.ink.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (grade != ReviewGrade.values.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  static String _intervalLabel(ReviewSchedule next) {
    final days = next.intervalDays;
    if (days <= 1) return '1d';
    if (days < 30) return '${days}d';
    if (days < 365) return '${(days / 30).round()}mo';
    return '${(days / 365).round()}y';
  }
}

class _CaughtUp extends StatelessWidget {
  final DateTime? nextDueAt;

  const _CaughtUp({this.nextDueAt});

  @override
  Widget build(BuildContext context) {
    final next = nextDueAt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56, color: context.ink.accent),
            const SizedBox(height: 16),
            Text(
              'Nothing due',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.ink.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              next == null
                  ? 'Make some flashcards from a page to start reviewing.'
                  : 'Next card is due ${_relative(next)}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.ink.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime when) {
    final days = when.difference(DateTime.now()).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}

class _Finished extends StatelessWidget {
  final int reviewed;

  const _Finished({required this.reviewed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_outlined,
                size: 56, color: context.ink.accent),
            const SizedBox(height: 16),
            Text(
              'Reviewed $reviewed ${reviewed == 1 ? 'card' : 'cards'}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.ink.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Come back when the next batch is due.',
              style: TextStyle(color: context.ink.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
