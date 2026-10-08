// Golden-vector guard for the embedding pipeline (docs/TECH_MIGRATION_PLAN.md,
// phase 4.1). Device only: it needs the embedding model installed on the device.
//
// Embeds three fixed inputs with the active model, once as a document and once
// as a query, and compares every component with integration_test/golden/
// <modelId>.json within 1e-5. Each later Phase 4 step must leave these vectors
// unchanged, because a changed vector silently breaks search over existing
// indexes.
//
// Generate the golden file once, on the device, before any other Phase 4 change:
//   flutter test integration_test/embedding_golden_test.dart -d <device> \
//     --dart-define=UPDATE_GOLDEN=true
// The test prints where it wrote the file (the app's documents folder). Copy it
// into integration_test/golden/ and commit it. A debug build can read it with
//   adb shell run-as com.inkflow.inkflow cat app_flutter/golden/<modelId>.json
//
// Later runs compare against the copy in the documents folder. Put it there
// with adb shell run-as ... cp, then run the test without UPDATE_GOLDEN.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:inkflow/features/ai/data/embeddings/embedder_spec.dart';
import 'package:inkflow/features/ai/data/embeddings/local_text_embedder.dart';
import 'package:inkflow/features/ai/domain/rag/text_embedder.dart';

/// The fixed inputs. Changing any of them invalidates the golden file.
const _inputs = <String, String>{
  'en':
      'Photosynthesis turns light energy into chemical energy stored in glucose.',
  'bn':
      'সালোকসংশ্লেষণে উদ্ভিদ আলো থেকে শক্তি সংগ্রহ করে এবং তা খাদ্যে সঞ্চয় করে।',
  // Titled the way RagIndexer embeds a page: '<title>\n\n<passage>'.
  'titled': 'Biology notes\n\nCells divide by mitosis.',
};

const _tolerance = 1e-5;
const _updateGolden = bool.fromEnvironment('UPDATE_GOLDEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('embedding vectors match the golden file', (tester) async {
    final embedder = LocalTextEmbedder();
    try {
      final modelId = embedder.modelId;
      expect(modelId, EmbedderSpec.active.modelId);

      final actual = <String, List<double>>{};
      for (final entry in _inputs.entries) {
        actual['${entry.key}_document'] = await embedder.embedOne(
          entry.value,
          taskType: EmbedTaskType.document,
        );
        actual['${entry.key}_query'] = await embedder.embedOne(
          entry.value,
          taskType: EmbedTaskType.query,
        );
      }

      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/golden',
      );
      final file = File('${dir.path}/$modelId.json');

      if (_updateGolden) {
        await dir.create(recursive: true);
        await file.writeAsString(jsonEncode({
          'modelId': modelId,
          'dimensions': embedder.dimensions,
          'vectors': actual,
        }));
        // ignore: avoid_print
        print('Golden file written to ${file.path}');
        return;
      }

      if (!file.existsSync()) {
        fail('No golden file at ${file.path}. Generate it first with '
            '--dart-define=UPDATE_GOLDEN=true (plan phase 4.1).');
      }
      final golden =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final expected = (golden['vectors'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as List).map((x) => (x as num).toDouble()).toList(),
        ),
      );

      expect(actual.keys.toSet(), expected.keys.toSet());
      for (final key in expected.keys) {
        final want = expected[key]!;
        final got = actual[key]!;
        expect(got.length, want.length, reason: '$key dimensions');
        for (var i = 0; i < want.length; i++) {
          expect(
            (got[i] - want[i]).abs() <= _tolerance,
            isTrue,
            reason: '$key[$i]: got ${got[i]}, golden ${want[i]}',
          );
        }
      }
    } finally {
      await embedder.release();
    }
  });
}
