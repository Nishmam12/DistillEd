// Saved pens and the remembered current pen.
//
// A [PenStyle] is everything that makes a pen look the way it does. The pen in
// use is saved whenever it changes, so a note opens with the pen the user last
// had (see `editorToolProvider`); up to [kMaxPenPresets] favourites sit on the
// toolbar beside the pen tool.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/model/scene_element.dart';
import 'editor_tool_controller.dart';

@immutable
class PenStyle {
  final PenKind kind;
  final int color; // ARGB
  final double size;
  final double opacity;

  const PenStyle({
    required this.kind,
    required this.color,
    required this.size,
    required this.opacity,
  });

  /// The pen the tool state currently describes.
  factory PenStyle.of(EditorToolState s) =>
      PenStyle(kind: s.penKind, color: s.color, size: s.size, opacity: s.opacity);

  Map<String, Object> toJson() =>
      {'kind': kind.name, 'color': color, 'size': size, 'opacity': opacity};

  /// Null when [json] is not a pen this build can read (an unknown pen type
  /// from a newer build, or a damaged value): the caller keeps its default.
  static PenStyle? fromJson(Map<String, dynamic> json) {
    final kind = PenKind.values.asNameMap()[json['kind']];
    final color = json['color'];
    final size = json['size'];
    final opacity = json['opacity'];
    if (kind == null || color is! int || size is! num || opacity is! num) {
      return null;
    }
    return PenStyle(
      kind: kind,
      color: color,
      size: size.toDouble(),
      opacity: opacity.toDouble().clamp(0.1, 1.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PenStyle &&
      other.kind == kind &&
      other.color == color &&
      other.size == size &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(kind, color, size, opacity);

  @override
  String toString() => 'PenStyle(${kind.name}, #${color.toRadixString(16)}, '
      '$size, $opacity)';
}

/// How many saved pens fit on the toolbar.
const int kMaxPenPresets = 5;

/// What a first-time user starts with: one of each kind, in sensible colours.
///
/// Thin on purpose: the first device test found the earlier sizes (3, 4, 3,
/// 18) too heavy for everyday writing.
const List<PenStyle> kDefaultPenPresets = [
  PenStyle(kind: PenKind.ballpoint, color: 0xFF1F2933, size: 2, opacity: 1),
  PenStyle(kind: PenKind.fountain, color: 0xFF1971C2, size: 2.5, opacity: 1),
  PenStyle(kind: PenKind.pencil, color: 0xFF495057, size: 2, opacity: 1),
  PenStyle(kind: PenKind.highlighter, color: 0xFFFFD43B, size: 14, opacity: 1),
];

/// The pen a [kind] starts as when it has never been used: its starter preset.
PenStyle defaultPenFor(PenKind kind) =>
    kDefaultPenPresets.firstWhere((p) => p.kind == kind);

/// Pens earlier builds handed out as defaults. A stored pen exactly equal to
/// one of these was never chosen by the user, so it moves to the new default
/// for its kind instead of keeping the old, heavier size.
const List<PenStyle> _kOldDefaultPens = [
  PenStyle(kind: PenKind.ballpoint, color: 0xFF1F2933, size: 3, opacity: 1),
  PenStyle(kind: PenKind.fountain, color: 0xFF1971C2, size: 4, opacity: 1),
  PenStyle(kind: PenKind.pencil, color: 0xFF495057, size: 3, opacity: 1),
  PenStyle(kind: PenKind.highlighter, color: 0xFFFFD43B, size: 18, opacity: 1),
  // The tool state's own default before saved pens existed.
  PenStyle(kind: PenKind.ballpoint, color: 0xFF1F2933, size: 4, opacity: 1),
];

/// [pen], or the current default for its kind when [pen] is an untouched
/// default from an earlier build.
PenStyle withoutOldDefault(PenStyle pen) =>
    _kOldDefaultPens.contains(pen) ? defaultPenFor(pen.kind) : pen;

/// Where pens are kept between sessions.
abstract interface class PenPreferences {
  Future<PenStyle?> loadCurrent();
  Future<void> saveCurrent(PenStyle pen);

  /// Null when nothing has ever been saved (as opposed to an empty list, which
  /// is a user who removed every saved pen).
  Future<List<PenStyle>?> loadPresets();
  Future<void> savePresets(List<PenStyle> presets);

  /// The last pen used of each kind, so switching back to a kind brings back
  /// its own colour and size. Empty when nothing has been saved.
  Future<Map<PenKind, PenStyle>> loadByKind();
  Future<void> saveByKind(Map<PenKind, PenStyle> pens);

  /// Colours picked with "Custom…", newest first.
  Future<List<int>> loadRecentColors();
  Future<void> saveRecentColors(List<int> colors);
}

/// [PenPreferences] in SharedPreferences. Never throws: a pen that cannot be
/// read or saved costs only the remembering, never the editor.
class SharedPrefsPenPreferences implements PenPreferences {
  const SharedPrefsPenPreferences();

  static const _kCurrent = 'pen.current';
  static const _kPresets = 'pen.presets';
  static const _kRecentColors = 'pen.recentColors';
  static const _kByKind = 'pen.byKind';

  @override
  Future<Map<PenKind, PenStyle>> loadByKind() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kByKind);
      if (raw == null) return const {};
      final pens = [
        for (final item in jsonDecode(raw) as List)
          ?PenStyle.fromJson(item as Map<String, dynamic>),
      ];
      return {for (final pen in pens) pen.kind: pen};
    } catch (e) {
      debugPrint('[Pens] could not read pens by kind: $e');
      return const {};
    }
  }

