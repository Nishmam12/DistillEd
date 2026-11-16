import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/constants/storage_paths.dart';
import 'package:margo/domain/model/page_links.dart';
import 'package:margo/features/import/page_links_service.dart';
import 'package:margo/features/import/pdf_text_layer.dart';

PdfCharRect _r(double l, double b, double r, double t) =>
    (left: l, bottom: b, right: r, top: t);

void main() {
  group('PageLinks file', () {
    test('round trip', () {
      const links = PageLinks(links: [
        PageLink(rect: Rect.fromLTRB(0.1, 0.2, 0.3, 0.25), destPage: 7),
        PageLink(rect: Rect.fromLTRB(0.1, 0.5, 0.6, 0.55), url: 'https://a.b/c'),
      ], outline: [
        OutlineEntry(title: 'Cells', depth: 1, order: 4),
      ]);
      final back = PageLinks.decode(links.encode());
      expect(back.links, links.links);
      expect(back.outline, links.outline);
    });

    test('a damaged file reads as nothing, and bad entries are skipped', () {
      expect(PageLinks.decode('nope').isEmpty, isTrue);
      expect(PageLinks.decode('[]').isEmpty, isTrue);
      final back = PageLinks.decode('{"links":['
          '{"b":[0,0,1,1],"p":2},'
          '{"b":[0,0,1,1]},'
          '{"b":[0,0],"u":"x"},'
          '{"b":[0,"a",1,1],"u":"x"}],'
          '"outline":[{"t":"ok","d":1,"o":0},{"t":" ","d":0,"o":1},{"d":0}]}');
      expect(back.links.map((l) => l.destPage), [2]);
      expect(back.outline.map((o) => o.title), ['ok']);
    });
  });

  group('linksFromPdf', () {
    // Two 100 x 200 pt pages.
    const sizes = [(100.0, 200.0), (100.0, 200.0)];

    test('a link is flipped to a top-left origin and normalised', () {
      final out = linksFromPdf(
        sizes: sizes,
        links: [
          [
            (rects: [_r(10, 150, 60, 190)], url: null, destPage: 2),
          ],
          const [],
        ],
        outline: const [],
      );
      final l = out[0].links.single;
      expect(l.destPage, 2);
      expect(l.rect.left, closeTo(0.1, 1e-9));
      expect(l.rect.right, closeTo(0.6, 1e-9));
      expect(l.rect.top, closeTo(10 / 200, 1e-9)); // 200 - 190
      expect(l.rect.bottom, closeTo(50 / 200, 1e-9)); // 200 - 150
    });

    test('a link to a page the PDF lacks, or to nowhere, is dropped; a link '
        'to a page that was not imported is kept', () {
      final out = linksFromPdf(
        sizes: sizes,
        links: [
          [
            (rects: [_r(0, 0, 10, 10)], url: null, destPage: 9),
            (rects: [_r(0, 20, 10, 30)], url: null, destPage: null),
            (rects: [_r(0, 40, 10, 50)], url: 'https://x.org', destPage: null),
            (rects: [_r(0, 60, 10, 70)], url: null, destPage: 2),
          ],
          const [],
        ],
        outline: const [],
      );
      expect(out[0].links.map((l) => l.url ?? l.destPage), ['https://x.org', 2]);
    });

    test('a link with several rectangles (across lines) becomes several', () {
      final out = linksFromPdf(
        sizes: sizes,
        links: [
          [
            (
              rects: [_r(10, 100, 90, 110), _r(10, 85, 40, 95)],
              url: 'https://x.org',
              destPage: null,
            ),
          ],
          const [],
        ],
        outline: const [],
      );
      expect(out[0].links, hasLength(2));
    });

    test('contents entries are filed under the page they land on, in order, '
        'with depth; a heading with no page takes its first child\'s', () {
      final out = linksFromPdf(
        sizes: sizes,
        links: [const [], const []],
        outline: [
          PdfOutlineInput('Part A', null, [
            PdfOutlineInput('Intro', 1, const []),
            PdfOutlineInput('Cells', 2, const []),
          ]),
          PdfOutlineInput('Nowhere', null, const []),
          PdfOutlineInput('Bad page', 9, const []),
          PdfOutlineInput('End', 2, const []),
        ],
      );
      expect(out[0].outline.map((o) => (o.title, o.depth)),
          [('Part A', 0), ('Intro', 1)]);
      expect(out[1].outline.map((o) => (o.title, o.depth)),
          [('Cells', 1), ('End', 0)]);
      expect(out[1].outline.map((o) => o.order).toList(),
          orderedEquals([...out[1].outline.map((o) => o.order)]..sort()));
    });
  });

  group('addresses and sibling pictures', () {
    test('only web addresses are safe to open', () {
      for (final ok in [
        'https://example.org/a?b=1',
        'http://example.org',
      ]) {
        expect(isSafeLinkUrl(ok), isTrue, reason: ok);
      }
      for (final bad in [
        null,
        '',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://x#Intent;end',
        'tel:123',
        'https://',
        'mailto:me@example.org',
        'content://media/x',
        'https://${'a' * 2100}.com',
      ]) {
        expect(isSafeLinkUrl(bad), isFalse, reason: '$bad');
      }
    });

    test('the picture of another PDF page sits beside this one', () {
      expect(siblingPdfPagePath('notes/3/imports/pdf_AB12cd_4.png', 9),
          'notes/3/imports/pdf_AB12cd_9.png');
      expect(siblingPdfPagePath('notes/3/imports/photo.png', 9), isNull);
      expect(siblingPdfPagePath('notes/3/imports/pdf_ab_4.png', 0), isNull);
    });
  });

  group('PageLinksService', () {
    late Directory docs;
    const rel = 'notes/1/imports/pdf_abc_1.png';
    setUp(() => docs = Directory.systemTemp.createTempSync('margo_links_'));
    tearDown(() => docs.deleteSync(recursive: true));

    test('reads the sidecar, and nothing when there is none', () async {
      final service = PageLinksService(docsDir: docs.path);
      expect((await service.linksFor(rel)).isEmpty, isTrue);

      const links = PageLinks(outline: [OutlineEntry(title: 'A', depth: 0, order: 0)]);
      File(StoragePaths.pdfLinksSidecar('${docs.path}/$rel'))
        ..createSync(recursive: true)
        ..writeAsStringSync(links.encode());
      // A new service: the first one remembered "none".
      final fresh = PageLinksService(docsDir: docs.path);
      expect((await fresh.linksFor(rel)).outline.single.title, 'A');
    });

    test('a path outside the app files is refused', () async {
      expect(
          (await PageLinksService(docsDir: docs.path).linksFor('../x.png'))
              .isEmpty,
          isTrue);
    });
  });
}
