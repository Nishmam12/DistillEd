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

/// [relativePath] with the language the student chose for the lecture written
/// before its extension: `audio/n2_p2_123.wav` becomes `audio/n2_p2_123_bn.wav`.
///
/// The choice lives in the name because a recording row has no field for it, and
/// adding one would change the stored schema of every user's database.
String withLectureLanguage(String relativePath, String language) {
  final dot = relativePath.lastIndexOf('.');
  return '${relativePath.substring(0, dot)}_$language'
      '${relativePath.substring(dot)}';
}

/// The language a recording was made in, from its name (see
/// [withLectureLanguage]); null for a recording made before the choice existed.
String? languageOfRecording(String relativePath) =>
    RegExp(r'_(en|bn)\.[A-Za-z0-9]+$').firstMatch(relativePath)?.group(1);

/// The language to transcribe a recording as. The student's choice when the
/// recording has one; otherwise [lectureLanguage]'s reading of the notes and the
/// setting, exactly as before the choice existed.
Future<String> transcriptionLanguage({
  required String relativePath,
  required String pageText,
  required String setting,
  LanguageDetector? detector,
}) async {
  final chosen = languageOfRecording(relativePath);
  if (chosen != null) return chosen;
  return lectureLanguage(
    pageText: pageText,
    setting: setting,
    detector: detector,
  );
}
