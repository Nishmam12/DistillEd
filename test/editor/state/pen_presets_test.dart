import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/state/editor_tool_controller.dart';
import 'package:margo/editor/state/pen_presets.dart';

/// Keeps what was saved in memory, and can start with something "on disk".
class _MemoryPrefs implements PenPreferences {
  PenStyle? current;
  List<PenStyle>? presets;
  int currentSaves = 0;

  _MemoryPrefs({this.current, this.presets});

  @override
  Future<PenStyle?> loadCurrent() async => current;
  @override
  Future<void> saveCurrent(PenStyle pen) async {
    current = pen;
    currentSaves++;
  }

  @override
  Future<List<PenStyle>?> loadPresets() async => presets;
  @override
  Future<void> savePresets(List<PenStyle> value) async => presets = value;

  List<int> recent = [];
  @override
  Future<List<int>> loadRecentColors() async => recent;
  @override
  Future<void> saveRecentColors(List<int> colors) async => recent = colors;

  Map<PenKind, PenStyle> byKind = {};
  @override
  Future<Map<PenKind, PenStyle>> loadByKind() async => byKind;
  @override
  Future<void> saveByKind(Map<PenKind, PenStyle> pens) async => byKind = pens;
}

const _yellowHighlighter = PenStyle(
    kind: PenKind.highlighter, color: 0xFFFFD43B, size: 18, opacity: 1);
const _redBallpoint = PenStyle(
    kind: PenKind.ballpoint, color: 0xFFE03131, size: 1.5, opacity: 1);

