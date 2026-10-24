// Stored image/audio paths can come from pasted JSON; deleting a page must never
// remove a file outside the app's own notes/ and audio/ (docs/SECURITY_REVIEW.md
// item 1: a pasted `margo.isar` path wiped the database on page delete).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/core/constants/storage_paths.dart';
import 'package:margo/data/persistence/content_purge.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/clipboard_service.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isSafeRelativePath accepts only the app\'s own layout', () {
    for (final ok in ['notes/1/imports/a.png', 'audio/n1_p2_3.m4a']) {
      expect(StoragePaths.isSafeRelativePath(ok), isTrue, reason: ok);
    }
    for (final bad in [
      '', 'margo.isar', 'margo_library.json', '/notes/1/a.png',
      'notes/../margo.isar', 'notes/./a', 'notes//a', r'notes\..\margo.isar',
      'C:/x', 'other/a.png',
    ]) {
      expect(StoragePaths.isSafeRelativePath(bad), isFalse, reason: bad);
    }
  });

  group('deleteContentFiles', () {
    late Directory docs;

    setUp(() async {
      docs = await Directory.systemTemp.createTemp('path_safety_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathChannel, (_) async => docs.path);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathChannel, null);
      await docs.delete(recursive: true);
    });

    File touch(String rel) =>
        File('${docs.path}/$rel')..createSync(recursive: true);

    test('removes app files, leaves everything else', () async {
      final image = touch('notes/1/imports/a.png');
      final audio = touch('audio/n1_p1_1.m4a');
      final db = touch('margo.isar');
      final nested = touch('notes/x.json');

      await deleteContentFiles(
        fileRelativePaths: [
          'notes/1/imports/a.png',
          'margo.isar',
          'notes/1/../../margo.isar',
          '/${db.path}',
          'notes/../notes/x.json',
        ],
        audioRelativePaths: ['audio/n1_p1_1.m4a', '../margo.isar'],
      );

      expect(image.existsSync(), isFalse);
      expect(audio.existsSync(), isFalse);
      expect(db.existsSync(), isTrue);
      expect(nested.existsSync(), isTrue);
    });
  });

  test('pasted image elements pointing outside app files are dropped', () {
    ImageElement image(String path) => ImageElement(
          id: path,
          zOrder: 0,
          geometryData: const [0, 0, 10, 10],
          relativeImagePath: path,
        );
    final text = ClipboardService.encode([
      image('notes/1/imports/a.png'),
      image('margo.isar'),
      image('../margo.isar'),
      image(''),
    ]);
    // Sanity: the attacker JSON really carries the bad paths.
    expect(jsonDecode(text).toString(), contains('margo.isar'));

    final pasted = ClipboardService.tryDecode(text)!;
    expect(
      pasted.map((e) => (e as ImageElement).relativeImagePath),
      ['notes/1/imports/a.png', ''],
    );
  });
}
