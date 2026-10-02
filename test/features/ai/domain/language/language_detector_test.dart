import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/language/language_detector.dart';

/// Answers every question with one tag (or none, as a detector that could not
/// run would) and counts how often it was asked.
class _Detector implements LanguageDetector {
  final String? tag;
  final bool throws;
  int asked = 0;

  _Detector(this.tag, {this.throws = false});

  @override
  Future<String?> identify(String text) async {
    asked++;
    if (throws) throw StateError('platform channel failed');
    return tag;
  }
}

void main() {
  // 30 letters: long enough for "no language found" to mean something.
  const long = 'the quick brown fox jumps over';

  group('isUnreadable — text that is not any language', () {
    test('long text no language is found in is unreadable', () async {
      expect(await isUnreadable(long, _Detector(kUndetermined)), isTrue);
    });

    test('long text in a language is readable — English, Bangla, romanised',
        () async {
      for (final tag in ['en', 'bn', 'bn-Latn']) {
        expect(await isUnreadable(long, _Detector(tag)), isFalse, reason: tag);
      }
    });

    test('short text is never judged: "F = ma" is too short to identify',
        () async {
      final detector = _Detector(kUndetermined);

      expect(await isUnreadable('F = ma', detector), isFalse);
      expect(detector.asked, 0, reason: 'the detector is not even asked');
    });

    test('only letters count toward "long enough", not digits or symbols',
        () async {
      final detector = _Detector(kUndetermined);

      expect(await isUnreadable('1234567890 +-*/=<> 1234567890 (){}[]', detector),
          isFalse);
      expect(detector.asked, 0);
    });

    test('Bengali letters count — the script ML Kit text recognition cannot read',
        () async {
      // 30 Bengali letters.
      const bangla = 'আমারসোনারবাংলাআমিতোমায়ভালোবাসি';
      final detector = _Detector(kUndetermined);

      expect(await isUnreadable(bangla, detector), isTrue);
      expect(detector.asked, 1);
    });

    test('a detector that could not run never makes text unreadable', () async {
      // The guard exists to drop gibberish; a broken guard must not drop text.
      expect(await isUnreadable(long, _Detector(null)), isFalse);
    });

    test('a detector that throws never makes text unreadable', () async {
      expect(await isUnreadable(long, _Detector(null, throws: true)), isFalse);
    });
  });
}
