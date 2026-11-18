// Hidden notes: kept out of the notes list, shown only in the unlocked Hidden
// view, and unlocked only through the device's own lock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/presentation/hidden_notes.dart';
import 'package:margo/features/home/presentation/models/note_card_data.dart';
import 'package:margo/features/home/presentation/note_cards_provider.dart';

NoteCardData _c(int id, {bool hidden = false}) => NoteCardData(
      id: id,
      title: 'n$id',
      createdAt: DateTime(2026),
      pages: 1,
      type: NoteType.text,
      hidden: hidden,
    );

void main() {
  late ProviderContainer c;
  var answer = DeviceAuthResult.cancelled;

  setUp(() {
    c = ProviderContainer(retry: (_, _) => null, overrides: [
      noteCardsProvider
          .overrideWith((ref) async => [_c(1), _c(2, hidden: true)]),
      deviceAuthProvider.overrideWithValue((_) async => answer),
    ]);
  });
  tearDown(() => c.dispose());

  Future<List<int>> visible() async {
    await c.read(noteCardsProvider.future);
    return [for (final n in c.read(visibleNoteCardsProvider).value!) n.id];
  }

  test('the notes list never shows a hidden note', () async {
    expect(await visible(), [1]);
    c.read(hiddenUnlockedProvider.notifier).state = true;
    expect(await visible(), [1], reason: 'unlocking alone is not the view');
  });

  test('the Hidden view shows hidden notes only while unlocked', () async {
    c.read(notesHiddenViewProvider.notifier).state = true;
    expect(await visible(), [1], reason: 'locked: falls back to the list');
    c.read(hiddenUnlockedProvider.notifier).state = true;
    expect(await visible(), [2]);
  });

  testWidgets('unlocking needs the device to say yes', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (_, r, _) {
            ref = r;
            return const SizedBox();
          }),
        ),
      ),
    ));
    final context = tester.element(find.byType(SizedBox));

    answer = DeviceAuthResult.cancelled;
    expect(await unlockHidden(context, ref), isFalse);
    expect(c.read(hiddenUnlockedProvider), isFalse);

    answer = DeviceAuthResult.noScreenLock;
    expect(await unlockHidden(context, ref), isFalse);
    await tester.pump();
    expect(find.textContaining('Set a screen lock'), findsOneWidget);

    answer = DeviceAuthResult.unlocked;
    expect(await unlockHidden(context, ref), isTrue);
    expect(c.read(hiddenUnlockedProvider), isTrue);
  });
}
