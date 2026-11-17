// What the student tells the tutor about themselves ("What the tutor knows
// about you"). One short note, in shared_preferences; no database change. It
// reaches a model only inside the learner profile, under the same cloud
// settings as everything else in the prompt.

import 'package:shared_preferences/shared_preferences.dart';

class TutorNoteStore {
  static const _key = 'tutor.aboutMe';

  static Future<String> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> save(String note) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = note.trim();
    trimmed.isEmpty ? await prefs.remove(_key) : await prefs.setString(_key, trimmed);
  }
}
