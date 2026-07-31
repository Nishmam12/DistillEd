import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/math_markup.dart';

/// Reassembles [segments] back into the source string, delimiters and all.
/// Every parse must survive this — a renderer that can lose text is worse than
/// no renderer.
String reassemble(List<MathSegment> segments) {
  final buffer = StringBuffer();
  for (final s in segments) {
    if (!s.isMath) {
      buffer.write(s.text);
    } else if (s.isBlock) {
      buffer.write('\$\$${s.text}\$\$');
    } else {
      buffer.write('\$${s.text}\$');
    }
  }
  return buffer.toString();
}

void main() {
  group('plain prose', () {
    test('an empty string yields nothing', () {
      expect(parseMathSegments(''), isEmpty);
    });

    test('prose with no dollar signs is one text segment', () {
      const text = 'Photosynthesis converts light into sugar.';
      expect(parseMathSegments(text), [const MathSegment.text(text)]);
      expect(containsMath(text), isFalse);
    });
  });

  group('inline maths', () {
    test('a lone formula is one math segment, delimiters stripped', () {
      expect(parseMathSegments(r'$E = mc^2$'),
          [const MathSegment.math('E = mc^2')]);
    });

    test('a formula inside a sentence splits into three segments', () {
      final segments = parseMathSegments(r'The energy is $E = mc^2$ exactly.');

      expect(segments, [
        const MathSegment.text('The energy is '),
        const MathSegment.math('E = mc^2'),
        const MathSegment.text(' exactly.'),
      ]);
    });

    test('two formulas in one sentence both parse', () {
      final segments = parseMathSegments(r'With $a$ and $b$ known.');
      expect(segments.where((s) => s.isMath).map((s) => s.text), ['a', 'b']);
    });
  });

  group('block maths', () {
    test(r'$$…$$ is a block segment', () {
      final segments =
          parseMathSegments(r'The roots: $$x = \frac{-b}{2a}$$ and that is it.');

      expect(segments[1].isMath, isTrue);
      expect(segments[1].isBlock, isTrue);
      expect(segments[1].text, r'x = \frac{-b}{2a}');
    });

    test('a block is not mistaken for two empty inline pairs', () {
      final segments = parseMathSegments(r'$$a + b$$');
      expect(segments, hasLength(1));
      expect(segments.single.isBlock, isTrue);
    });
  });

  group('what must NOT be treated as maths', () {
    test('currency stays prose', () {
      const text = r'The textbook cost $30 and the notes cost $5.';
      expect(containsMath(text), isFalse);
      expect(parseMathSegments(text).single.text, text);
    });

    test('a dollar followed by a space stays prose', () {
      const text = r'Priced in $ per unit.';
      expect(containsMath(text), isFalse);
    });

    test('an unclosed delimiter stays prose — a formula still streaming in', () {
      const partial = r'The quadratic formula is $x = \frac{-b';
      expect(containsMath(partial), isFalse);
      expect(reassemble(parseMathSegments(partial)), partial);
    });

    test('an inline delimiter does not swallow the next paragraph', () {
      const text = 'Costs \$40 to run.\n\nThe second paragraph survives.';
      expect(containsMath(text), isFalse);
    });

    test(r'an escaped \$ is a literal dollar sign', () {
      final segments = parseMathSegments(r'A literal \$ sign, not maths.');
      expect(segments.any((s) => s.isMath), isFalse);
    });

    test('empty delimiters render as written rather than as a blank formula',
        () {
      expect(containsMath(r'$$'), isFalse);
    });

    test(r'a digit-led expression like $2x$ IS maths', () {
      // The currency rule must not eat a real expression that opens with a
      // number, which is why it looks at the whole run rather than one char.
      expect(parseMathSegments(r'Take $2x + 1$ here.')[1].text, '2x + 1');
    });
  });

  test('every parse round-trips back to its source', () {
    const samples = [
      r'Plain prose with no maths at all.',
      r'Inline $a^2 + b^2 = c^2$ in a sentence.',
      r'Block: $$\int_0^1 x^2 dx$$ done.',
      r'Costs $30, and $E = mc^2$ too.',
      r'Unclosed $\frac{1}{2',
      r'',
    ];
    for (final sample in samples) {
      expect(reassemble(parseMathSegments(sample)), sample, reason: sample);
    }
  });

  group('a real note fixture: the quadratic formula and a derivative', () {
    // The end-to-end shape of what Explain/Ask/Summarize produce from a maths
    // note, asserted at the parsing layer that decides whether it renders as
    // maths or as raw backslashes.
    const answer = r'''You solve it with the quadratic formula:

$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$

Here $a = 2$, $b = -3$ and $c = 1$, so the discriminant $b^2 - 4ac$ comes to 1.
Differentiating $f(x) = x^3$ gives $f'(x) = 3x^2$.''';

    test('the quadratic formula is a block segment, not raw text', () {
      final blocks = parseMathSegments(answer).where((s) => s.isBlock);
      expect(blocks, hasLength(1));
      expect(blocks.single.text, r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}');
    });

    test('the coefficients and the derivative are inline maths', () {
      final inline = [
        for (final s in parseMathSegments(answer))
          if (s.isMath && !s.isBlock) s.text
      ];
      expect(inline, containsAll(['a = 2', 'b = -3', 'c = 1', r'f(x) = x^3']));
      expect(inline, contains(r"f'(x) = 3x^2"));
    });

    test('no LaTeX command escapes into a prose segment', () {
      for (final segment in parseMathSegments(answer)) {
        if (segment.isMath) continue;
        expect(segment.text, isNot(contains(r'\frac')));
        expect(segment.text, isNot(contains(r'\sqrt')));
        expect(segment.text, isNot(contains(r'\pm')));
      }
    });

    test('the whole answer round-trips', () {
      expect(reassemble(parseMathSegments(answer)), answer);
    });
  });

  group('mathAsPlainText, for the canvas-painted graph labels', () {
    test('strips the delimiters', () {
      expect(mathAsPlainText(r'$E = mc^2$'), 'E = mc²');
    });

    test('spells a fraction as a division', () {
      expect(mathAsPlainText(r'$\frac{a}{b}$'), 'a/b');
    });

    test('spells a root and a Greek letter', () {
      expect(mathAsPlainText(r'$\sqrt{2}$'), '√(2)');
      expect(mathAsPlainText(r'$\lambda$'), 'λ');
    });

    test('leaves ordinary concept names untouched', () {
      expect(mathAsPlainText('Photosynthesis'), 'Photosynthesis');
    });

    test('never leaves a bare backslash-frac in a label', () {
      expect(mathAsPlainText(r'Speed $= \frac{d}{t}$'), isNot(contains(r'\frac')));
    });
  });
}
