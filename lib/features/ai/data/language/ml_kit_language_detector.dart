// ML Kit Language ID as a [LanguageDetector] (docs/AI_PIPELINE_PLAN.md, item 18).
//
// On-device, with the model shipped inside the library — nothing to download,
// so unlike entity extraction it needs no network on first use.

import 'package:flutter/services.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart' as mlkit;

import '../../domain/language/language_detector.dart';

class MlKitLanguageDetector implements LanguageDetector {
  /// ML Kit's own default: a language is reported only when it is at least this
  /// likely, otherwise the answer is [kUndetermined].
  static const double confidenceThreshold = 0.5;

  /// Created on first use and reused: the native identifier is keyed by this
  /// object's id.
  mlkit.LanguageIdentifier? _identifier;

  @override
  Future<String?> identify(String text) async {
    final identifier = _identifier ??=
        mlkit.LanguageIdentifier(confidenceThreshold: confidenceThreshold);
    try {
      return await identifier.identifyLanguage(text);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Frees the native identifier. A detector that never ran has nothing to free.
  Future<void> dispose() async {
    final identifier = _identifier;
    _identifier = null;
    if (identifier == null) return;
    try {
      await identifier.close();
    } catch (_) {
      // Releasing a native handle must not throw into a dispose path.
    }
  }
}
