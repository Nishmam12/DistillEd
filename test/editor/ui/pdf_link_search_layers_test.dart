// The link layer over imported PDF pages, the search tint, and the contents
// section of the outline. Links and words come from fakes: real file reads
// inside widget tests hang.


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/persistence/scene_element_store.dart';
import 'package:margo/domain/geometry/search_matches.dart';
import 'package:margo/domain/model/page_links.dart';
import 'package:margo/domain/model/page_words.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/page_notifier.dart';
import 'package:margo/editor/state/scene_controller.dart';
import 'package:margo/editor/state/search_highlight.dart';
import 'package:margo/editor/ui/pdf_link_layer.dart';
import 'package:margo/editor/ui/search_highlight_layer.dart';
import 'package:margo/features/home/domain/models/note_page.dart';
import 'package:margo/features/import/link_target.dart';
import 'package:margo/features/import/page_links_service.dart';
import 'package:margo/features/import/page_words_service.dart';
import 'package:margo/features/notebook/presentation/page_outline_screen.dart';
import 'package:margo/features/notebook/presentation/pdf_contents_provider.dart';

import '../state/page_notifier_test.dart' show FakePageRepository;

const ScenePageKey _key = (notebookId: 0, pageId: 0);

const _path = 'notes/0/imports/pdf_abc_1.png';
const _image = ImageElement(
  id: 'pdf',
  zOrder: 0,
  geometryData: [0, 0, 700, 500],
  relativeImagePath: _path,
  isLocked: true,
);

class _FakeLinks implements PageLinksService {
  _FakeLinks(this.links);
  final PageLinks links;
  @override
  String get docsDir => '';
  @override
  Future<PageLinks> linksFor(String relativeImagePath) async => links;
}

class _FakeWords implements PageWordsService {
  _FakeWords(this.words);
  final PageWords words;
  @override
  String get docsDir => '';
  @override
  OcrWordsReader get readWords => (_) async => words;
  @override
  PageWords? cached(String relativeImagePath) => words;
  @override
  Future<PageWords> wordsFor(String relativeImagePath) async => words;
  @override
  Future<PageWords> storedWordsFor(String relativeImagePath) async => words;
}

const _links = PageLinks(links: [
  PageLink(rect: Rect.fromLTRB(0.1, 0.1, 0.4, 0.15), destPage: 2),
  PageLink(rect: Rect.fromLTRB(0.5, 0.6, 0.8, 0.65), url: 'https://example.org'),
]);

