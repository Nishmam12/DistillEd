import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:margo/data/backup/backup_service.dart';
import 'package:margo/data/backup/notebook_archive.dart';
import 'package:margo/domain/model/scene_element.dart';

NotebookSnapshot snap(int id, {String title = 'Notes', String text = 'hello'}) =>
    NotebookSnapshot(
      sourceId: id,
      meta: NotebookMeta(
        title: title,
        backgroundColor: 0xFFFFFFFF,
        templateIndex: 0,
        layoutMode: 0,
        tags: const [],
        createdAt: DateTime.utc(2026),
      ),
      pages: [
        PageSnapshot(text: text, elements: const [
          FreehandElement(
              id: 's', zOrder: 0, color: 0xFF000000, size: 2,
              points: [StrokePoint(x: 0, y: 0)]),
        ]),
      ],
      media: const {},
    );

class _FakeLibrary implements BackupLibrary {
  final Map<int, NotebookSnapshot> notebooks;
  final Set<int> failing;
  final List<NotebookSnapshot> added = [];
  _FakeLibrary(this.notebooks, {this.failing = const {}});

  @override
  Future<List<int>> notebookIds() async => notebooks.keys.toList();
  @override
  Future<NotebookSnapshot?> snapshot(int id) async {
    if (failing.contains(id)) throw StateError('disk said no');
    return notebooks[id];
  }

  @override
  Future<int> add(NotebookSnapshot s) async {
    added.add(s);
    return 100 + added.length;
  }
}

class _FakeTarget implements BackupTarget {
  final Map<String, Uint8List> files = {};
  final List<String> deleted = [];
  bool failDelete = false;
  @override
  Future<String> save(String sourcePath, String name, String mimeType) async {
    files[name] = File(sourcePath).readAsBytesSync();
    return 'Download/Margo';
  }

  @override
  Future<void> delete(String name) async {
    if (failDelete) throw StateError('no');
    deleted.add(name);
    files.remove(name);
  }

  @override
  Future<List<BackupFile>> list() async => [
        for (final e in files.entries)
          BackupFile(e.key, e.value.length, DateTime.utc(2026)),
      ];

  @override
  Future<void> copyOut(String name, String destPath) async =>
      File(destPath).writeAsBytesSync(files[name]!);
}

class _MemoryState implements BackupStateStore {
  BackupState state = BackupState.empty;
  @override
  Future<BackupState> load() async => state;
  @override
  Future<void> save(BackupState s) async => state = s;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('margo_backup_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  BackupService service(_FakeLibrary lib, _FakeTarget target, _MemoryState state,
          {DateTime? now}) =>
      BackupService(
        library: lib,
        target: target,
        state: state,
        tempDir: () async => tmp.path,
        clock: () => now ?? DateTime.utc(2026, 11, 11, 10),
        // Tests run on one isolate.
        runInBackground: false,
      );

  test('writes a .margo and a .md for each notebook', () async {
    final lib = _FakeLibrary({1: snap(1, title: 'Biology'), 2: snap(2, title: 'Maths')});
    final target = _FakeTarget();
    final report = await service(lib, target, _MemoryState()).run();

    expect(report.written, 2);
    expect(target.files.keys, containsAll([
      'Biology (1) 2026-11-11 1000.margo', 'Biology (1).md',
      'Maths (2) 2026-11-11 1000.margo', 'Maths (2).md',
    ]));
    final back = NotebookArchive.decode(
        target.files['Biology (1) 2026-11-11 1000.margo']!);
    expect(back.meta.title, 'Biology');
  });

  test('an unchanged notebook is not written again', () async {
    final lib = _FakeLibrary({1: snap(1)});
    final target = _FakeTarget();
    final state = _MemoryState();
    await service(lib, target, state).run();
    target.files.clear();

    final report = await service(lib, target, state).run();
    expect(report.written, 0);
    expect(report.unchanged, 1);
    expect(target.files, isEmpty);
  });

  test('a changed notebook is written again', () async {
    final lib = _FakeLibrary({1: snap(1)});
    final target = _FakeTarget();
    final state = _MemoryState();
    await service(lib, target, state).run();

    lib.notebooks[1] = snap(1, text: 'new writing');
    final report = await service(lib, target, state).run();
    expect(report.written, 1);
  });

  List<String> margos(_FakeTarget t) =>
      (t.files.keys.where((n) => n.endsWith('.margo')).toList()..sort());

  Future<void> change(_FakeLibrary lib, _FakeTarget t, _MemoryState st, int n,
      {String title = 'Notes'}) async {
    lib.notebooks[1] = snap(1, title: title, text: 'v$n');
    await service(lib, t, st, now: DateTime.utc(2026, 11, 11, 10, n)).run();
  }

