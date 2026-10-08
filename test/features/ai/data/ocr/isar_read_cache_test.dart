// The Isar-backed read cache against a REAL database.
//
// The replace-by-key and trim-the-oldest rules live in the store's queries, so a
// fake would test nothing. Isar needs its native library; this finds the one
// shipped by isar_community_flutter_libs through the package config (so it works on any
// machine where the package is resolved) and skips itself if it can't.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:inkflow/features/ai/data/ocr/isar_read_cache.dart';
import 'package:inkflow/features/ai/data/ocr/read_cache_record.dart';
import 'package:inkflow/features/ai/domain/figure.dart';
import 'package:inkflow/features/ai/domain/read_cache.dart';

Future<String?> _nativeLibrary() async {
  // `flutter test` runs from the project root, and the package resolver is not
  // available to the test isolate, so read the package config directly.
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  final entry = packages
      .cast<Map>()
      .where((p) => p['name'] == 'isar_community_flutter_libs');
  if (entry.isEmpty) return null;
  final rootUri = Uri.parse(entry.first['rootUri'] as String);
  final root = rootUri.isAbsolute
      ? File.fromUri(rootUri).path
      : File.fromUri(config.parent.uri.resolveUri(rootUri)).path;
  final candidate = switch (Abi.current()) {
    Abi.linuxX64 => '$root/linux/libisar.so',
    Abi.windowsX64 => '$root/windows/isar.dll',
    Abi.macosX64 || Abi.macosArm64 => '$root/macos/libisar.dylib',
    _ => null,
  };
  return candidate != null && File(candidate).existsSync() ? candidate : null;
}

void main() {
  late Isar isar;
  late Directory dir;
  String? skipReason;

  setUpAll(() async {
    final lib = await _nativeLibrary();
    if (lib == null) {
      skipReason = 'Isar native library not found for this platform';
      return;
    }
    await Isar.initializeIsarCore(libraries: {Abi.current(): lib});
  });

  setUp(() async {
    if (skipReason != null) return;
    dir = await Directory.systemTemp.createTemp('read_cache_test');
    isar = await Isar.open([ReadCacheRecordSchema],
        directory: dir.path, name: 'read_cache_test');
  });

  tearDown(() async {
    if (skipReason != null) return;
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  IsarReadCache cache({int max = 4000, int batch = 250}) => IsarReadCache(
      isar: () => isar, maxEntries: max, trimBatch: batch);

  test('a saved read comes back, text and figure both', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    const figure = FigureDescription(
      kind: FigureKind.chart,
      title: 'Revenue',
      summary: 'A bar chart of revenue across four quarters.',
      series: [FigureSeries(label: 'Revenue', detail: 'rises')],
      confidence: 0.9,
      modelId: 'local',
    );

    await cache().save('k', const CachedRead(text: 'hello', figure: figure));

    final hit = await cache().find('k');
    expect(hit!.text, 'hello');
    expect(hit.figure, figure);
  });

  test('a read with no figure comes back with none', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    await cache().save('k', const CachedRead(text: 'only words'));
    expect((await cache().find('k'))!.figure, isNull);
  });

  test('an unknown key finds nothing', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    expect(await cache().find('missing'), isNull);
  });

  test('saving a key again leaves ONE row, holding the new read', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final c = cache();
    await c.save('k', const CachedRead(text: 'old'));
    await c.save('k', const CachedRead(text: 'new'));

    expect((await c.find('k'))!.text, 'new');
    expect(await isar.readCacheRecords.count(), 1,
        reason: 'a duplicate row would make which read wins arbitrary');
  });

  test('past its size the OLDEST reads are dropped, the newest kept', () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final c = cache(max: 5, batch: 2);
    for (var i = 0; i < 6; i++) {
      await c.save('k$i', CachedRead(text: 'read $i'));
    }

    // 6 > 5 trims the excess (1) plus the batch (2): k0, k1, k2 go.
    expect(await c.find('k0'), isNull);
    expect(await c.find('k1'), isNull);
    expect(await c.find('k2'), isNull);
    for (final k in ['k3', 'k4', 'k5']) {
      expect(await c.find(k), isNotNull, reason: '$k is among the newest');
    }
    expect(await isar.readCacheRecords.count(), 3);
  });

  test('re-saving a read makes it new again, so it outlives older ones',
      () async {
    if (skipReason != null) return markTestSkipped(skipReason!);
    final c = cache(max: 3, batch: 1);
    await c.save('a', const CachedRead(text: 'a'));
    await c.save('b', const CachedRead(text: 'b'));
    await c.save('c', const CachedRead(text: 'c'));
    await c.save('a', const CachedRead(text: 'a again')); // refresh a
    await c.save('d', const CachedRead(text: 'd')); // forces a trim

    expect(await c.find('b'), isNull, reason: 'b is now the oldest');
    expect(await c.find('a'), isNotNull);
  });
}
