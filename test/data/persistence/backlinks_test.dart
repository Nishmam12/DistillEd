import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/services/selection_editing.dart';

TextElement _text(String id, {String link = ''}) => TextElement(
    id: id, zOrder: 0, geometryData: const [0, 0, 10, 10], text: id, color: 0, link: link);

void main() {
  test('pages linking to a page or its notebook, never the page itself',
      () async {
    final store = InMemorySceneElementStore();
    await store.upsertForPage(1, 10, [_text('self', link: 'page:20')]);
    await store.upsertForPage(1, 11, [_text('a', link: 'page:20')]);
    await store.upsertForPage(2, 30, [_text('b', link: 'notebook:1')]);
    await store.upsertForPage(2, 31, [_text('c', link: 'page:99')]);
    await store.upsertForPage(1, 20, [_text('own', link: 'page:20')]);

    expect(await store.pagesLinkingTo(pageId: 20, notebookId: 1), {10, 11, 30});
  });

  test('withLink sets and clears a link on any element', () {
    final linked = SelectionEditing.withLink(_text('t'), 'notebook:4');
    expect(linked.link, 'notebook:4');
    expect(SelectionEditing.withLink(linked, '').link, '');
  });
}