  test('each change is a new dated snapshot; the last five are kept', () async {
    final lib = _FakeLibrary({1: snap(1)});
    final target = _FakeTarget();
    final state = _MemoryState();
    for (var n = 1; n <= 7; n++) {
      await change(lib, target, state, n);
    }
    expect(margos(target), [
      'Notes (1) 2026-11-11 1003.margo',
      'Notes (1) 2026-11-11 1004.margo',
      'Notes (1) 2026-11-11 1005.margo',
      'Notes (1) 2026-11-11 1006.margo',
      'Notes (1) 2026-11-11 1007.margo',
    ]);
    expect(target.files.keys.where((n) => n.endsWith('.md')), ['Notes (1).md']);
  });

  test('"Back up now" on an unchanged notebook adds no snapshot', () async {
    final lib = _FakeLibrary({1: snap(1)});
    final target = _FakeTarget();
    final state = _MemoryState();
    await service(lib, target, state).run();
    for (var i = 0; i < 6; i++) {
      final r = await service(lib, target, state).run(force: true);
      expect(r.written, 0);
    }
    expect(margos(target), hasLength(1));
  });

  test('two snapshots in one minute do not overwrite each other', () async {
    final lib = _FakeLibrary({1: snap(1)});
    final target = _FakeTarget();
    final state = _MemoryState();
    final at = DateTime.utc(2026, 11, 11, 10, 30);
    await service(lib, target, state, now: at).run();
    lib.notebooks[1] = snap(1, text: 'other');
    await service(lib, target, state, now: at).run();
    expect(margos(target),
        ['Notes (1) 2026-11-11 1030-2.margo', 'Notes (1) 2026-11-11 1030.margo']);
  });

  test('a renamed notebook keeps its history and drops only its old .md',
      () async {
    final lib = _FakeLibrary({1: snap(1, title: 'Old')});
    final target = _FakeTarget();
    final state = _MemoryState();
    await change(lib, target, state, 1, title: 'Old');
    await change(lib, target, state, 2, title: 'New');
    expect(target.deleted, ['Old (1).md']);
    expect(margos(target), [
      'New (1) 2026-11-11 1002.margo',
      'Old (1) 2026-11-11 1001.margo',
    ]);
    expect(target.files.containsKey('New (1).md'), isTrue);
  });

  test('a file from before snapshots counts as the oldest and is pruned',
      () async {
    final lib = _FakeLibrary({1: snap(1)});
    final target = _FakeTarget()..files['Notes (1).margo'] = Uint8List(1);
    final state = _MemoryState()
      ..state = BackupState(records: {
        1: BackupRecord(NotebookArchive.fingerprint(snap(1)), 'Notes (1)'),
      });
    for (var n = 1; n <= 5; n++) {
      await change(lib, target, state, n);
    }
    expect(target.files.containsKey('Notes (1).margo'), isFalse);
    expect(margos(target), hasLength(5));
  });

  test('a snapshot that will not delete does not fail the backup', () async {
    final lib = _FakeLibrary({1: snap(1)});
    final target = _FakeTarget()..failDelete = true;
    final state = _MemoryState();
    for (var n = 1; n <= 6; n++) {
      await change(lib, target, state, n);
    }
    expect(state.state.lastError, isNull);
    expect(margos(target), hasLength(6));
    target.failDelete = false;
    await change(lib, target, state, 7);
    expect(margos(target), hasLength(5));
  });

  test('state saved before snapshots still loads', () {
    final back = BackupState.fromJson({
      'records': {
        '4': {'fp': 'abc', 'name': 'Biology (4)'},
      },
    });
    expect(back.records[4]!.snapshots, isEmpty);
    final again = BackupState.fromJson(back.toJson());
    expect(again.records[4]!.fileName, 'Biology (4)');
    final withSnaps = BackupState.fromJson({
      'records': {
        '4': {'fp': 'abc', 'name': 'B (4)', 'snaps': ['a.margo', 7]},
      },
    });
    expect(withSnaps.records[4]!.snapshots, ['a.margo']);
  });