  @override
  Future<void> saveByKind(Map<PenKind, PenStyle> pens) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _kByKind, jsonEncode([for (final p in pens.values) p.toJson()]));
    } catch (e) {
      debugPrint('[Pens] could not save pens by kind: $e');
    }
  }

  @override
  Future<List<int>> loadRecentColors() async {
    try {
      final raw =
          (await SharedPreferences.getInstance()).getStringList(_kRecentColors);
      return [for (final s in raw ?? const <String>[]) ?int.tryParse(s)];
    } catch (e) {
      debugPrint('[Pens] could not read recent colours: $e');
      return const [];
    }
  }

  @override
  Future<void> saveRecentColors(List<int> colors) async {
    try {
      await (await SharedPreferences.getInstance())
          .setStringList(_kRecentColors, [for (final c in colors) '$c']);
    } catch (e) {
      debugPrint('[Pens] could not save recent colours: $e');
    }
  }

  @override
  Future<PenStyle?> loadCurrent() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kCurrent);
      if (raw == null) return null;
      return PenStyle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Pens] could not read the current pen: $e');
      return null;
    }
  }

  @override
  Future<void> saveCurrent(PenStyle pen) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_kCurrent, jsonEncode(pen.toJson()));
    } catch (e) {
      debugPrint('[Pens] could not save the current pen: $e');
    }
  }

  @override
  Future<List<PenStyle>?> loadPresets() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kPresets);
      if (raw == null) return null;
      return [
        for (final item in jsonDecode(raw) as List)
          ?PenStyle.fromJson(item as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('[Pens] could not read saved pens: $e');
      return null;
    }
  }

  @override
  Future<void> savePresets(List<PenStyle> presets) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _kPresets, jsonEncode([for (final p in presets) p.toJson()]));
    } catch (e) {
      debugPrint('[Pens] could not save saved pens: $e');
    }
  }
}

final penPreferencesProvider =
    Provider<PenPreferences>((ref) => const SharedPrefsPenPreferences());

/// The saved pens on the toolbar.
class PenPresetsNotifier extends StateNotifier<List<PenStyle>> {
  PenPresetsNotifier(this._prefs) : super(kDefaultPenPresets) {
    _load();
  }

  final PenPreferences _prefs;
  bool _edited = false;

  Future<void> _load() async {
    final saved = await _prefs.loadPresets();
    if (!mounted || _edited || saved == null) return;
    state = [for (final p in saved.take(kMaxPenPresets)) withoutOldDefault(p)];
  }

  bool get canAdd => state.length < kMaxPenPresets;

  void add(PenStyle pen) {
    if (!canAdd) return;
    _set([...state, pen]);
  }

  void replace(int index, PenStyle pen) {
    if (index < 0 || index >= state.length) return;
    _set([...state]..[index] = pen);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    _set([...state]..removeAt(index));
  }

  void _set(List<PenStyle> next) {
    _edited = true;
    state = next;
    _prefs.savePresets(next);
  }
}

final penPresetsProvider =
    StateNotifierProvider<PenPresetsNotifier, List<PenStyle>>(
  (ref) => PenPresetsNotifier(ref.watch(penPreferencesProvider)),
);

/// How many custom colours are remembered.
const int kMaxRecentColors = 6;

/// Colours picked with "Custom…", newest first, kept between sessions.
class RecentColorsNotifier extends StateNotifier<List<int>> {
  RecentColorsNotifier(this._prefs) : super(const []) {
    _load();
  }

  final PenPreferences _prefs;
  bool _edited = false;

  Future<void> _load() async {
    final saved = await _prefs.loadRecentColors();
    if (!mounted || _edited) return;
    state = saved.take(kMaxRecentColors).toList();
  }

  /// Puts [color] first, without repeating it.
  void use(int color) {
    _edited = true;
    state = [color, ...state.where((c) => c != color)]
        .take(kMaxRecentColors)
        .toList();
    _prefs.saveRecentColors(state);
  }
}

final recentColorsProvider =
    StateNotifierProvider<RecentColorsNotifier, List<int>>(
  (ref) => RecentColorsNotifier(ref.watch(penPreferencesProvider)),
);
