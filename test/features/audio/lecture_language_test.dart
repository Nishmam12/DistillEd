import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/language/language_detector.dart';
import 'package:inkflow/features/audio/domain/lecture_language.dart';

class _Detector implements LanguageDetector {
  _Detector(this.tag, {this.throws = false});
  final String? tag;
  final bool throws;
  int asked = 0;

  @override
  Future<String?> identify(String text) async {
    asked++;
    if (throws) throw StateError('platform channel failed');
    return tag;
  }
}

void main() {
  const english = 'Photosynthesis converts light energy into chemical energy.';
  const bangla = 'আজ আমরা সালোকসংশ্লেষণ পড়ব এবং আলোর বিক্রিয়া বুঝব';

  group('whisperLanguageForSetting', () {
    test('English is English', () {
      expect(whisperLanguageForSetting('en'), 'en');
    });

    test('Bangla, in either script, is spoken Bangla', () {
      expect(whisperLanguageForSetting('bn'), 'bn');
      // Written in English letters, but the lecturer still SPEAKS Bangla.
      expect(whisperLanguageForSetting('bn-Latn'), 'bn');
    });

    test('anything unknown falls back to English', () {
      expect(whisperLanguageForSetting('zz'), 'en');
    });
  });

  group('whisperLanguageFor — a Language ID tag', () {
    test('maps the languages the app speaks', () {
      expect(whisperLanguageFor('en'), 'en');
      expect(whisperLanguageFor('bn'), 'bn');
      expect(whisperLanguageFor('bn-Latn'), 'bn');
    });

    test('says nothing for the rest', () {
      expect(whisperLanguageFor('de'), isNull);
      expect(whisperLanguageFor(kUndetermined), isNull);
      expect(whisperLanguageFor(null), isNull);
    });
  });

  group('lectureLanguage — what to transcribe a lecture as', () {
    test('the notes beside it win over the setting', () async {
      // Whisper does not detect: asked for "en" on Bangla speech it TRANSLATES.
      // A student on the English setting taking a Bangla lecture has Bangla notes.
      expect(
          await lectureLanguage(
              pageText: bangla, setting: 'en', detector: _Detector('bn')),
          'bn');
    });

    test('and the other way round', () async {
      expect(
          await lectureLanguage(
              pageText: english, setting: 'bn', detector: _Detector('en')),
          'en');
    });

    test('romanised Bangla notes mean a Bangla lecture', () async {
      expect(
          await lectureLanguage(
              pageText: 'ami bhalo achi ar tumi kemon acho bondhu',
              setting: 'en',
              detector: _Detector('bn-Latn')),
          'bn');
    });

    test('a page with too little text to tell uses the setting, and the '
        'detector is not asked', () async {
      final detector = _Detector('bn');

      expect(
          await lectureLanguage(
              pageText: 'F = ma', setting: 'en', detector: detector),
          'en');
      expect(detector.asked, 0);
    });

    test('a blank page uses the setting', () async {
      expect(
          await lectureLanguage(
              pageText: '', setting: 'bn', detector: _Detector('en')),
          'bn');
    });

    test('a language the app does not speak falls back to the setting',
        () async {
      expect(
          await lectureLanguage(
              pageText: english, setting: 'bn', detector: _Detector('de')),
          'bn');
    });

    test('"no language found" falls back to the setting', () async {
      expect(
          await lectureLanguage(
              pageText: english,
              setting: 'en',
              detector: _Detector(kUndetermined)),
          'en');
    });

    test('a detector that could not run falls back to the setting', () async {
      expect(
          await lectureLanguage(
              pageText: english, setting: 'bn', detector: _Detector(null)),
          'bn');
    });

    test('a detector that throws falls back to the setting', () async {
      expect(
          await lectureLanguage(
              pageText: english,
              setting: 'bn',
              detector: _Detector(null, throws: true)),
          'bn');
    });

    test('with no detector at all it is just the setting', () async {
      expect(await lectureLanguage(pageText: bangla, setting: 'bn'), 'bn');
      expect(await lectureLanguage(pageText: bangla, setting: 'en'), 'en');
    });
  });
}
