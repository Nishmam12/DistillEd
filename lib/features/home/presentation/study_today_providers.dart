// Data for the Today strip, the study reminders and the home-screen widgets.
// Hidden notebooks never count: their cards and plans stay out of all three.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/presentation/ai_providers.dart'
    show flashcardStoreProvider, studyPlanStoreProvider;
import '../domain/study_today.dart';
import 'note_cards_provider.dart';

/// Every shown notebook's cards and plan. Read again when a notebook is
/// closed (reviews and plans change inside it) and when the app is left.
final studyNotebooksProvider =
    FutureProvider<List<StudyNotebook>>((ref) async {
  final cards = await ref.watch(noteCardsProvider.future);
  final store = ref.read(flashcardStoreProvider);
  final plans = ref.read(studyPlanStoreProvider);
  return [
    for (final n in cards)
      if (!n.hidden)
        (
          id: n.id,
          title: n.title,
          cardDue: [
            for (final c in await store.forNotebook(n.id)) c.schedule.dueAt,
          ],
          plan: await plans.loadForNotebook(n.id),
        ),
  ];
});

/// A card of the Today strip, which the user can dismiss.
enum TodayCard { cards, plan, pad }

/// The Today cards dismissed; Settings brings them back.
class TodayHiddenNotifier extends StateNotifier<Set<TodayCard>> {
  TodayHiddenNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'home.todayHidden';

  Future<void> _load() async {
    try {
      final names =
          (await SharedPreferences.getInstance()).getStringList(_key) ?? [];
      if (!mounted) return;
      state = {
        for (final c in TodayCard.values)
          if (names.contains(c.name)) c,
      };
    } catch (_) {}
  }

  Future<void> set(TodayCard card, {required bool hidden}) async {
    state = hidden ? {...state, card} : ({...state}..remove(card));
    await (await SharedPreferences.getInstance())
        .setStringList(_key, [for (final c in state) c.name]);
  }
}

final todayHiddenProvider =
    StateNotifierProvider<TodayHiddenNotifier, Set<TodayCard>>(
        (ref) => TodayHiddenNotifier());

/// The scratch pad's text: jotted on Home, turned into a note when wanted.
class ScratchPadNotifier extends StateNotifier<String> {
  ScratchPadNotifier() : super('') {
    _load();
  }

  static const _key = 'home.scratchPad';

  Future<void> _load() async {
    try {
      final text = (await SharedPreferences.getInstance()).getString(_key);
      if (text != null && mounted && state.isEmpty) state = text;
    } catch (_) {}
  }

  Future<void> set(String text) async {
    state = text;
    await (await SharedPreferences.getInstance()).setString(_key, text);
  }
}

final scratchPadProvider = StateNotifierProvider<ScratchPadNotifier, String>(
    (ref) => ScratchPadNotifier());