void main() {
  group('PenStyle', () {
    test('survives JSON', () {
      const pen = PenStyle(
          kind: PenKind.fountain, color: 0xFF1971C2, size: 5, opacity: 0.8);
      expect(PenStyle.fromJson(pen.toJson()), pen);
    });

    test('unreadable JSON is ignored, not a crash', () {
      expect(PenStyle.fromJson({'kind': 'crayon'}), isNull);
      expect(PenStyle.fromJson(const {}), isNull);
    });
  });

  group('the current pen', () {
    ProviderContainer containerWith(_MemoryPrefs prefs) {
      final c = ProviderContainer(
          overrides: [penPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      return c;
    }

    test('a note opens with the pen used last', () async {
      final prefs = _MemoryPrefs(
          current: const PenStyle(
              kind: PenKind.pencil, color: 0xFF868E96, size: 3, opacity: 1));
      final c = containerWith(prefs);
      final sub = c.listen(editorToolProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(editorToolProvider);
      expect(state.penKind, PenKind.pencil);
      expect(state.color, 0xFF868E96);
      expect(state.size, 3);
    });

    test('changing the pen saves it', () async {
      final prefs = _MemoryPrefs();
      final c = containerWith(prefs);
      final sub = c.listen(editorToolProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      c.read(editorToolProvider.notifier).setPenKind(PenKind.highlighter);
      c.read(editorToolProvider.notifier).setSize(18);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.current?.kind, PenKind.highlighter);
      expect(prefs.current?.size, 18);
    });

    test('a pen chosen before the saved one loads is not overwritten',
        () async {
      final prefs = _MemoryPrefs(
          current: const PenStyle(
              kind: PenKind.pencil, color: 0xFF868E96, size: 3, opacity: 1));
      final c = containerWith(prefs);
      final sub = c.listen(editorToolProvider, (_, _) {});
      addTearDown(sub.close);
      c.read(editorToolProvider.notifier).setPenKind(PenKind.fountain);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(editorToolProvider).penKind, PenKind.fountain);
    });

    test('moving to another tool does not count as changing the pen',
        () async {
      final prefs = _MemoryPrefs();
      final c = containerWith(prefs);
      final sub = c.listen(editorToolProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      c.read(editorToolProvider.notifier).setTool(EditorTool.eraser);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.currentSaves, 0);
    });
  });

  group('saved pens', () {
    PenPresetsNotifier notifier(_MemoryPrefs prefs) => PenPresetsNotifier(prefs);

    test('start with the starter set', () async {
      final n = notifier(_MemoryPrefs());
      await Future<void>.delayed(Duration.zero);
      expect(n.state, kDefaultPenPresets);
      expect(n.state.map((p) => p.kind), contains(PenKind.highlighter));
    });

    test('load what was saved', () async {
      const mine = [
        PenStyle(kind: PenKind.ballpoint, color: 0xFFE03131, size: 2, opacity: 1)
      ];
      final n = notifier(_MemoryPrefs(presets: mine));
      await Future<void>.delayed(Duration.zero);
      expect(n.state, mine);
    });

    test('add, replace and remove are saved', () async {
      final prefs = _MemoryPrefs(presets: const []);
      final n = notifier(prefs);
      await Future<void>.delayed(Duration.zero);

      const red = PenStyle(
          kind: PenKind.ballpoint, color: 0xFFE03131, size: 2, opacity: 1);
      const green = PenStyle(
          kind: PenKind.fountain, color: 0xFF2F9E44, size: 4, opacity: 1);
      n.add(red);
      n.replace(0, green);
      expect(prefs.presets, [green]);
      n.removeAt(0);
      expect(prefs.presets, isEmpty);
    });

    test('there are at most five', () async {
      final n = notifier(_MemoryPrefs(presets: const []));
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 7; i++) {
        n.add(PenStyle(
            kind: PenKind.ballpoint, color: 0xFF000000, size: i + 1.0, opacity: 1));
      }
      expect(n.state.length, kMaxPenPresets);
      expect(n.canAdd, isFalse);
    });

    test('using one sets the pen tool to it', () {
      final ctl = EditorToolController()..setTool(EditorTool.eraser);
      ctl.usePen(kDefaultPenPresets.last);
      expect(ctl.state.tool, EditorTool.pen);
      expect(ctl.state.penKind, kDefaultPenPresets.last.kind);
      expect(ctl.state.color, kDefaultPenPresets.last.color);
      expect(PenStyle.of(ctl.state), kDefaultPenPresets.last);
    });
  });

  group('each pen kind keeps its own pen', () {
    test('switching kind does not carry the size and colour across', () {
      final ctl = EditorToolController()..usePen(_yellowHighlighter);
      ctl.setPenKind(PenKind.ballpoint);
      // The first device test: a highlighter turned into a fat yellow pen.
      expect(PenStyle.of(ctl.state), defaultPenFor(PenKind.ballpoint));
    });

    test('a kind comes back as it was last used', () {
      final ctl = EditorToolController()..usePen(_redBallpoint);
      ctl.setPenKind(PenKind.highlighter);
      ctl.setSize(30);
      ctl.setPenKind(PenKind.ballpoint);
      expect(PenStyle.of(ctl.state), _redBallpoint);
      ctl.setPenKind(PenKind.highlighter);
      expect(ctl.state.size, 30);
      expect(ctl.state.color, defaultPenFor(PenKind.highlighter).color);
    });

    test('picking the kind already in use changes nothing but the tool', () {
      final ctl = EditorToolController()
        ..usePen(_redBallpoint)
        ..setTool(EditorTool.eraser);
      ctl.setPenKind(PenKind.ballpoint);
      expect(ctl.state.tool, EditorTool.pen);
      expect(PenStyle.of(ctl.state), _redBallpoint);
    });

    test('a saved pen remembers the pen it replaced', () {
      final ctl = EditorToolController()..usePen(_redBallpoint);
      ctl.usePen(_yellowHighlighter);
      ctl.setPenKind(PenKind.ballpoint);
      expect(PenStyle.of(ctl.state), _redBallpoint);
    });

    test('is saved, and restored when a note opens', () async {
      final prefs = _MemoryPrefs();
      final c = ProviderContainer(
          overrides: [penPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      final sub = c.listen(editorToolProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      c.read(editorToolProvider.notifier)
        ..usePen(_redBallpoint)
        ..setPenKind(PenKind.pencil);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.byKind[PenKind.ballpoint], _redBallpoint);
      sub.close();

      // A fresh editor: back to the ballpoint finds the red one again.
      final c2 = ProviderContainer(
          overrides: [penPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c2.dispose);
      final sub2 = c2.listen(editorToolProvider, (_, _) {});
      addTearDown(sub2.close);
      await Future<void>.delayed(Duration.zero);
      expect(c2.read(editorToolProvider).penKind, PenKind.pencil);
      c2.read(editorToolProvider.notifier).setPenKind(PenKind.ballpoint);
      expect(PenStyle.of(c2.read(editorToolProvider)), _redBallpoint);
    });

    test('loading the kinds first still lets the last pen be restored', () {
      final ctl = EditorToolController()
        ..restorePenMemory({PenKind.ballpoint: _redBallpoint})
        ..restorePen(_yellowHighlighter);
      expect(PenStyle.of(ctl.state), _yellowHighlighter);
      expect(ctl.state.penMemory[PenKind.ballpoint], _redBallpoint);
    });

    test('a pen used this session outranks the stored one', () {
      final ctl = EditorToolController()
        ..usePen(_redBallpoint)
        ..setPenKind(PenKind.pencil)
        ..restorePenMemory({
          PenKind.ballpoint: const PenStyle(
              kind: PenKind.ballpoint, color: 0xFF000000, size: 9, opacity: 1),
        });
      expect(ctl.state.penMemory[PenKind.ballpoint], _redBallpoint);
    });
  });

  group('thinner defaults', () {
    test('every starter pen is thinner than before', () {
      expect(defaultPenFor(PenKind.ballpoint).size, lessThan(3));
      expect(defaultPenFor(PenKind.fountain).size, lessThan(4));
      expect(defaultPenFor(PenKind.pencil).size, lessThan(3));
      expect(defaultPenFor(PenKind.highlighter).size, lessThan(18));
      expect(const EditorToolState().size, lessThan(3));
    });

    test('an untouched old default moves to the new one', () {
      expect(withoutOldDefault(_yellowHighlighter),
          defaultPenFor(PenKind.highlighter));
      // A pen the user chose is left alone.
      expect(withoutOldDefault(_redBallpoint), _redBallpoint);
    });

    test('a note last left on an old default opens on the new one', () async {
      final prefs = _MemoryPrefs(
          current: const PenStyle(
              kind: PenKind.ballpoint, color: 0xFF1F2933, size: 3, opacity: 1));
      final c = ProviderContainer(
          overrides: [penPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      final sub = c.listen(editorToolProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      expect(PenStyle.of(c.read(editorToolProvider)),
          defaultPenFor(PenKind.ballpoint));
    });

    test('saved pens equal to old defaults load as the new ones', () async {
      final n = PenPresetsNotifier(
          _MemoryPrefs(presets: const [_yellowHighlighter, _redBallpoint]));
      await Future<void>.delayed(Duration.zero);
      expect(n.state, [defaultPenFor(PenKind.highlighter), _redBallpoint]);
    });
  });

  group('recent colours', () {
    test('newest first, no repeats, at most six', () async {
      final prefs = _MemoryPrefs();
      final n = RecentColorsNotifier(prefs);
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 8; i++) {
        n.use(0xFF000000 + i);
      }
      n.use(0xFF000005);
      expect(n.state.first, 0xFF000005);
      expect(n.state.length, kMaxRecentColors);
      expect(n.state.toSet().length, n.state.length);
      expect(prefs.recent, n.state);
    });
  });
}

