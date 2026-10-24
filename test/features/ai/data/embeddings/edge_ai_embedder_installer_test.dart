// What counts as an embedder installed: the plugin's records and the files
// they point at, for the model and for its tokenizer. The 300M is the model with
// a tokenizer; a bundle's one file follows the same rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/data/embeddings/embedder_adapter.dart';
import 'package:margo/features/ai/data/embeddings/embedder_spec.dart';

void main() {
  const spec = EmbedderSpec.embeddingGemma300m;

  test('records without files are not installed', () async {
    // A restored backup keeps the records and loses the files. The download
    // manager then skipped the download, so the Download button did nothing.
    final installer = EdgeAiEmbedderInstaller(
      isFileInstalled: (_) async => true,
      isFileOnDisk: (_) async => false,
    );

    expect(await installer.isInstalled(spec), isFalse);
  });

  test('the model and its tokenizer, recorded and on disk, are installed',
      () async {
    final installer = EdgeAiEmbedderInstaller(
      isFileInstalled: (_) async => true,
      isFileOnDisk: (_) async => true,
    );

    expect(await installer.isInstalled(spec), isTrue);
  });

  test('the model on disk without its tokenizer is not installed', () async {
    final installer = EdgeAiEmbedderInstaller(
      isFileInstalled: (_) async => true,
      isFileOnDisk: (name) async => name == spec.modelFilename,
    );

    expect(await installer.isInstalled(spec), isFalse);
  });

  group('installing over records whose files are gone', () {
    test('stale records for the model and its tokenizer are forgotten',
        () async {
      final forgotten = <String>[];
      final installer = EdgeAiEmbedderInstaller(
        isFileInstalled: (_) async => true,
        isFileOnDisk: (_) async => false,
        forgetFile: (name) async {
          forgotten.add(name);
        },
      );

      await installer.forgetStaleRecords(spec);

      expect(forgotten, [spec.modelFilename, spec.tokenizerFilename]);
    });

    test('files that are on disk keep their records', () async {
      final forgotten = <String>[];
      final installer = EdgeAiEmbedderInstaller(
        isFileInstalled: (_) async => true,
        isFileOnDisk: (_) async => true,
        forgetFile: (name) async {
          forgotten.add(name);
        },
      );

      await installer.forgetStaleRecords(spec);

      expect(forgotten, isEmpty);
    });
  });
}
