import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/domain/suggested_terms.dart';

void main() {
  test('concepts first, then repeated phrases, then repeated words', () {
    final terms = rankTerms(
      concepts: ['Mitosis', 'mitosis'],
      pageTexts: [
        'Cell division happens in the nucleus.\nCell division: prophase',
        'The nucleus holds DNA. DNA replicates before cell division.',
        'A word said once is not a suggestion.',
      ],
    );
    expect(terms, ['Mitosis', 'cell division', 'nucleus', 'dna']);
  });

  test('at most max; nothing for empty pages', () {
    expect(rankTerms(pageTexts: const []), isEmpty);
    expect(
        rankTerms(pageTexts: ['alpha alpha beta beta gamma gamma'], max: 2)
            .length,
        2);
  });

  test('titles capitalise plain terms and keep written capitals', () {
    expect(asTitle('cell division'), 'Cell Division');
    expect(asTitle('DNA replication'), 'DNA replication');
  });
}
