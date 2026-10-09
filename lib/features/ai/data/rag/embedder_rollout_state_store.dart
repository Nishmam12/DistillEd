// The rollout's state, kept in shared_preferences, so a restart resumes the
// rollout where it stopped (docs/TECH_MIGRATION_PLAN.md, phase 4.5).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/rag/embedder_rollout.dart';
import '../../domain/rag/embedder_rollout_runner.dart';

class SharedPrefsRolloutStateStore implements RolloutStateStore {
  static const _key = 'embedder_rollout_v1';

  @override
  Future<EmbedderRollout> load(String servingModelId) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return EmbedderRollout(servingModelId: servingModelId);
    try {
      return EmbedderRollout.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // Corrupt saved state restarts the rollout rather than blocking it.
      return EmbedderRollout(servingModelId: servingModelId);
    }
  }

  @override
  Future<void> save(EmbedderRollout rollout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(rollout.toJson()));
  }
}
