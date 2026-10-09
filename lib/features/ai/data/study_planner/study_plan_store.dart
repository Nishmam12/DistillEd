// A seam over Isar for the persisted [StudyPlan], so the planner flow is
// unit-testable (fake the store) and features/ai never touches IsarService
// outside data/.

import 'package:isar_community/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import '../../domain/study_planner/study_plan.dart';
import 'study_plan_record.dart';

abstract class StudyPlanStore {
  /// Persists [plan] as THE plan for its notebook, replacing any earlier one
  /// (regenerating a plan supersedes it rather than accumulating history).
  Future<void> save(StudyPlan plan);

  /// The notebook's current plan, or null if none has been generated.
  Future<StudyPlan?> loadForNotebook(int notebookId);

  Future<void> deleteForNotebook(int notebookId);
}

class IsarStudyPlanStore implements StudyPlanStore {
  /// [isar] lets a test point the store at its own database; the app uses the
  /// shared [IsarService] instance.
  IsarStudyPlanStore({Isar Function()? isar}) : _isarOverride = isar;

  final Isar Function()? _isarOverride;

  Isar get _isar => _isarOverride?.call() ?? IsarService.instance;

  IsarCollection<StudyPlanRecord> get _plans =>
      _isar.studyPlanRecords;

  @override
  Future<void> save(StudyPlan plan) {
    return _isar.writeTxn(() async {
      await _plans.filter().notebookIdEqualTo(plan.notebookId).deleteAll();
      await _plans.put(StudyPlanRecord.fromDomain(plan));
    });
  }

  @override
  Future<StudyPlan?> loadForNotebook(int notebookId) async {
    final row =
        await _plans.filter().notebookIdEqualTo(notebookId).findFirst();
    return row?.toDomain();
  }

  @override
  Future<void> deleteForNotebook(int notebookId) {
    return _isar.writeTxn(() async {
      await _plans.filter().notebookIdEqualTo(notebookId).deleteAll();
    });
  }
}
