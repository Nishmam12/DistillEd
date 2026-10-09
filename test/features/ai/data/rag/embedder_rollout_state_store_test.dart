// The rollout's state survives a restart (docs/TECH_MIGRATION_PLAN.md, phase 4.5):
// a crash resumes the rollout where it stopped, so the state must be saved.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/ai/data/rag/embedder_rollout_state_store.dart';
import 'package:distill_ed/features/ai/domain/rag/embedder_rollout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('with nothing saved, the serving model is idle with no rollout', () async {
    SharedPreferences.setMockInitialValues({});

    final loaded = await SharedPrefsRolloutStateStore().load('serving');

    expect(loaded.servingModelId, 'serving');
    expect(loaded.status, RolloutStatus.idle);
    expect(loaded.targetModelId, isNull);
  });

  test('a rollout saved mid-indexing is the one loaded after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPrefsRolloutStateStore();
    final indexing = const EmbedderRollout(servingModelId: 'serving')
        .start(targetModelId: 'target', totalPages: 4, now: DateTime(2026, 10, 8))
        .downloaded()
        .progress(2);

    await store.save(indexing);
    final restarted = await SharedPrefsRolloutStateStore().load('serving');

    expect(restarted.status, RolloutStatus.indexing);
    expect(restarted.targetModelId, 'target');
    expect(restarted.indexedPages, 2);
    expect(restarted.totalPages, 4);
    expect(restarted.servingModelId, 'serving');
  });
}