Future<ProviderContainer> _scene(
  WidgetTester tester,
  Widget Function(ProviderContainer) child, {
  PageLinks links = _links,
  PageWords? words,
}) async {
  final container = ProviderContainer(retry: (_, _) => null, overrides: [
    sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
    pageLinksServiceProvider.overrideWithValue(_FakeLinks(links)),
    if (words != null)
      pageWordsServiceProvider.overrideWithValue(_FakeWords(words)),
  ]);
  addTearDown(container.dispose);
  await container.read(sceneControllerProvider(_key).notifier).addMany([_image]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: Stack(children: [Positioned.fill(child: child(container))])),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  group('PdfLinkLayer', () {
    Future<(ProviderContainer, List<(PageLink, String)>)> pump(
        WidgetTester tester) async {
      final followed = <(PageLink, String)>[];
      final c = await _scene(
        tester,
        (_) => PdfLinkLayer(
            pageKey: _key, onFollow: (l, p) => followed.add((l, p))),
      );
      return (c, followed);
    }

    testWidgets('with the hand tool, a tap on a link follows it',
        (tester) async {
      final (c, followed) = await pump(tester);
      c.read(editorToolProvider.notifier).setTool(EditorTool.hand);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('pdfLink_0')));
      await tester.pump();
      expect(followed, hasLength(1));
      expect(followed.single.$1.destPage, 2);
      expect(followed.single.$2, _path);

      await tester.tap(find.byKey(const Key('pdfLink_1')));
      expect(followed.last.$1.url, 'https://example.org');
    });

    testWidgets('in the select tool\'s Text mode too', (tester) async {
      final (c, followed) = await pump(tester);
      c.read(editorToolProvider.notifier)
        ..setTool(EditorTool.select)
        ..setSelectText(true);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('pdfLink_0')));
      expect(followed, hasLength(1));
    });

    testWidgets('with the pen, the eraser or plain selection there are no '
        'links to tap', (tester) async {
      final (c, followed) = await pump(tester);
      for (final tool in [EditorTool.pen, EditorTool.eraser, EditorTool.select]) {
        c.read(editorToolProvider.notifier).setTool(tool);
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('pdfLink_0')), findsNothing,
            reason: '$tool');
      }
      expect(followed, isEmpty);
    });

    testWidgets('a picture that is not a PDF page has no links', (tester) async {
      final c = ProviderContainer(retry: (_, _) => null, overrides: [
        sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
        pageLinksServiceProvider.overrideWithValue(_FakeLinks(_links)),
      ]);
      addTearDown(c.dispose);
      await c.read(sceneControllerProvider(_key).notifier).addMany([
        _image.copyWith(relativeImagePath: 'notes/0/photo.png'),
      ]);
      c.read(editorToolProvider.notifier).setTool(EditorTool.hand);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
              body: Stack(children: [
            Positioned.fill(
                child: PdfLinkLayer(pageKey: _key, onFollow: (_, _) {})),
          ])),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('pdfLink_0')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('matchWords', () {
    const words = PageWords(source: PageWordsSource.pdf, words: [
      PageWord(text: 'Cell', box: Rect.fromLTRB(0, 0, 0.1, 0.1), line: 0),
      PageWord(text: 'division', box: Rect.fromLTRB(0.1, 0, 0.3, 0.1), line: 0),
      PageWord(text: 'and', box: Rect.fromLTRB(0, 0.2, 0.1, 0.3), line: 1),
      PageWord(text: 'cells', box: Rect.fromLTRB(0.1, 0.2, 0.2, 0.3), line: 1),
    ]);

    test('a phrase across words and a line break tints each word', () {
      final m = matchWords(words, 'division and');
      expect(m.matches, 1);
      expect(m.indexes, {1, 2});
    });

    test('a match inside a word tints the word, case ignored, and counts '
        'every match', () {
      final m = matchWords(words, 'CELL');
      expect(m.matches, 2);
      expect(m.indexes, {0, 3});
    });

    test('Find and the tint agree: whatever Find would match is tinted', () {
      for (final q in ['ell d', 'on  and  ce', 'vision']) {
        expect(matchWords(words, q).matches, 1, reason: q);
      }
    });

    test('a blank query or no words matches nothing', () {
      expect(matchWords(words, '  ').matches, 0);
      expect(matchWords(PageWords.empty, 'cell').matches, 0);
      expect(matchWords(words, 'zebra').indexes, isEmpty);
    });
  });

  group('SearchHighlightLayer', () {
    const words = PageWords(source: PageWordsSource.pdf, words: [
      PageWord(text: 'Cell', box: Rect.fromLTRB(0.1, 0.1, 0.2, 0.15), line: 0),
      PageWord(text: 'division', box: Rect.fromLTRB(0.22, 0.1, 0.4, 0.15), line: 0),
      PageWord(text: 'cell', box: Rect.fromLTRB(0.1, 0.3, 0.2, 0.35), line: 1),
    ]);

    Future<ProviderContainer> pump(WidgetTester tester) => _scene(
          tester,
          (_) => const SearchHighlightLayer(pageKey: _key),
          words: words,
        );

    testWidgets('tints the words and says how many, and the chip clears it',
        (tester) async {
      final c = await pump(tester);
      expect(find.byKey(const Key('searchHighlightChip')), findsNothing);

      c.read(searchHighlightProvider.notifier).state =
          const SearchHighlight(pageId: 0, query: 'cell');
      await tester.pump();
      await tester.pump();
      expect(find.text('2 matches on this page'), findsOneWidget);
      expect(find.byKey(const Key('searchHighlightPaint')), findsOneWidget);

      await tester.tap(find.byKey(const Key('searchHighlightClear')));
      await tester.pump();
      expect(c.read(searchHighlightProvider), isNull);
      expect(find.byKey(const Key('searchHighlightChip')), findsNothing);
    });

    testWidgets('shows nothing for another page, or when nothing on the '
        'picture matches', (tester) async {
      final c = await pump(tester);
      c.read(searchHighlightProvider.notifier).state =
          const SearchHighlight(pageId: 99, query: 'cell');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('searchHighlightChip')), findsNothing);

      c.read(searchHighlightProvider.notifier).state =
          const SearchHighlight(pageId: 0, query: 'zebra');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('searchHighlightChip')), findsNothing);
    });
  });

  group('findLinkTargetPage', () {
    // Page 1 is hand-made; the rest came from an import.
    final pages = [for (var i = 0; i < 5; i++) _page(i + 1, imported: i != 0)];

    Future<List<SceneElement>> load(int pageId, {Set<int> showing = const {}}) async =>
        showing.contains(pageId)
            ? [_image.copyWith(relativeImagePath: 'notes/0/imports/pdf_abc_7.png')]
            : <SceneElement>[];

    test('finds the page showing the picture of the PDF page, wherever it '
        'moved to', () async {
      final at = await findLinkTargetPage(
        pages: pages,
        load: (id) => load(id, showing: {4}),
        fromImagePath: 'notes/0/imports/pdf_abc_1.png',
        destPage: 7,
        currentIndex: 0,
      );
      expect(at, 3);
    });

    test('with a copy, the nearest wins, the earlier on a tie', () async {
      Future<int?> from(int current) => findLinkTargetPage(
            pages: pages,
            load: (id) => load(id, showing: {2, 4}),
            fromImagePath: 'notes/0/imports/pdf_abc_1.png',
            destPage: 7,
            currentIndex: current,
          );
      expect(await from(0), 1);
      expect(await from(4), 3);
      expect(await from(2), 1, reason: 'both are 1 away: the earlier');
    });

    test('a page that was not imported has no target', () async {
      expect(
          await findLinkTargetPage(
            pages: pages,
            load: (id) => load(id),
            fromImagePath: 'notes/0/imports/pdf_abc_1.png',
            destPage: 7,
            currentIndex: 0,
          ),
          isNull);
      expect(
          await findLinkTargetPage(
            pages: pages,
            load: (id) => load(id, showing: {2}),
            fromImagePath: 'notes/0/photo.png',
            destPage: 7,
            currentIndex: 0,
          ),
          isNull);
    });
  });

  group('outline contents', () {
    testWidgets('the PDF contents come first, indented, and a tap opens the '
        'page', (tester) async {
      final container = ProviderContainer(retry: (_, _) => null, overrides: [
        pageRepositoryProvider.overrideWithValue(FakePageRepository()),
        sceneElementStoreProvider.overrideWithValue(InMemorySceneElementStore()),
        pdfContentsProvider(0).overrideWith((ref) async => const [
              PdfContentsItem(title: 'Cells', depth: 0, pageIndex: 1),
              PdfContentsItem(title: 'Mitosis', depth: 1, pageIndex: 2),
            ]),
      ]);
      addTearDown(container.dispose);
      final pages = container.read(pageProvider(0).notifier);
      await pages.initialize();
      await pages.insertPage();
      await pages.insertPage();
      await pages.setBookmarked(container.read(pageProvider(0)).pages[0].id, true);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PageOutlineScreen(notebookId: 0)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PDF contents'), findsOneWidget);
      expect(find.text('Your pages'), findsOneWidget);
      final cells = tester.getTopLeft(find.text('Cells')).dx;
      final mitosis = tester.getTopLeft(find.text('Mitosis')).dx;
      expect(mitosis, greaterThan(cells), reason: 'indented by depth');

      await tester.tap(find.byKey(const Key('contentsEntry_1')));
      await tester.pumpAndSettle();
      expect(container.read(pageProvider(0)).currentPageIndex, 2);
    });
  });
}

NotePage _page(int id, {bool imported = true}) => NotePage()
  ..id = id
  ..notebookId = 0
  ..pageIndex = id - 1
  ..importGroupId = imported ? 'import-1' : null
  ..createdAt = DateTime(2026)
  ..modifiedAt = DateTime(2026);
