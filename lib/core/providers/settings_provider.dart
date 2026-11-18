import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';

/// The user's comfort level with the Phase 3 Intelligent Router sending a
/// request to the cloud AI provider. `askEachTime` is the spec-mandated default —
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

  /// An unrecognised name falls back to [onDevice], the privacy default: a value
  /// this build cannot read must never grant the cloud anything.
  static AiProcessingMode byName(String? name) => switch (name) {
        'onDevice' => AiProcessingMode.onDevice,
        'cloudFirst' => AiProcessingMode.cloudFirst,
        'auto' => AiProcessingMode.auto,
        _ => AiProcessingMode.onDevice,
      };
}

/// How the tutor teaches when the student asks something.
///
/// [explain] is the default and what every feature did before there was a
/// choice: give the explanation. [guide] holds the full answer back and gives
/// one hint or question first. The words each one puts in a prompt are in
/// `features/ai/domain/tutor/tutor_prompt.dart`; the enum lives here for the
/// same reason [CloudPrivacy] does.
///
/// Stored by name. A name this build does not know reads as [explain].
enum TeachingStyle {
  explain,
  guide;

  static TeachingStyle byName(String? name) => values.firstWhere(
        (v) => v.name == name,
        orElse: () => TeachingStyle.explain,
      );
}

/// How often automatic backup runs. Stored by name.
enum BackupFrequency {
  /// When the user leaves a note (and at least daily as a safety net).
  afterEditing,
  hourly,
  daily,
  weekly;

  Duration get period => switch (this) {
        BackupFrequency.afterEditing => const Duration(days: 1),
        BackupFrequency.hourly => const Duration(hours: 1),
        BackupFrequency.daily => const Duration(days: 1),
        BackupFrequency.weekly => const Duration(days: 7),
      };

