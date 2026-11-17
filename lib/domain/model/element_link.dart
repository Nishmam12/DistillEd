// Where an element's link goes (`SceneElement.link`): another page, a whole
// notebook, or a web address. Kept as one short string on the element
// (`page:12`, `notebook:3`, `url:https://…`) so it stores, backs up and copies
// like any other field, and an unknown or damaged one is simply no link.

import 'page_links.dart' show isSafeLinkUrl;

sealed class ElementLink {
  const ElementLink();

  /// The stored form.
  String get encoded;

  /// [raw] as a link; null for '' and anything unreadable — including a web
  /// address that is not plain http(s), which is never followed.
  static ElementLink? parse(String raw) {
    final colon = raw.indexOf(':');
    if (colon <= 0) return null;
    final kind = raw.substring(0, colon);
    final value = raw.substring(colon + 1);
    return switch (kind) {
      'page' => switch (int.tryParse(value)) {
          final id? when id > 0 => LinkToPage(id),
          _ => null,
        },
      'notebook' => switch (int.tryParse(value)) {
          final id? when id > 0 => LinkToNotebook(id),
          _ => null,
        },
      'url' => isSafeLinkUrl(value) ? LinkToWeb(value.trim()) : null,
      _ => null,
    };
  }
}

final class LinkToPage extends ElementLink {
  final int pageId;
  const LinkToPage(this.pageId);
  @override
  String get encoded => 'page:$pageId';
}

final class LinkToNotebook extends ElementLink {
  final int notebookId;
  const LinkToNotebook(this.notebookId);
  @override
  String get encoded => 'notebook:$notebookId';
}

final class LinkToWeb extends ElementLink {
  final String url;
  const LinkToWeb(this.url);
  @override
  String get encoded => 'url:$url';
}
