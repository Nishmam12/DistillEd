import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's comfort level with the Phase 3 Intelligent Router sending a
/// request to the cloud gateway. `askEachTime` is the spec-mandated default —
/// cloud never happens silently. Lives here (not in `features/ai`) because
/// `core/` settings must stay feature-agnostic; the AI feature imports this
/// type rather than the reverse.
enum CloudPrivacy { localOnly, askEachTime, allowCloudForNonSensitive }

/// WHERE the AI runs — distinct from [CloudPrivacy], which governs whether the
/// user is asked before a cloud call happens.
///
/// [onDevice] is the DEFAULT, preserving the privacy stance of the
/// `cloudAiEnabled = false` bool this replaces: nothing leaves the device until
/// the user opts in. [auto] is the historical opted-in behaviour — on-device
/// first, cloud only when it fails or the note overflows the local context
/// window. [cloudFirst] is for someone who would rather wait on the network
/// than on a 2B model: it skips the local model entirely, so a page read costs
/// one cloud round-trip instead of a multi-second model load plus several
/// on-device passes.
///
/// Persisted by NAME, not index, so reordering this enum cannot silently
/// reinterpret a stored preference.
enum AiProcessingMode {
  /// Nothing ever leaves the device, whatever [CloudPrivacy] says.
  onDevice,

  /// On-device first; escalate to cloud on failure or overflow.
  auto,

  /// Cloud reads the page directly; the local model is not loaded.
  cloudFirst;

  /// True when this mode permits a cloud call at all — the successor to the
  /// old `cloudAiEnabled` bool, and what escalation predicates should ask.
  bool get allowsCloud => this != AiProcessingMode.onDevice;

  /// True when the cloud should be tried BEFORE the on-device model.
  bool get prefersCloud => this == AiProcessingMode.cloudFirst;

  static AiProcessingMode byName(String? name) => switch (name) {
        'onDevice' => AiProcessingMode.onDevice,
        'cloudFirst' => AiProcessingMode.cloudFirst,
        'auto' => AiProcessingMode.auto,
        _ => AiProcessingMode.auto,
      };
}

/// App theme preference. `system` follows the OS setting (the Android
/// convention, and the default); `light` / `dark` pin one regardless.
///
/// Kept as our own enum rather than persisting Flutter's [ThemeMode] directly,
/// so the stored value does not depend on the framework enum's declaration
/// order — a reorder upstream would silently reinterpret everyone's setting.
enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get toThemeMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}

class SettingsState {
  /// Which theme the app renders. Replaced a `darkMode` bool that persisted
  /// correctly but which nothing ever read — the toggle moved a stored value
  /// and changed no pixels.
  final AppThemeMode themeMode;
  final bool devMode;
  final String exportDefault;

  /// Where the AI runs. Default [AiProcessingMode.onDevice] — the same privacy
  /// default as the `cloudAiEnabled = false` bool it supersedes, so note
  /// content still never leaves the device until the user opts in.
  ///
  /// `cloudAiEnabled` survives as a derived getter so existing call sites keep
  /// working unchanged.
  final AiProcessingMode aiMode;

  /// The Phase 3 Intelligent Router's privacy gate. Default `askEachTime`
  /// (spec-mandated) — additive alongside [cloudAiEnabled], not a replacement:
  /// each drives a separate router (see `intelligent_router.dart`'s header).
  final CloudPrivacy cloudPrivacy;

  /// Whether the app has ever shown the first-cloud-call explainer. The
  /// *first* cloud call gets a longer, more educational confirmation message;
  /// every later `askEachTime` confirmation is terser. Persisted so it only
  /// happens once per install, not once per app launch.
  final bool hasSeenFirstCloudCall;

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

  /// False until [SettingsNotifier] has finished reading SharedPreferences.
  ///
  /// Exists because that read is asynchronous while the first frame is not:
  /// until it lands, every field here is a DEFAULT, and `huggingFaceToken` in
  /// particular defaults to '' — indistinguishable from "the user has no
  /// token". Screens that turn a missing token into a message or a disabled
  /// button must wait for this, or they will tell someone who has a perfectly
  /// good token saved that they need to add one.
  final bool loaded;

