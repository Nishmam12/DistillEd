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
  @override
  Future<String> save(String sourcePath, String name, String mimeType) async {
    files[name] = File(sourcePath).readAsBytesSync();
    return 'Download/Margo';
  }

  @override
  Future<void> delete(String name) async {
    deleted.add(name);
    files.remove(name);
  }
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
      'Biology (1).margo', 'Biology (1).md', 'Maths (2).margo', 'Maths (2).md',
    ]));
    final back = NotebookArchive.decode(target.files['Biology (1).margo']!);
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

  test('"Back up now" writes everything even if unchanged', () async {
    final lib = _FakeLibrary({1: snap(1)});
    final state = _MemoryState();
    await service(lib, _FakeTarget(), state).run();
    final report = await service(lib, _FakeTarget(), state).run(force: true);
    expect(report.written, 1);
  });

  test('a renamed notebook replaces its old files', () async {
    final lib = _FakeLibrary({1: snap(1, title: 'Old')});
    final target = _FakeTarget();
    final state = _MemoryState();
    await service(lib, target, state).run();

    lib.notebooks[1] = snap(1, title: 'New');
    await service(lib, target, state).run();
    expect(target.deleted, containsAll(['Old (1).margo', 'Old (1).md']));
    expect(target.files.keys, containsAll(['New (1).margo', 'New (1).md']));
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
