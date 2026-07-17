import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool darkMode;
  final bool devMode;
  final String exportDefault;

  /// Privacy default OFF: note content never leaves the device unless the
  /// user explicitly enables cloud AI.
  final bool cloudAiEnabled;

  /// BCP-47 tag for handwriting recognition ('en' or 'bn').
  final String recognitionLanguage;

  /// The user's own HuggingFace access token, used to download models from
  /// gated repos (EmbeddingGemma today; any gated model tomorrow). '' means
  /// "not set" — gated downloads are simply unavailable until the user adds one.
  ///
  /// Per-user by design: the token is never compiled into the app, so each
  /// person accepts Google's model licence under their own account. Stored in
  /// app-private SharedPreferences (sandboxed per-app on Android/iOS), which is
  /// proportionate for a read-only model-download token; if account credentials
  /// ever live here, revisit with secure storage.
  final String huggingFaceToken;

  SettingsState({
    this.darkMode = false,
    this.devMode = false,
    this.exportDefault = 'PNG',
    this.cloudAiEnabled = false,
    this.recognitionLanguage = 'en',
    this.huggingFaceToken = '',
  });

  /// True when gated model downloads can be attempted.
  bool get hasHuggingFaceToken => huggingFaceToken.trim().isNotEmpty;

  SettingsState copyWith({
    bool? darkMode,
    bool? devMode,
    String? exportDefault,
    bool? cloudAiEnabled,
    String? recognitionLanguage,
    String? huggingFaceToken,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      devMode: devMode ?? this.devMode,
      exportDefault: exportDefault ?? this.exportDefault,
      cloudAiEnabled: cloudAiEnabled ?? this.cloudAiEnabled,
      recognitionLanguage: recognitionLanguage ?? this.recognitionLanguage,
      huggingFaceToken: huggingFaceToken ?? this.huggingFaceToken,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _kCloudAiEnabled = 'ai.cloudEnabled';
  static const _kRecognitionLanguage = 'ai.recognitionLanguage';
  static const _kHuggingFaceToken = 'ai.huggingFaceToken';

  SettingsNotifier() : super(SettingsState()) {
    _restoreAiSettings();
  }

  /// The AI settings are persisted (the cloud opt-in especially must survive
  /// restarts); the pre-existing settings keep their in-memory behavior.
  Future<void> _restoreAiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = state.copyWith(
      cloudAiEnabled: prefs.getBool(_kCloudAiEnabled) ?? false,
      recognitionLanguage: prefs.getString(_kRecognitionLanguage) ?? 'en',
      huggingFaceToken: prefs.getString(_kHuggingFaceToken) ?? '',
    );
  }

  void toggleDarkMode(bool value) {
    state = state.copyWith(darkMode: value);
  }

  void toggleDevMode(bool value) {
    state = state.copyWith(devMode: value);
  }

  void setExportDefault(String value) {
    state = state.copyWith(exportDefault: value);
  }

  Future<void> setCloudAiEnabled(bool value) async {
    state = state.copyWith(cloudAiEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCloudAiEnabled, value);
  }

  Future<void> setRecognitionLanguage(String languageCode) async {
    state = state.copyWith(recognitionLanguage: languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRecognitionLanguage, languageCode);
  }

  /// Stores the user's HuggingFace token (trimmed — tokens pasted from a browser
  /// routinely carry whitespace, and a stray space would 401 confusingly).
  /// Passing a blank value clears it.
  Future<void> setHuggingFaceToken(String token) async {
    final cleaned = token.trim();
    state = state.copyWith(huggingFaceToken: cleaned);
    final prefs = await SharedPreferences.getInstance();
    if (cleaned.isEmpty) {
      await prefs.remove(_kHuggingFaceToken);
    } else {
      await prefs.setString(_kHuggingFaceToken, cleaned);
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