  test('available lists only .margo backups, newest first; restoreNamed '
      'restores one as a copy', () async {
    final lib = _FakeLibrary({});
    final target = _FakeTarget()
      ..files['Physics (7) 2026-11-11 1001.margo'] =
          NotebookArchive.encode(snap(7, title: 'Physics'))
      ..files['Physics (7).md'] = Uint8List(1)
      ..files['stray.margo'] = Uint8List(1);
    final svc = service(lib, target, _MemoryState());
    final files = await svc.available();
    expect(files.map((f) => f.name), ['Physics (7) 2026-11-11 1001.margo']);

    final report = await svc.restoreNamed(files.single.name);
    expect(report.restored, ['Physics']);
    expect(lib.added, hasLength(1));
    final broken = await svc.restoreNamed('missing.margo');
    expect(broken.failed, isNotEmpty);
    expect(tmp.listSync().whereType<File>().where((f) => f.path.contains('restore_')),
        isEmpty);
  });

  group('backup names', () {
    test('a snapshot name reads back to its notebook and time', () {
      final p = parseBackupName('Bio (3) (12) 2026-11-11 1030-2.margo')!;
      expect((p.title, p.id), ('Bio (3)', 12));
      expect(p.at, DateTime(2026, 11, 11, 10, 30));
      expect(parseBackupName('Notes (4).margo')!.at, isNull);
      expect(parseBackupName('Notes (4).md'), isNull);
      expect(parseBackupName('random.margo'), isNull);
    });
  });

  test('one notebook failing does not stop the rest, and is reported', () async {
    final lib = _FakeLibrary({1: snap(1), 2: snap(2)}, failing: {1});
    final target = _FakeTarget();
    final state = _MemoryState();
    final report = await service(lib, target, state).run();

    expect(report.written, 1);
    expect(report.failed, 1);
    expect(state.state.lastError, isNotNull);
    expect(state.state.lastSuccessAt, isNull);
  });

  test('a clean run records when and where', () async {
    final state = _MemoryState();
    await service(_FakeLibrary({1: snap(1)}), _FakeTarget(), state,
            now: DateTime.utc(2026, 11, 11, 9))
        .run();
    expect(state.state.lastRunAt, DateTime.utc(2026, 11, 11, 9));
    expect(state.state.lastSuccessAt, DateTime.utc(2026, 11, 11, 9));
    expect(state.state.location, 'Download/Margo');
    expect(state.state.lastError, isNull);
  });

  test('restore adds each file as a new notebook', () async {
    final lib = _FakeLibrary({});
    final file = File('${tmp.path}/a.margo')
      ..writeAsBytesSync(NotebookArchive.encode(snap(7, title: 'Physics')));
    final bad = File('${tmp.path}/b.margo')..writeAsBytesSync([1, 2, 3]);

    final report = await service(lib, _FakeTarget(), _MemoryState())
        .restore([file.path, bad.path]);
    expect(report.restored, ['Physics']);
    expect(report.failed, hasLength(1));
    expect(lib.added.single.meta.title, 'Physics');
  });

  group('backupFileName', () {
    test('keeps the title readable and unique by id', () {
      expect(backupFileName('Biology', 3), 'Biology (3)');
    });
    test('drops characters a file name cannot hold', () {
      expect(backupFileName('A/B: C?*', 3), 'A_B_ C__ (3)');
    });
    test('an empty title still gets a name', () {
      expect(backupFileName('   ', 3), 'Notebook (3)');
    });
    test('a very long title is shortened', () {
      expect(backupFileName('x' * 200, 3).length, lessThan(80));
    });
  });

  group('isBackupDue', () {
    final now = DateTime.utc(2026, 11, 11, 12);
    test('never backed up: due on any trigger', () {
      for (final f in BackupFrequency.values) {
        expect(isBackupDue(f, null, now, BackupTrigger.appResumed), isTrue);
      }
    });
    test('after each session: leaving a note is the trigger', () {
      expect(
          isBackupDue(BackupFrequency.afterEditing,
              now.subtract(const Duration(minutes: 1)), now, BackupTrigger.leftEditor),
          isTrue);
      expect(
          isBackupDue(BackupFrequency.afterEditing,
              now.subtract(const Duration(minutes: 1)), now, BackupTrigger.appResumed),
          isFalse);
    });
    test('daily: not again within the day, yes after it', () {
      expect(
          isBackupDue(BackupFrequency.daily,
              now.subtract(const Duration(hours: 5)), now, BackupTrigger.leftEditor),
          isFalse);
      expect(
          isBackupDue(BackupFrequency.daily,
              now.subtract(const Duration(hours: 25)), now, BackupTrigger.appResumed),
          isTrue);
    });
    test('hourly and weekly', () {
      expect(
          isBackupDue(BackupFrequency.hourly,
              now.subtract(const Duration(minutes: 61)), now, BackupTrigger.appResumed),
          isTrue);
      expect(
          isBackupDue(BackupFrequency.weekly,
              now.subtract(const Duration(days: 3)), now, BackupTrigger.appResumed),
          isFalse);
    });
  });
}
