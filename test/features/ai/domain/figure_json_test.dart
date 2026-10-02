// A figure the model read is cached on disk so the same picture is never read
// twice (see read_cache.dart), which means it has to survive being written out
// and read back EXACTLY — a figure that comes back slightly different would make
// a cached session disagree with the session that produced it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/figure.dart';

void main() {
  const full = FigureDescription(
    kind: FigureKind.chart,
    title: 'Quarterly revenue',
    summary: 'A bar chart of revenue across the four quarters of 2024.',
    axes: ['x: quarter (Q1-Q4)', 'y: revenue in thousands'],
    series: [
      FigureSeries(label: 'Revenue', detail: 'rises from 2 to 9'),
      FigureSeries(label: 'Costs'),
    ],
    insight: 'Revenue roughly quadruples over the year.',
    verbatimText: 'Q1 2\nQ2 4\nQ3 7\nQ4 9',
    confidence: 0.85,
    modelId: 'gemma-4-E2B-it.litertlm',
  );

  test('every field survives a trip through JSON text', () {
    final back = FigureDescription.fromJson(
        jsonDecode(jsonEncode(full.toJson())) as Map<String, dynamic>)!;

    expect(back, full);
  });

  test('a sparse figure — no title, axes, series or insight — round-trips too',
      () {
    const sparse = FigureDescription(
      kind: FigureKind.equation,
      summary: 'A quadratic equation written out in full on the page.',
    );

    final back = FigureDescription.fromJson(
        jsonDecode(jsonEncode(sparse.toJson())) as Map<String, dynamic>)!;

    expect(back, sparse);
    expect(back.axes, isEmpty);
    expect(back.series, isEmpty);
  });

  test('every kind keeps its identity', () {
    for (final kind in FigureKind.values) {
      final figure =
          FigureDescription(kind: kind, summary: 'Some summary of the figure.');
      final back = FigureDescription.fromJson(
          jsonDecode(jsonEncode(figure.toJson())) as Map<String, dynamic>)!;
      expect(back.kind, kind);
    }
  });

  test('a stored entry that is damaged reads as nothing rather than throwing',
      () {
    // A cache must never be able to take a page read down with it.
    expect(FigureDescription.fromJson(const {}), isNull);
    expect(FigureDescription.fromJson(const {'kind': 'chart'}), isNull,
        reason: 'no summary: not a usable figure');
    expect(
        FigureDescription.fromJson(
            const {'kind': 'chart', 'summary': 7, 'axes': 'oops'}),
        isNull);
  });
}
