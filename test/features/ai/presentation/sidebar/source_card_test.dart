import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/presentation/sidebar/ai_ask_view.dart';

void main() {
  const lecture = '[1:23] The nucleus holds the DNA.';
  const notes = 'Notes on the cell cycle';

  Future<void> pump(
    WidgetTester tester, {
    required String text,
    void Function(int pageId)? onJump,
    void Function(int pageId, String passage)? onPlay,
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SourceCard(
            index: 1,
            pageId: 7,
            text: text,
            onJumpToSource: onJump,
            onPlayLecture: onPlay,
          ),
        ),
      ));

  testWidgets('a passage from a lecture offers to play it', (tester) async {
    await pump(tester, text: lecture, onPlay: (_, __) {});

    expect(find.byTooltip('Play this part of the lecture'), findsOneWidget);
  });

  testWidgets('tapping play plays the passage, and does not jump pages',
      (tester) async {
    final played = <(int, String)>[];
    var jumps = 0;
    await pump(tester,
        text: lecture,
        onJump: (_) => jumps++,
        onPlay: (page, passage) => played.add((page, passage)));

    await tester.tap(find.byTooltip('Play this part of the lecture'));
    await tester.pump();

    expect(played, [(7, lecture)]);
    expect(jumps, 0);
  });

  testWidgets('tapping the rest of the card still jumps to its page',
      (tester) async {
    final jumped = <int>[];
    await pump(tester,
        text: lecture, onJump: jumped.add, onPlay: (_, __) {});

    await tester.tap(find.textContaining('nucleus'));
    await tester.pump();

    expect(jumped, [7]);
  });

  testWidgets('ordinary notes have no play button', (tester) async {
    await pump(tester, text: notes, onPlay: (_, __) {});

    expect(find.byTooltip('Play this part of the lecture'), findsNothing);
  });

  testWidgets('nothing to play it with, no button', (tester) async {
    await pump(tester, text: lecture);

    expect(find.byTooltip('Play this part of the lecture'), findsNothing);
  });

  testWidgets('a citation number is not a lecture', (tester) async {
    await pump(tester, text: 'as shown in [2] and [12]', onPlay: (_, __) {});

    expect(find.byTooltip('Play this part of the lecture'), findsNothing);
  });
}