  String get label => switch (this) {
        BackupFrequency.afterEditing => 'After each note',
        BackupFrequency.hourly => 'Hourly',
        BackupFrequency.daily => 'Daily',
        BackupFrequency.weekly => 'Weekly',
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

  /// Which model answers what the student asks: `auto` (on-device first, the
  /// behaviour before there was a picker), `local` (only ever the on-device
  /// model), or the id of a model in the list — see
  /// `features/ai/domain/catalog/answer_route.dart`, which is the only place
  /// this is interpreted.
  ///
  /// Separate from [aiMode] on purpose. [aiMode] decides where pages are READ
  /// and whether the cloud may be used at all; this decides who ANSWERS. Folding
  /// the two together would make picking a model re-read every page.
  final String answerModelId;

  /// Whether the tutor explains or guides. See [TeachingStyle].
  final TeachingStyle teachingStyle;

  /// Hold the pen still at the end of a freehand stroke and a rectangle, ellipse,
  /// triangle or arrow snaps to the clean shape (ML Kit's shape model, a small
  /// download made when this is switched on). Off by default: it changes what the
  /// student drew.
  final bool snapShapes;

  /// Scrub back and forth over something to wipe it out (ML Kit's gesture model).
  /// Off by default, for the same reason — and because a scrub the model reads
  /// wrongly deletes work, even though it can be undone.
  final bool scribbleErase;

  /// Hold at the end of a line and it straightens. Its own switch, off by
  /// default: it used to be always on and fired when it was not wanted.
  final bool straightenLines;

  /// A highlighter stroke over printed text on a page picture snaps to the
  /// words. On by default.
  final bool snapHighlighter;

  /// A notebook exported as PDF has its handwriting read on the device and
  /// laid invisibly over it, so it can be searched. Remembered from the last
  /// export; on by default.
  final bool exportHandwriting;

  /// Whether one finger draws on the page. On by default, as it always was.
  /// Off, a finger scrolls the page and only a pen draws — what most people
  /// writing with a stylus want, and what stops a resting finger leaving ink.
  final bool fingerDraws;

  /// Whether the one-time "a pen was detected — let a finger scroll?" offer has
  /// been shown. Persisted so it is offered once per install.
  final bool stylusTipShown;

  /// Whether notebooks are backed up on their own (to Download/Margo).
  /// Off by default: it writes into the user's Downloads, which they should
  /// choose.
  final bool autoBackup;
  final BackupFrequency backupFrequency;

  /// Width the docked AI panel was last dragged to, in logical pixels.
  /// Clamped to what fits when it is shown.
  final double aiPanelWidth;

  /// On wide screens the AI panel floats over the page as a card that can be
  /// moved and resized, instead of docking beside it and narrowing the page.
  /// On by default (asked for in the first device test).
  final bool aiPanelFloating;

  /// Where the floating AI panel was last left, in logical pixels within the
  /// editor's page area. Null until it is first moved. Clamped to fit when
  /// shown.
  final Rect? aiPanelFloatRect;

  /// Record lectures for transcription: 16 kHz mono WAV (about 2 MB a minute)
  /// instead of compressed AAC (about 0.5 MB), because the speech model reads
  /// nothing else — and transcribe them on the device once they stop. Off by
  /// default: it costs storage and an ~80 MB model, and not everyone wants it.
  final bool transcribeLectures;

  /// After a lecture is transcribed, summarise its page on the device (never
  /// the cloud) so a study summary is waiting. Skipped quietly where the
  /// on-device model is not installed.
  final bool summarizeLectures;

  /// The home search also lists pages that mean what was typed ("Matched by
  /// meaning"), from the on-device search model.
  final bool searchByMeaning;

  /// A notification on days with cards due or study-plan tasks. Off until
  /// asked for (it needs the notification permission).
  final bool studyReminders;

  /// ML Kit digital-ink model for handwriting recognition: 'en', 'bn' (Bangla
  /// script) or 'bn-Latn' (Bangla written in English letters).
  final String recognitionLanguage;

  /// The user's own HuggingFace access token, used to download models from
  /// gated repos (EmbeddingGemma today; any gated model tomorrow). '' means
  /// "not set" — gated downloads are simply unavailable until the user adds one.
  ///
  /// Per-user by design: the token is never compiled into the app, so each
  /// person accepts Google's model licence under their own account. Stored in
  /// the platform keystore (see [SecretStore]); an older build's plain
  /// SharedPreferences copy is migrated on first read.
  final String huggingFaceToken;

  /// The user's own cloud AI provider: a preset id ('openrouter', 'custom',
  /// ...; '' when none was chosen), its OpenAI-compatible base URL with no
  /// trailing slash, and the model to call. Plain SharedPreferences: none of
  /// these is a secret.
  final String cloudPresetId;
  final String cloudBaseUrl;
  final String cloudModel;

  /// The chosen model's context window in tokens, as the provider's model list
  /// reported it. 0 means unknown, and the provider then uses its default.
  final int cloudContextTokens;

  /// The user's cloud AI API key. '' means "not set". Stored in the platform
  /// keystore only (see [SecretStore]), never in SharedPreferences.
  final String cloudApiKey;

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
    this.answerModelId = 'auto',
    this.teachingStyle = TeachingStyle.explain,
    this.recognitionLanguage = 'en',
    this.transcribeLectures = false,
    this.summarizeLectures = true,
    this.searchByMeaning = true,
    this.studyReminders = false,
    this.snapShapes = false,
    this.scribbleErase = false,
    this.straightenLines = false,
    this.snapHighlighter = true,
    this.exportHandwriting = true,
    this.fingerDraws = true,
    this.stylusTipShown = false,
    this.aiPanelWidth = 340,
    this.aiPanelFloating = true,
    this.aiPanelFloatRect,
    this.autoBackup = false,
    this.backupFrequency = BackupFrequency.afterEditing,
    this.huggingFaceToken = '',
    this.cloudPresetId = '',
    this.cloudBaseUrl = '',
    this.cloudModel = '',
    this.cloudContextTokens = 0,
    this.cloudApiKey = '',
    this.loaded = false,
  });

  /// True when gated model downloads can be attempted.
  bool get hasHuggingFaceToken => huggingFaceToken.trim().isNotEmpty;

  /// True when a cloud provider is fully set up: a key, a base URL and a model.
  /// Any one missing and there is nothing to call.
  bool get hasCloudKey =>
      cloudApiKey.trim().isNotEmpty &&
      cloudBaseUrl.trim().isNotEmpty &&
      cloudModel.trim().isNotEmpty;

  /// Whether a cloud call is permitted at all.
  ///
  /// Kept as the name every escalation predicate already asks for. It is
  /// DERIVED, not stored: [aiMode] must allow the cloud (`onDevice` forbids it,
  /// `auto` and `cloudFirst` both permit it) AND the user must have saved a
  /// cloud key ([hasCloudKey]). A cloud mode with no key is cloud-off.
  bool get cloudAiEnabled => aiMode.allowsCloud && hasCloudKey;

  /// Whether cloud-first is actually in effect: the mode asks for it and a key
  /// is saved. Read this, not [AiProcessingMode.prefersCloud], wherever the
  /// local model would be skipped, so a keyless cloud-first user still gets
  /// on-device AI.
  bool get prefersCloud => aiMode.prefersCloud && cloudAiEnabled;

  SettingsState copyWith({
    AppThemeMode? themeMode,
    bool? devMode,
    String? exportDefault,
    AiProcessingMode? aiMode,
    CloudPrivacy? cloudPrivacy,
    bool? hasSeenFirstCloudCall,
    String? answerModelId,
    TeachingStyle? teachingStyle,
    String? recognitionLanguage,
    bool? transcribeLectures,
    bool? summarizeLectures,
    bool? searchByMeaning,
    bool? studyReminders,
    bool? snapShapes,
    bool? scribbleErase,
    bool? straightenLines,
    bool? snapHighlighter,
    bool? exportHandwriting,
    bool? fingerDraws,
    bool? stylusTipShown,
    double? aiPanelWidth,
    bool? aiPanelFloating,
    Rect? aiPanelFloatRect,
    bool? autoBackup,
    BackupFrequency? backupFrequency,
    String? huggingFaceToken,
    String? cloudPresetId,
    String? cloudBaseUrl,
    String? cloudModel,
    int? cloudContextTokens,
    String? cloudApiKey,
    bool? loaded,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      devMode: devMode ?? this.devMode,
      exportDefault: exportDefault ?? this.exportDefault,
      aiMode: aiMode ?? this.aiMode,
      cloudPrivacy: cloudPrivacy ?? this.cloudPrivacy,
      hasSeenFirstCloudCall: hasSeenFirstCloudCall ?? this.hasSeenFirstCloudCall,
      answerModelId: answerModelId ?? this.answerModelId,
      teachingStyle: teachingStyle ?? this.teachingStyle,
      recognitionLanguage: recognitionLanguage ?? this.recognitionLanguage,
      transcribeLectures: transcribeLectures ?? this.transcribeLectures,
      summarizeLectures: summarizeLectures ?? this.summarizeLectures,
      searchByMeaning: searchByMeaning ?? this.searchByMeaning,
      studyReminders: studyReminders ?? this.studyReminders,
      snapShapes: snapShapes ?? this.snapShapes,
      scribbleErase: scribbleErase ?? this.scribbleErase,
      straightenLines: straightenLines ?? this.straightenLines,
      snapHighlighter: snapHighlighter ?? this.snapHighlighter,
      exportHandwriting: exportHandwriting ?? this.exportHandwriting,
      fingerDraws: fingerDraws ?? this.fingerDraws,
      stylusTipShown: stylusTipShown ?? this.stylusTipShown,
      aiPanelWidth: aiPanelWidth ?? this.aiPanelWidth,
      aiPanelFloating: aiPanelFloating ?? this.aiPanelFloating,
      aiPanelFloatRect: aiPanelFloatRect ?? this.aiPanelFloatRect,
      autoBackup: autoBackup ?? this.autoBackup,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      huggingFaceToken: huggingFaceToken ?? this.huggingFaceToken,
      cloudPresetId: cloudPresetId ?? this.cloudPresetId,
      cloudBaseUrl: cloudBaseUrl ?? this.cloudBaseUrl,
      cloudModel: cloudModel ?? this.cloudModel,
      cloudContextTokens: cloudContextTokens ?? this.cloudContextTokens,
      cloudApiKey: cloudApiKey ?? this.cloudApiKey,
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
  static const _kAnswerModelId = 'ai.answerModelId';
  static const _kTeachingStyle = 'ai.teachingStyle';
  static const _kHasSeenFirstCloudCall = 'ai.hasSeenFirstCloudCall';
  static const _kRecognitionLanguage = 'ai.recognitionLanguage';
  static const _kTranscribeLectures = 'ai.transcribeLectures';
  static const _kSummarizeLectures = 'ai.summarizeLectures';
  static const _kSearchByMeaning = 'ai.searchByMeaning';
  static const _kStudyReminders = 'home.studyReminders';
  static const _kSnapShapes = 'ui.snapShapes';
  static const _kScribbleErase = 'ui.scribbleErase';
  static const _kStraightenLines = 'ui.straightenLines';
  static const _kSnapHighlighter = 'ui.snapHighlighter';
  static const _kExportHandwriting = 'export.searchableHandwriting';
  static const _kFingerDraws = 'ui.fingerDraws';
  static const _kStylusTipShown = 'ui.stylusTipShown';
  static const _kAiPanelWidth = 'ui.aiPanelWidth';
  static const _kAiPanelFloating = 'ui.aiPanelFloating';
  static const _kAiPanelFloatRect = 'ui.aiPanelFloatRect';

  /// A rect saved as four numbers (left, top, width, height), or null when
  /// missing or unreadable.
  static Rect? _readRect(List<String>? raw) {
    if (raw == null || raw.length != 4) return null;
    final v = raw.map(double.tryParse).toList();
    if (v.any((x) => x == null || !x.isFinite)) return null;
    return Rect.fromLTWH(v[0]!, v[1]!, v[2]!, v[3]!);
  }
  static const _kAutoBackup = 'backup.auto';
  static const _kBackupFrequency = 'backup.frequency';
  static const _kHuggingFaceToken = 'ai.huggingFaceToken';
  static const _kCloudPresetId = 'ai.cloudPresetId';
  static const _kCloudBaseUrl = 'ai.cloudBaseUrl';
  static const _kCloudModel = 'ai.cloudModel';
  static const _kCloudContextTokens = 'ai.cloudContextTokens';

  /// Keystore only.
  static const _kCloudApiKey = 'ai.cloudApiKey';

  /// Export formats the Settings picker offers. A persisted value outside this
  /// set (an older build's format, or hand-edited prefs) falls back to the
  /// default rather than leaving the picker showing no selection at all.
  static const exportFormats = {'PNG', 'PDF'};

  SettingsNotifier({this._secrets = const KeystoreSecretStore()})
      : super(SettingsState()) {
    _restore();
  }

  final SecretStore _secrets;

  /// Set by [setCloudApiKey] before it awaits anything, so a key saved or
  /// cleared while [_restore] is still reading the keystore is not overwritten
  /// by the older stored value (an empty field cannot tell "cleared" from "not
  /// read yet").
  bool _cloudKeyWritten = false;

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
      answerModelId: prefs.getString(_kAnswerModelId) ?? 'auto',
      teachingStyle: TeachingStyle.byName(prefs.getString(_kTeachingStyle)),
      recognitionLanguage: prefs.getString(_kRecognitionLanguage) ?? 'en',
      transcribeLectures: prefs.getBool(_kTranscribeLectures) ?? false,
      summarizeLectures: prefs.getBool(_kSummarizeLectures) ?? true,
      searchByMeaning: prefs.getBool(_kSearchByMeaning) ?? true,
      studyReminders: prefs.getBool(_kStudyReminders) ?? false,
      snapShapes: prefs.getBool(_kSnapShapes) ?? false,
      scribbleErase: prefs.getBool(_kScribbleErase) ?? false,
      straightenLines: prefs.getBool(_kStraightenLines) ?? false,
      snapHighlighter: prefs.getBool(_kSnapHighlighter) ?? true,
      exportHandwriting: prefs.getBool(_kExportHandwriting) ?? true,
      fingerDraws: prefs.getBool(_kFingerDraws) ?? true,
      stylusTipShown: prefs.getBool(_kStylusTipShown) ?? false,
      aiPanelWidth: prefs.getDouble(_kAiPanelWidth) ?? 340,
      aiPanelFloating: prefs.getBool(_kAiPanelFloating) ?? true,
      aiPanelFloatRect: _readRect(prefs.getStringList(_kAiPanelFloatRect)),
      autoBackup: prefs.getBool(_kAutoBackup) ?? false,
      backupFrequency:
          BackupFrequency.values.asNameMap()[prefs.getString(_kBackupFrequency)] ??
              BackupFrequency.afterEditing,
      cloudPresetId: prefs.getString(_kCloudPresetId) ?? '',
      cloudBaseUrl: prefs.getString(_kCloudBaseUrl) ?? '',
      cloudModel: prefs.getString(_kCloudModel) ?? '',
      cloudContextTokens: prefs.getInt(_kCloudContextTokens) ?? 0,
    );
    // The keystore is slower than prefs, so everything else lands first; `loaded`
    // waits for both secrets, because the UI reads an empty one as "nothing
    // stored".
    final token = await _restoreHuggingFaceToken(prefs);
    if (!mounted) return;
    final cloudKey = await _secrets.read(_kCloudApiKey);
    if (!mounted) return;
    // A token pasted, or a cloud key saved or cleared, while the keystore was
    // still being read is newer.
    state = state.copyWith(
      huggingFaceToken: state.huggingFaceToken.isEmpty ? token : null,
      cloudApiKey: _cloudKeyWritten ? null : (cloudKey ?? ''),
      loaded: true,
    );
  }

  /// The token from the keystore. One saved by an older build sits in plain
  /// SharedPreferences: it moves to the keystore and the plain copy is removed
  /// (kept only if the keystore refused it, so the token is not lost).
  Future<String> _restoreHuggingFaceToken(SharedPreferences prefs) async {
    final secure = await _secrets.read(_kHuggingFaceToken);
    final legacy = prefs.getString(_kHuggingFaceToken);
    if (legacy != null) {
      if (secure == null && await _secrets.write(_kHuggingFaceToken, legacy)) {
        await prefs.remove(_kHuggingFaceToken);
        return legacy;
      }
      if (secure != null) await prefs.remove(_kHuggingFaceToken);
    }
    return secure ?? legacy ?? '';
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

  /// Whether the student is asked before a cloud call. Stored by name.
  Future<void> setCloudPrivacy(CloudPrivacy value) async {
    state = state.copyWith(cloudPrivacy: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCloudPrivacy, value.name);
  }

  /// Stores which model answers (see [SettingsState.answerModelId]). Leaves
  /// [SettingsState.aiMode] alone: picking a model is not a change to where
  /// pages are read.
  Future<void> setAnswerModelId(String value) async {
    state = state.copyWith(answerModelId: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAnswerModelId, value);
  }

  /// Stores whether the tutor explains or guides. Changes nothing about which
  /// model answers or where it runs.
  Future<void> setTeachingStyle(TeachingStyle value) async {
    state = state.copyWith(teachingStyle: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTeachingStyle, value.name);
  }

  /// Marks the first-cloud-call explainer as shown — every confirmation
  /// after this one is the terser, repeat version.
  Future<void> markFirstCloudCallSeen() async {
    if (state.hasSeenFirstCloudCall) return;
    state = state.copyWith(hasSeenFirstCloudCall: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSeenFirstCloudCall, true);
  }

  Future<void> setSnapShapes(bool value) async {
    state = state.copyWith(snapShapes: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSnapShapes, value);
  }

  Future<void> setExportHandwriting(bool value) async {
    state = state.copyWith(exportHandwriting: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kExportHandwriting, value);
  }

  Future<void> setSnapHighlighter(bool value) async {
    state = state.copyWith(snapHighlighter: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSnapHighlighter, value);
  }

  Future<void> setStraightenLines(bool value) async {
    state = state.copyWith(straightenLines: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStraightenLines, value);
  }

  Future<void> setScribbleErase(bool value) async {
    state = state.copyWith(scribbleErase: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kScribbleErase, value);
  }

  Future<void> setFingerDraws(bool value) async {
    state = state.copyWith(fingerDraws: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFingerDraws, value);
  }

  Future<void> markStylusTipShown() async {
    if (state.stylusTipShown) return;
    state = state.copyWith(stylusTipShown: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStylusTipShown, true);
  }

  Future<void> setAutoBackup(bool value) async {
    state = state.copyWith(autoBackup: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoBackup, value);
  }

  Future<void> setBackupFrequency(BackupFrequency value) async {
    state = state.copyWith(backupFrequency: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackupFrequency, value.name);
  }

  Future<void> setAiPanelFloating(bool value) async {
    state = state.copyWith(aiPanelFloating: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAiPanelFloating, value);
  }

  Future<void> setAiPanelFloatRect(Rect value) async {
    state = state.copyWith(aiPanelFloatRect: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kAiPanelFloatRect, [
      for (final v in [value.left, value.top, value.width, value.height])
        v.toString(),
    ]);
  }

  Future<void> setAiPanelWidth(double value) async {
    state = state.copyWith(aiPanelWidth: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kAiPanelWidth, value);
  }

  Future<void> setSearchByMeaning(bool value) async {
    state = state.copyWith(searchByMeaning: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSearchByMeaning, value);
  }

  Future<void> setStudyReminders(bool value) async {
    state = state.copyWith(studyReminders: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStudyReminders, value);
  }

  Future<void> setSummarizeLectures(bool value) async {
    state = state.copyWith(summarizeLectures: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSummarizeLectures, value);
  }

  Future<void> setTranscribeLectures(bool value) async {
    state = state.copyWith(transcribeLectures: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTranscribeLectures, value);
  }

  Future<void> setRecognitionLanguage(String languageCode) async {
    state = state.copyWith(recognitionLanguage: languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRecognitionLanguage, languageCode);
  }

  /// Cleans every pasted secret: the HuggingFace token and the cloud AI key.
  ///
  /// The value is sanitized, not merely trimmed, because every one of these
  /// mangles a secret that the user believes they pasted correctly and produces
  /// an unexplained 401 hours later:
  ///
  /// • ALL whitespace is stripped, not just the ends — copying from a wrapped
  ///   terminal or a soft-wrapped web page embeds newlines mid-token. Neither
  ///   HF tokens nor provider API keys ever contain whitespace.
  /// • Surrounding quotes are dropped — pasting from a `HF_TOKEN="hf_…"` or
  ///   `OPENAI_API_KEY="sk-…"` line or a JSON snippet is a common way to get
  ///   here.
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

  /// Stores the user's HuggingFace token. Passing a blank value clears it.
  Future<void> setHuggingFaceToken(String token) async {
    final cleaned = sanitizeToken(token);
    state = state.copyWith(huggingFaceToken: cleaned);
    // The keystore can refuse; the token then lasts this session only.
    final stored = await _secrets.write(_kHuggingFaceToken, cleaned);
    if (!stored) {
      debugPrint('HuggingFace token could not be saved to the keystore');
      return;
    }
    // Never leave an older plain copy behind (kept if the keystore refused).
    await (await SharedPreferences.getInstance()).remove(_kHuggingFaceToken);
  }

  /// Trimmed, with trailing slashes dropped, so `…/v1/` and `…/v1` are the
  /// same provider. A private copy of `normalizeCloudBaseUrl`, because `core/`
  /// must not import `features/`.
  static String _normalizeBaseUrl(String raw) =>
      raw.trim().replaceFirst(RegExp(r'/+$'), '');

  /// Stores which cloud provider and model to call. Not a secret, so it goes
  /// to SharedPreferences. Save this BEFORE [setCloudApiKey], so
  /// [SettingsState.hasCloudKey] only turns true once everything is in place.
  /// [contextTokens] 0 means unknown.
  Future<void> setCloudProvider({
    required String presetId,
    required String baseUrl,
    required String model,
    int contextTokens = 0,
  }) async {
    final id = presetId.trim();
    final url = _normalizeBaseUrl(baseUrl);
    final name = model.trim();
    final tokens = contextTokens < 0 ? 0 : contextTokens;
    state = state.copyWith(
      cloudPresetId: id,
      cloudBaseUrl: url,
      cloudModel: name,
      cloudContextTokens: tokens,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCloudPresetId, id);
    await prefs.setString(_kCloudBaseUrl, url);
    await prefs.setString(_kCloudModel, name);
    if (tokens == 0) {
      await prefs.remove(_kCloudContextTokens);
    } else {
      await prefs.setInt(_kCloudContextTokens, tokens);
    }
  }

  /// Stores the user's cloud AI key in the keystore. A blank value clears it.
  /// Returns false when the keystore refused it; the key then lasts this
  /// session only.
  Future<bool> setCloudApiKey(String key) async {
    final cleaned = sanitizeToken(key);
    _cloudKeyWritten = true;
    state = state.copyWith(cloudApiKey: cleaned);
    final stored = await _secrets.write(_kCloudApiKey, cleaned);
    if (!stored) debugPrint('Cloud AI key could not be saved to the keystore');
    return stored;
  }
}

/// Where secrets live. Overridden with an in-memory store in widget tests, where
/// the platform keystore never answers.
final secretStoreProvider =
    Provider<SecretStore>((ref) => const KeystoreSecretStore());

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(secrets: ref.watch(secretStoreProvider));
});
