// ML Kit entity extraction for the selection's action chips: web addresses,
// emails, phone numbers, street addresses and dates, on the device. Its English
// model downloads once on first use, like the study planner's date finder.

import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart'
    as mlkit;

import '../../notebook/domain/action_links.dart';
import 'study_planner/ml_kit_date_finder.dart';

class MlKitActionFinder {
  mlkit.EntityExtractor? _extractor;

  /// The entities in [text], in the order written. Throws when the model is
  /// not on the device yet and cannot be fetched.
  Future<List<FoundEntity>> find(String text, {required DateTime now}) async {
    final extractor = _extractor ??=
        mlkit.EntityExtractor(language: mlkit.EntityExtractorLanguage.english);
    final annotations = await extractor.annotateText(
      text,
      referenceTime: now.millisecondsSinceEpoch,
      entityTypesFilter: const [
        mlkit.EntityType.url,
        mlkit.EntityType.email,
        mlkit.EntityType.phone,
        mlkit.EntityType.address,
        mlkit.EntityType.dateTime,
      ],
    );
    annotations.sort((a, b) => a.start.compareTo(b.start));
    return [
      for (final a in annotations)
        if (a.entities.firstOrNull case final e?)
          if (switch (e.type) {
            mlkit.EntityType.url => ActionKind.web,
            mlkit.EntityType.email => ActionKind.email,
            mlkit.EntityType.phone => ActionKind.phone,
            mlkit.EntityType.address => ActionKind.address,
            mlkit.EntityType.dateTime
                when e is mlkit.DateTimeEntity &&
                    MlKitDateFinder.isDayOrFiner(e) =>
              ActionKind.date,
            _ => null,
          }
              case final kind?)
            (
              kind: kind,
              text: a.text,
              date: e is mlkit.DateTimeEntity
                  ? DateTime.fromMillisecondsSinceEpoch(e.timestamp)
                  : null,
            ),
    ];
  }

  Future<void> dispose() async {
    final extractor = _extractor;
    _extractor = null;
    try {
      await extractor?.close();
    } catch (_) {}
  }
}
