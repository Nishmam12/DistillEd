// Action chips for what a selection says (Samsung Notes' "action links"): a
// web address, an email, a phone number, a street address or a date found in
// the selected handwriting or text, each with the one thing to do with it.
//
// Pure: the entities come from ML Kit entity extraction on the device
// (`MlKitActionFinder`); this decides which are worth a chip and what each
// opens.

/// What was found.
enum ActionKind { web, email, phone, address, date }

/// One entity in the text, as the extractor reports it.
typedef FoundEntity = ({ActionKind kind, String text, DateTime? date});

class ActionLink {
  final ActionKind kind;

  /// As written, for the chip.
  final String text;

  /// The day, for [ActionKind.date].
  final DateTime? date;

  const ActionLink({required this.kind, required this.text, this.date});

  /// What the chip opens; null for a date (it goes to the study plan).
  Uri? get uri => switch (kind) {
        ActionKind.web => Uri.tryParse(
            RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false)
                    .hasMatch(text)
                ? text
                : 'https://$text'),
        ActionKind.email => Uri(scheme: 'mailto', path: text),
        // Digits and a leading + only: handwriting recognised "(555) 123-4567".
        ActionKind.phone => Uri(
            scheme: 'tel', path: text.replaceAll(RegExp(r'[^\d+]'), '')),
        ActionKind.address =>
          Uri(scheme: 'geo', path: '0,0', queryParameters: {'q': text}),
        ActionKind.date => null,
      };

  /// The chip's label: the verb and what it acts on.
  String get label => switch (kind) {
        ActionKind.web => 'Open $text',
        ActionKind.email => 'Email $text',
        ActionKind.phone => 'Call $text',
        ActionKind.address => 'Map $text',
        ActionKind.date => 'Add ${_day(date!)} to study plan',
      };

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}

/// The chips for [found]: one per distinct thing, in the order written, at
/// most [max] so the bar stays calm. A date is kept only from today on.
List<ActionLink> actionLinksFrom(
  List<FoundEntity> found, {
  required DateTime now,
  int max = 3,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <ActionLink>[];
  final seen = <String>{};
  for (final e in found) {
    if (out.length == max) break;
    final text = e.text.trim();
    if (text.isEmpty) continue;
    DateTime? day;
    if (e.kind == ActionKind.date) {
      final d = e.date;
      if (d == null) continue;
      day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(today)) continue;
    }
    final key = e.kind == ActionKind.date
        ? 'date:$day'
        : '${e.kind.name}:${text.toLowerCase()}';
    if (!seen.add(key)) continue;
    out.add(ActionLink(kind: e.kind, text: text, date: day));
  }
  return out;
}
