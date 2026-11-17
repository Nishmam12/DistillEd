import 'package:flutter_test/flutter_test.dart';
import 'package:margo/editor/state/toolbar_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('never customised: every tool, in the standard order', () {
    expect(ToolbarLayout.fromStored(null, null).shown, kToolbarItems);
  });

  test('kept order and hidden tools; unknown ids dropped; a tool new to this '
      'build is shown at the end', () {
    final layout = ToolbarLayout.fromStored(
      ['eraser', 'pen', 'gone-tool', 'pen'],
      ['select', 'shape', 'arrow', 'text', 'tape'],
    );
    // 'laser' is in neither list, as a tool added later would be.
    expect(layout.shown, ['eraser', 'pen', 'laser']);
    expect(layout.hidden, ['select', 'shape', 'arrow', 'text', 'tape']);
  });

  test('a stored empty bar falls back to the standard one', () {
    expect(ToolbarLayout.fromStored([], kToolbarItems).shown, kToolbarItems);
  });

  test('saved and read back; reset forgets it', () async {
    SharedPreferences.setMockInitialValues({});
    final a = ToolbarLayoutNotifier();
    await Future<void>.delayed(Duration.zero);
    await a.set(['text', 'pen']);
    await a.set([]); // ignored
    expect(a.state.shown, ['text', 'pen']);

    final b = ToolbarLayoutNotifier();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(b.state.shown, ['text', 'pen']);

    await b.reset();
    final c = ToolbarLayoutNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.shown, kToolbarItems);
  });
}
