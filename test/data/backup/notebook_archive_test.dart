import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/backup/notebook_archive.dart';
import 'package:margo/domain/model/scene_element.dart';

NotebookSnapshot sample({int sourceId = 12, String text = 'Mitosis has four phases'}) =>
    NotebookSnapshot(
      sourceId: sourceId,
      meta: NotebookMeta(
        title: 'Biology',
        backgroundColor: 0xFFFFFDF7,
        templateIndex: 2,
        layoutMode: 1,
        tags: const ['exam', 'cells'],
        createdAt: DateTime.utc(2026, 9, 1),
      ),
      pages: [
        PageSnapshot(
          text: text,
          elements: const [
            FreehandElement(
              id: 's1',
              zOrder: 0,
              color: 0xFF000000,
              size: 3,
              penKind: PenKind.fountain,
              points: [StrokePoint(x: 1, y: 2, pressure: 0.4), StrokePoint(x: 5, y: 6)],
            ),
          ],
        ),
        PageSnapshot(
          importGroupId: 'import-1',
          importSourceName: 'lecture.pdf',
          text: '',
          elements: [
            ImageElement(
              id: 'img',
              zOrder: 0,
              geometryData: const [0, 0, 100, 140],
              relativeImagePath: 'notes/$sourceId/imports/pdf_abc_1.png',
              isLocked: true,
            ),
          ],
        ),
      ],
      media: {
        'notes/$sourceId/imports/pdf_abc_1.png': Uint8List.fromList([1, 2, 3, 4]),
        'notes/$sourceId/imports/pdf_abc_1.txt': Uint8List.fromList(utf8.encode('slide text')),
      },
    );

void main() {
  group('encode / decode', () {
    test('everything survives the round trip', () {
      final back = NotebookArchive.decode(NotebookArchive.encode(sample()));

      expect(back.sourceId, 12);
      expect(back.meta.title, 'Biology');
      expect(back.meta.templateIndex, 2);
      expect(back.meta.layoutMode, 1);
      expect(back.meta.backgroundColor, 0xFFFFFDF7);
      expect(back.meta.tags, ['exam', 'cells']);
      expect(back.pages, hasLength(2));
      expect(back.pages[0].text, 'Mitosis has four phases');
      final stroke = back.pages[0].elements.single as FreehandElement;
      expect(stroke.penKind, PenKind.fountain);
      expect(stroke.points[0].pressure, 0.4);
      expect(back.pages[1].importSourceName, 'lecture.pdf');
      expect(back.pages[1].importGroupId, 'import-1');
      expect((back.pages[1].elements.single as ImageElement).isLocked, isTrue);
      expect(back.media.keys, containsAll(sample().media.keys));
      expect(back.media['notes/12/imports/pdf_abc_1.png'], [1, 2, 3, 4]);
    });

    test('carries a readable markdown copy', () {
      final zip = ZipDecoder().decodeBytes(NotebookArchive.encode(sample()));
      final md = utf8.decode(zip.findFile('notebook.md')!.content as List<int>);
      expect(md, contains('# Biology'));
      expect(md, contains('Mitosis has four phases'));
      expect(md, contains('lecture.pdf'));
    });

    test('a file that is not a Margo notebook is refused', () {
      final notMargo = ZipEncoder().encodeBytes(
          Archive()..add(ArchiveFile.string('hello.txt', 'hi')));
      expect(() => NotebookArchive.decode(Uint8List.fromList(notMargo)),
          throwsA(isA<NotebookArchiveException>()));
      expect(() => NotebookArchive.decode(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<NotebookArchiveException>()));
    });

    test('a media entry that would land outside the notes folder is dropped',
        () {
      final good = NotebookArchive.encode(sample());
      final zip = ZipDecoder().decodeBytes(good);
      final evil = Archive();
      for (final f in zip.files) {
        evil.add(f);
      }
      evil.add(ArchiveFile.bytes('media/../margo.isar', [9, 9]));
      evil.add(ArchiveFile.bytes('media/notes/12/../../x.png', [9, 9]));
      final back = NotebookArchive.decode(
          Uint8List.fromList(ZipEncoder().encodeBytes(evil)));
      expect(back.media.keys.every((k) => k.startsWith('notes/12/')), isTrue);
      expect(back.media, hasLength(2));
    });
  });

  group('markdown', () {
    test('a page with no text read yet says so rather than vanishing', () {
      final md = NotebookArchive.markdown(sample(text: ''));
      expect(md, contains('## Page 1'));
      expect(md, contains('## Page 2'));
    });
  });

  group('fingerprint', () {
    test('the same notebook gives the same fingerprint', () {
      expect(NotebookArchive.fingerprint(sample()),
          NotebookArchive.fingerprint(sample()));
    });

    test('changing the ink or the text changes it', () {
      expect(NotebookArchive.fingerprint(sample(text: 'other')),
          isNot(NotebookArchive.fingerprint(sample())));
    });
  });

  group('remap', () {
    test('moves the notebook\'s own files under its new id', () {
      final moved = sample().remappedTo(40);
      final image = moved.pages[1].elements.single as ImageElement;
      expect(image.relativeImagePath, 'notes/40/imports/pdf_abc_1.png');
      expect(moved.media.keys,
          everyElement(startsWith('notes/40/')));
    });
  });
}