  SettingsState({
    this.themeMode = AppThemeMode.system,
    this.devMode = false,
    this.exportDefault = 'PNG',
    this.aiMode = AiProcessingMode.onDevice,
    this.cloudPrivacy = CloudPrivacy.askEachTime,
    this.hasSeenFirstCloudCall = false,
    this.recognitionLanguage = 'en',
    this.huggingFaceToken = '',
    this.loaded = false,
  });

  /// True when gated model downloads can be attempted.
  bool get hasHuggingFaceToken => huggingFaceToken.trim().isNotEmpty;

  /// Whether a cloud call is permitted at all.
  ///
  /// Kept as the name every escalation predicate already asks for. It is now
  /// DERIVED from [aiMode] rather than stored: `onDevice` forbids the cloud,
  /// `auto` and `cloudFirst` both permit it — they differ only in whether the
  /// local model is tried first, which is [AiProcessingMode.prefersCloud].
  bool get cloudAiEnabled => aiMode.allowsCloud;

  SettingsState copyWith({
    AppThemeMode? themeMode,
    bool? devMode,
    String? exportDefault,
    AiProcessingMode? aiMode,
    CloudPrivacy? cloudPrivacy,
    bool? hasSeenFirstCloudCall,
    String? recognitionLanguage,
    String? huggingFaceToken,
    bool? loaded,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      devMode: devMode ?? this.devMode,
      exportDefault: exportDefault ?? this.exportDefault,
      aiMode: aiMode ?? this.aiMode,
      cloudPrivacy: cloudPrivacy ?? this.cloudPrivacy,
      hasSeenFirstCloudCall: hasSeenFirstCloudCall ?? this.hasSeenFirstCloudCall,
      recognitionLanguage: recognitionLanguage ?? this.recognitionLanguage,
      huggingFaceToken: huggingFaceToken ?? this.huggingFaceToken,
      loaded: loaded ?? this.loaded,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _kThemeMode = 'ui.themeMode';

  /// The pre-2.1 boolean key. Read once, on the first launch after upgrading,
  /// so anyone who had switched the old (inert) toggle on lands in dark rather
  /// than being silently reset. Never written.
  static const _kLegacyDarkMode = 'ui.darkMode';

  static const _kDevMode = 'ui.devMode';
  static const _kExportDefault = 'ui.exportDefault';
  static const _kAiMode = 'ai.mode';

  /// The pre-4.5 boolean key. Read once, on the first launch after upgrading,
  /// so an existing opt-in is not silently revoked. Never written.
  static const _kLegacyCloudAiEnabled = 'ai.cloudEnabled';
  static const _kCloudPrivacy = 'ai.cloudPrivacy';
  static const _kHasSeenFirstCloudCall = 'ai.hasSeenFirstCloudCall';
  static const _kRecognitionLanguage = 'ai.recognitionLanguage';
  static const _kHuggingFaceToken = 'ai.huggingFaceToken';

  /// Export formats the Settings picker offers. A persisted value outside this
  /// set (an older build's format, or hand-edited prefs) falls back to the
  /// default rather than leaving the picker showing no selection at all.
  static const exportFormats = {'PNG', 'PDF'};

  SettingsNotifier() : super(SettingsState()) {
    _restore();
  }

  /// Restores every persisted setting. Runs asynchronously from the
  /// constructor, so the first frame renders defaults and then settles onto the
  /// stored values — the same behavior the AI settings already had.
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final storedExport = prefs.getString(_kExportDefault);
    state = state.copyWith(
      themeMode: _restoreThemeMode(prefs),
      devMode: prefs.getBool(_kDevMode) ?? false,
      exportDefault: exportFormats.contains(storedExport) ? storedExport : 'PNG',
      aiMode: _restoreAiMode(prefs),
      cloudPrivacy: CloudPrivacy.values.firstWhere(
        (v) => v.name == prefs.getString(_kCloudPrivacy),
        orElse: () => CloudPrivacy.askEachTime,
      ),
      hasSeenFirstCloudCall: prefs.getBool(_kHasSeenFirstCloudCall) ?? false,
      recognitionLanguage: prefs.getString(_kRecognitionLanguage) ?? 'en',
      huggingFaceToken: prefs.getString(_kHuggingFaceToken) ?? '',
      loaded: true,
    );
  }

  /// Reads the stored theme mode, falling back to the legacy `ui.darkMode`
  /// boolean on the first launch after upgrading. An unrecognised stored name
  /// (an older build's value, or hand-edited prefs) falls back to System rather
  /// than throwing.
  static AppThemeMode _restoreThemeMode(SharedPreferences prefs) {
    final stored = prefs.getString(_kThemeMode);
    if (stored != null) {
      return AppThemeMode.values.firstWhere(
        (v) => v.name == stored,
        orElse: () => AppThemeMode.system,
      );
    }
    return (prefs.getBool(_kLegacyDarkMode) ?? false)
        ? AppThemeMode.dark
        : AppThemeMode.system;
  }

  /// Reads the stored AI mode, falling back to the legacy `ai.cloudEnabled`
  /// boolean on the first launch after upgrading.
  ///
  /// The legacy mapping is deliberately conservative in BOTH directions: `true`
  /// becomes [AiProcessingMode.auto] (the behaviour that bool actually bought —
  /// escalate on failure), never `cloudFirst`, because nobody consented to
  /// cloud-first by ticking it. `false`, or no stored value at all, becomes
  /// [AiProcessingMode.onDevice], so upgrading cannot widen anyone's privacy.
  static AiProcessingMode _restoreAiMode(SharedPreferences prefs) {
    final stored = prefs.getString(_kAiMode);
    if (stored != null) return AiProcessingMode.byName(stored);
    return (prefs.getBool(_kLegacyCloudAiEnabled) ?? false)
        ? AiProcessingMode.auto
        : AiProcessingMode.onDevice;
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    state = state.copyWith(themeMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, value.name);
  }

  Future<void> toggleDevMode(bool value) async {
    state = state.copyWith(devMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDevMode, value);
  }

  Future<void> setExportDefault(String value) async {
    if (!exportFormats.contains(value)) return;
    state = state.copyWith(exportDefault: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExportDefault, value);
  }

  Future<void> setAiMode(AiProcessingMode value) async {
    state = state.copyWith(aiMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAiMode, value.name);
  }

  /// Back-compat shim for the two-state callers (`/cloud on|off`, the sidebar
  /// switch). Turning cloud ON lands on [AiProcessingMode.auto], never
  /// `cloudFirst` — the stronger mode is only reachable by choosing it
  /// explicitly in Settings, so a one-tap switch can never send every page to
  /// the network. OFF returns to [AiProcessingMode.onDevice].
  Future<void> setCloudAiEnabled(bool value) => setAiMode(
        value ? AiProcessingMode.auto : AiProcessingMode.onDevice,
      );

  Future<void> setCloudPrivacy(CloudPrivacy value) async {
    state = state.copyWith(cloudPrivacy: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCloudPrivacy, value.name);
  }

  /// Marks the first-cloud-call explainer as shown — every confirmation
  /// after this one is the terser, repeat version.
  Future<void> markFirstCloudCallSeen() async {
    if (state.hasSeenFirstCloudCall) return;
    state = state.copyWith(hasSeenFirstCloudCall: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSeenFirstCloudCall, true);
  }

  Future<void> setRecognitionLanguage(String languageCode) async {
    state = state.copyWith(recognitionLanguage: languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRecognitionLanguage, languageCode);
  }

  /// Stores the user's HuggingFace token. Passing a blank value clears it.
  ///
  /// The value is sanitized, not merely trimmed, because every one of these
  /// mangles a token that the user believes they pasted correctly and produces
  /// an unexplained 401 hours later:
  ///
  /// • ALL whitespace is stripped, not just the ends — copying from a wrapped
  ///   terminal or a soft-wrapped web page embeds newlines mid-token. HF tokens
  ///   are `hf_` + alphanumerics, so no internal whitespace is ever legitimate.
  /// • Surrounding quotes are dropped — pasting from a `HF_TOKEN="hf_…"` line
  ///   or a JSON snippet is a common way to get here.
  static String sanitizeToken(String token) {
    final stripped = token.replaceAll(RegExp(r'\s'), '');
    if (stripped.length >= 2) {
      final first = stripped[0];
      if ((first == '"' || first == "'") && stripped.endsWith(first)) {
        return stripped.substring(1, stripped.length - 1);
      }
    }
    return stripped;
  }

  Future<void> setHuggingFaceToken(String token) async {
    final cleaned = sanitizeToken(token);
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
