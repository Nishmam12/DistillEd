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

  SettingsState({
    this.darkMode = false,
    this.devMode = false,
    this.exportDefault = 'PNG',
    this.cloudAiEnabled = false,
    this.recognitionLanguage = 'en',
  });

  SettingsState copyWith({
    bool? darkMode,
    bool? devMode,
    String? exportDefault,
    bool? cloudAiEnabled,
    String? recognitionLanguage,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      devMode: devMode ?? this.devMode,
      exportDefault: exportDefault ?? this.exportDefault,
      cloudAiEnabled: cloudAiEnabled ?? this.cloudAiEnabled,
      recognitionLanguage: recognitionLanguage ?? this.recognitionLanguage,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _kCloudAiEnabled = 'ai.cloudEnabled';
  static const _kRecognitionLanguage = 'ai.recognitionLanguage';

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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
