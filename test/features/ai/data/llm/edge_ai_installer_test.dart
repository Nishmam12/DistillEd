// What counts as Gemma installed. The plugin keeps a record per model; the file
// is what the model runs from. Only both together mean installed.

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';

void main() {
  const filename = 'gemma-4-E2B-it.litertlm';

  test('a model the plugin records but whose file is gone is not installed',
      () async {
    // A restored backup keeps the record and loses the file. Calling that
    // "installed" made the download a no-op and the summarizer try a file that
    // is not there.
    final installer = EdgeAiInstaller(
      isFileInstalled: (_) async => true,
      isFileOnDisk: (_) async => false,
    );

    expect(await installer.isInstalled(filename), isFalse);
  });

  test('a model that is recorded and on disk is installed', () async {
    final installer = EdgeAiInstaller(
      isFileInstalled: (_) async => true,
      isFileOnDisk: (_) async => true,
    );

    expect(await installer.isInstalled(filename), isTrue);
  });

  test('a file the plugin has no record of is not installed', () async {
    final installer = EdgeAiInstaller(
      isFileInstalled: (_) async => false,
      isFileOnDisk: (_) async => true,
    );

    expect(await installer.isInstalled(filename), isFalse);
  });

  group('installing over a record whose file is gone', () {
    // The plugin's install skips a model whose record exists, file or no file.
    // A record that outlived its file has to go first, or the download never runs.
    test('the stale record is forgotten before the download', () async {
      final forgotten = <String>[];
      final installer = EdgeAiInstaller(
        isFileInstalled: (_) async => true,
        isFileOnDisk: (_) async => false,
        forgetFile: (name) async {
          forgotten.add(name);
        },
      );

      await installer.forgetStaleRecords(filename);

      expect(forgotten, [filename]);
    });

    test('a record whose file is on disk is kept', () async {
      final forgotten = <String>[];
      final installer = EdgeAiInstaller(
        isFileInstalled: (_) async => true,
        isFileOnDisk: (_) async => true,
        forgetFile: (name) async {
          forgotten.add(name);
        },
      );

      await installer.forgetStaleRecords(filename);

      expect(forgotten, isEmpty);
    });

    test('with no record there is nothing to forget', () async {
      final forgotten = <String>[];
      final installer = EdgeAiInstaller(
        isFileInstalled: (_) async => false,
        isFileOnDisk: (_) async => false,
        forgetFile: (name) async {
          forgotten.add(name);
        },
      );

      await installer.forgetStaleRecords(filename);

      expect(forgotten, isEmpty);
    });
  });
}
