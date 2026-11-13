// Equations as LaTeX and tables as tables (docs: roadmap D2 step 7).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/domain/ai_exception.dart';
import 'package:margo/features/ai/domain/figure.dart';
import 'package:margo/features/ai/domain/figure_analyzer.dart';
import 'package:margo/features/ai/domain/figure_detail.dart';
import 'package:margo/features/ai/domain/image_transcriber.dart';

/// Replies in order; throws where a reply is null.
class _Model implements ImageTranscriber {
  _Model(this.replies);
  final List<String?> replies;
  final prompts = <String>[];

  @override
  Future<String> transcribeImage(Uint8List imageBytes,
      {required String prompt,
      double temperature = 0.0,
      int maxOutputTokens = 1024,
      int? randomSeed}) async {
    final reply = replies[prompts.length];
    prompts.add(prompt);
    if (reply == null) throw const AiGenerationException('no');
    return reply;
  }
}

String figure(String kind, String title) => jsonEncode({
      'kind': kind,
      'title': title,
      'summary': 'The $title as written in the notes.',
      'insight': 'It is the $title.',
      'confidence': 0.9,
    });

final image = Uint8List.fromList(const [1, 2, 3]);

void main() {
  group('cleanLatex', () {
    test('plain LaTeX is kept, a line per line', () {
      expect(cleanLatex(r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'),
          r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}');
      expect(cleanLatex('a = b + c\n\n2a = 2b + 2c'), 'a = b + c\n2a = 2b + 2c');
    });

    test('delimiters and fences the model added anyway are removed', () {
      expect(cleanLatex('```latex\n\$\$E = mc^2\$\$\n```'), 'E = mc^2');
      expect(cleanLatex(r'\[ \int_0^1 x\,dx \]'), r'\int_0^1 x\,dx');
      expect(cleanLatex(r'$a^2 + b^2 = c^2$'), 'a^2 + b^2 = c^2');
    });

    test('a reply cut off mid-expression is not kept', () {
      expect(cleanLatex(r'x = \frac{-b \pm \sqrt{b^2'), '');
      expect(cleanLatex(r'a}{b'), '');
    });

    test('an escaped brace is a character, not a group', () {
      expect(cleanLatex(r'S = \{1, 2, 3\}'), r'S = \{1, 2, 3\}');
    });

    test('prose is not LaTeX', () {
      expect(cleanLatex(r'The formula is $E = mc^2$ where m is mass.'), '');
      expect(cleanLatex('   '), '');
    });
  });

  group('parseMarkdownTable', () {
    test('headings, rule and rows', () {
      final t = parseMarkdownTable(
          '| Trial | Time (s) |\n|---|:--:|\n| 1 | 4.2 |\n| 2 | 4.5 |')!;
      expect(t.columns, ['Trial', 'Time (s)']);
      expect(t.rows, [
        ['1', '4.2'],
        ['2', '4.5'],
      ]);
    });

    test('words around the table and missing outer pipes are tolerated', () {
      final t = parseMarkdownTable(
          'Here is the table:\nA | B\n--- | ---\n1 | \n3 | 4\nDone.')!;
      expect(t.columns, ['A', 'B']);
      expect(t.rows.first, ['1', ''], reason: 'an empty cell is kept');
    });

    test('rows that disagree on the columns are no table at all', () {
      expect(parseMarkdownTable('| A | B |\n|---|---|\n| 1 | 2 | 3 |'), isNull);
    });

    test('headings alone, or one column, are not a table', () {
      expect(parseMarkdownTable('| A | B |\n|---|---|'), isNull);
      expect(parseMarkdownTable('| A |\n|---|\n| 1 |'), isNull);
      expect(parseMarkdownTable('no table here'), isNull);
    });

    test('it comes back the same from Markdown and from the cache', () {
      const t = FigureTable(columns: [
        'A',
        'B'
      ], rows: [
        ['1', '2'],
      ]);
      expect(parseMarkdownTable(t.toMarkdown()), t);
      expect(FigureTable.fromJson(jsonDecode(jsonEncode(t.toJson()))), t);
      expect(FigureTable.fromJson({'columns': ['A', 'B'], 'rows': [['1']]}),
          isNull);
    });
  });

  group('the follow-up read', () {
    test('an equation is asked for again, as LaTeX', () async {
      final model = _Model([figure('equation', 'quadratic formula'), r'x = \frac{1}{2}']);
      final f = await FigureAnalyzer(local: model).analyze(image);

      expect(model.prompts.length, 2);
      expect(model.prompts[1], kLatexPrompt);
      expect(f!.latex, r'x = \frac{1}{2}');
      expect(f.toPromptBlock(), contains(r'Written out: $$x = \frac{1}{2}$$'));
    });

    test('a table is asked for again, as a table', () async {
      final model = _Model(
          [figure('table', 'trial results'), '| Trial | Time |\n|---|---|\n| 1 | 4.2 |']);
      final f = await FigureAnalyzer(local: model).analyze(image);

      expect(model.prompts[1], kTablePrompt);
      expect(f!.table!.rows.single, ['1', '4.2']);
      expect(f.toPromptBlock(), contains('| Trial | Time |'));
    });

    test('a chart costs no second call', () async {
      final model = _Model([figure('chart', 'revenue chart')]);
      await FigureAnalyzer(local: model).analyze(image);
      expect(model.prompts.length, 1);
    });

    test('a follow-up that fails or says nothing usable costs only itself',
        () async {
      for (final second in [null, r'x = \frac{1', 'I cannot read this.']) {
        final model = _Model([figure('equation', 'quadratic formula'), second]);
        final f = await FigureAnalyzer(local: model).analyze(image);
        expect(f, isNotNull, reason: '$second');
        expect(f!.latex, '');
        expect(f.summary, contains('quadratic formula'));
      }
    });

    test('a figure the cloud read is followed up by the cloud', () async {
      final local = _Model([null]);
      final cloud = _Model([figure('equation', 'wave equation'), 'v = f \\lambda']);
      final f = await FigureAnalyzer(
        local: local,
        cloud: cloud,
        canEscalate: () async => true,
      ).analyze(image);

      expect(f!.latex, r'v = f \lambda');
      expect(local.prompts.length, 1, reason: 'only its own failed read');
      expect(cloud.prompts.length, 2);
    });
  });

  test('LaTeX and a table survive the cache', () {
    const f = FigureDescription(
      kind: FigureKind.table,
      summary: 'A table of trial results from the experiment.',
      latex: r'\frac{a}{b}',
      table: FigureTable(columns: [
        'A',
        'B'
      ], rows: [
        ['1', '2'],
      ]),
    );
    final back = FigureDescription.fromJson(
        jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>)!;
    expect(back.latex, r'\frac{a}{b}');
    expect(back.table, f.table);
  });
}
