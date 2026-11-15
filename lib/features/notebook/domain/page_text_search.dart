// Finding words in a notebook's pages, for "Search" on a text selection.
//
// Pure: searches the text the app already keeps for each page (what was read
// off it: handwriting, typed text, PDF text). Matching ignores case and runs of
// whitespace, so a phrase selected across a line break still matches.

import '../../../data/persistence/page_text_store.dart';

typedef PageTextHit = ({int pageId, String snippet});

/// The pages of [texts] that contain [query], in the order given, each with a
/// short [snippet] around the first match. Empty for a blank query.
List<PageTextHit> searchPageTexts(
  List<PageText> texts,
  String query, {
  int around = 40,
}) {
  final needle = _squash(query).toLowerCase();
  if (needle.isEmpty) return const [];
  final out = <PageTextHit>[];
  for (final t in texts) {
    final hay = _squash(t.text);
    final at = hay.toLowerCase().indexOf(needle);
    if (at < 0) continue;
    final start = (at - around).clamp(0, hay.length);
    final end = (at + needle.length + around).clamp(0, hay.length);
    out.add((
      pageId: t.pageId,
      snippet: '${start > 0 ? '…' : ''}${hay.substring(start, end)}'
          '${end < hay.length ? '…' : ''}',
    ));
  }
  return out;
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
