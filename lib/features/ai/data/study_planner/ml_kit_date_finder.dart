// ML Kit Entity Extraction as a [DateFinder] (docs/AI_PIPELINE_PLAN.md, item 16).
//
// On-device and fast (milliseconds a line), with no LLM involved. Its English
// model is a small download the plugin fetches itself the first time it is used,
// so the very first lookup needs a connection; after that it runs offline.
// Entity extraction has no Bangla, which is why the deadline cue words in
// `note_deadlines.dart` are English too.

import 'package:flutter/services.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart'
    as mlkit;

import '../../domain/study_planner/note_deadlines.dart';

class MlKitDateFinder implements DateFinder {
  /// Created on first use and reused: the native extractor is keyed by this
  /// object's id, and each call would otherwise build a new one.
  mlkit.EntityExtractor? _extractor;

  @override
  Future<List<DateTime>> find(String text, {required DateTime now}) async {
    final extractor = _extractor ??=
        mlkit.EntityExtractor(language: mlkit.EntityExtractorLanguage.english);

    final List<mlkit.EntityAnnotation> annotations;
    try {
      annotations = await extractor.annotateText(
        text,
        referenceTime: now.millisecondsSinceEpoch,
        entityTypesFilter: const [mlkit.EntityType.dateTime],
      );
    } on PlatformException catch (e) {
      // "Model not downloaded" — offline on first use — and any native failure.
      throw DateFinderUnavailable(e.message);
    } on MissingPluginException {
      throw const DateFinderUnavailable('entity extraction plugin not present');
    }

    return [
      for (final annotation in annotations)
        for (final entity in annotation.entities)
          if (entity is mlkit.DateTimeEntity && _isDayOrFiner(entity))
            DateTime.fromMillisecondsSinceEpoch(entity.timestamp),
    ];
  }

  /// "In October", "next week" and "2027" resolve to the first instant of their
  /// period — a date that was never written. Only a day or finer is a date.
  static bool _isDayOrFiner(mlkit.DateTimeEntity entity) =>
      switch (entity.dateTimeGranularity) {
        mlkit.DateTimeGranularity.day ||
        mlkit.DateTimeGranularity.hour ||
        mlkit.DateTimeGranularity.minute ||
        mlkit.DateTimeGranularity.second =>
          true,
        _ => false,
      };

  /// Frees the native extractor. A finder that never ran has nothing to free.
  Future<void> dispose() async {
    final extractor = _extractor;
    _extractor = null;
    if (extractor == null) return;
    try {
      await extractor.close();
    } catch (_) {
      // Releasing a native handle must not throw into a dispose path.
    }
  }
}
