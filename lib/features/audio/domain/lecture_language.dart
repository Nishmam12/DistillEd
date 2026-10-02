// Which language to transcribe a lecture in (docs/AI_PIPELINE_PLAN.md, items 14
// and 18).
//
// Whisper does not work the language out from the audio: it is told one, and
// asked for English on Bangla speech it does not fail — it fluently TRANSLATES.
// So the language has to be right, and the best evidence of what a lecture is in
// is the notes written beside it. ML Kit Language ID reads them; the Handwriting
// Language setting is the fallback when there is nothing to read.

import '../../ai/domain/language/language_detector.dart';

/// The Whisper code for a Handwriting Language setting: Bangla in either script
/// is spoken Bangla (the English-letters option is how it is WRITTEN), anything
/// else English.
String whisperLanguageForSetting(String recognitionLanguage) =>
    recognitionLanguage.startsWith('bn') ? 'bn' : 'en';

/// The Whisper code for a Language ID [tag], or null for a language the app does
/// not transcribe (or no answer at all).
String? whisperLanguageFor(String? tag) => switch (tag) {
      'en' => 'en',
      'bn' || 'bn-Latn' => 'bn',
      _ => null,
    };

/// The language to transcribe a lecture as: that of the [pageText] written
/// beside it when there is enough to tell and it is one the app speaks, else the
/// language the Handwriting Language [setting] names.
///
/// Never throws: a detector that fails costs the detection, not the lecture.
Future<String> lectureLanguage({
  required String pageText,
  required String setting,
  LanguageDetector? detector,
}) async {
  final fallback = whisperLanguageForSetting(setting);
  if (detector == null || letterCount(pageText) < kMinLettersToJudge) {
    return fallback;
  }
  try {
    return whisperLanguageFor(await detector.identify(pageText)) ?? fallback;
  } catch (_) {
    return fallback;
  }
}
