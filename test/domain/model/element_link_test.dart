import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/element_link.dart';

void main() {
  test('the three kinds round-trip through their stored form', () {
    for (final raw in ['page:12', 'notebook:3', 'url:https://example.com/a']) {
      expect(ElementLink.parse(raw)!.encoded, raw);
    }
    expect(ElementLink.parse('page:12'), isA<LinkToPage>());
    expect((ElementLink.parse('notebook:3') as LinkToNotebook).notebookId, 3);
  });

  test('empty, damaged or unsafe is no link', () {
    for (final raw in [
      '',
      'page:',
      'page:abc',
      'page:0',
      'notebook:-1',
      'mystery:1',
      ':12',
      'url:javascript:alert(1)',
      'url:file:///data/x',
      'url:mailto:a@b.c',
    ]) {
      expect(ElementLink.parse(raw), isNull, reason: raw);
    }
  });
}
