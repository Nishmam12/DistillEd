import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/notebook/domain/action_links.dart';

void main() {
  final now = DateTime(2026, 11, 17, 15);

  test('one chip per thing, in order, at most three; past dates dropped', () {
    final links = actionLinksFrom([
      (kind: ActionKind.date, text: 'yesterday', date: DateTime(2026, 11, 16)),
      (kind: ActionKind.web, text: 'margo.app/help', date: null),
      (kind: ActionKind.web, text: 'MARGO.app/help', date: null),
      (kind: ActionKind.date, text: 'Dec 3', date: DateTime(2026, 12, 3, 9)),
      (kind: ActionKind.date, text: '3 December', date: DateTime(2026, 12, 3)),
      (kind: ActionKind.phone, text: '(555) 123-4567', date: null),
      (kind: ActionKind.email, text: 'a@b.org', date: null),
    ], now: now);
    expect([for (final l in links) l.kind],
        [ActionKind.web, ActionKind.date, ActionKind.phone]);
    expect(links[1].date, DateTime(2026, 12, 3));
    expect(links[1].label, 'Add 3 Dec to study plan');
  });

  test('what each chip opens', () {
    ActionLink l(ActionKind k, String t) => ActionLink(kind: k, text: t);
    expect(l(ActionKind.web, 'margo.app').uri.toString(), 'https://margo.app');
    expect(l(ActionKind.web, 'http://x.org/a').uri.toString(), 'http://x.org/a');
    expect(l(ActionKind.email, 'a@b.org').uri.toString(), 'mailto:a@b.org');
    expect(l(ActionKind.phone, '+1 (555) 123-4567').uri.toString(),
        'tel:+15551234567');
    expect(l(ActionKind.address, '1 Main St').uri!.queryParameters['q'],
        '1 Main St');
    expect(l(ActionKind.address, '1 Main St').uri!.scheme, 'geo');
  });
}
