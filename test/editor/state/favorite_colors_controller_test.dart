import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/state/favorite_colors_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts on the defaults before anything is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final c = FavoriteColorsController();
    expect(c.state, FavoriteColorsController.defaults);
    expect(c.state.length, FavoriteColorsController.slots);
  });

  test('restores a persisted triple on construction', () async {
    SharedPreferences.setMockInitialValues({
      'editor.favoriteColors': ['4294901760', '4278255360', '4278190335'],
    });
    final c = FavoriteColorsController();
    await Future<void>.delayed(Duration.zero); // let _restore complete
    expect(c.state, [4294901760, 4278255360, 4278190335]);
  });

  test('a malformed / wrong-length stored value falls back to defaults',
      () async {
    SharedPreferences.setMockInitialValues({
      'editor.favoriteColors': ['not-a-number', '123'],
    });
    final c = FavoriteColorsController();
    await Future<void>.delayed(Duration.zero);
    expect(c.state, FavoriteColorsController.defaults);
  });

  test('setColor updates the slot and persists it', () async {
    SharedPreferences.setMockInitialValues({});
    final c = FavoriteColorsController();
    await c.setColor(1, 0xFF00FF00);

    expect(c.state[1], 0xFF00FF00);
    // Other slots are untouched.
    expect(c.state[0], FavoriteColorsController.defaults[0]);

    // A freshly-constructed controller reads back the persisted value.
    final reloaded = FavoriteColorsController();
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.state[1], 0xFF00FF00);
  });

  test('setColor ignores out-of-range indices', () async {
    SharedPreferences.setMockInitialValues({});
    final c = FavoriteColorsController();
    await c.setColor(9, 0xFFABCDEF);
    await c.setColor(-1, 0xFFABCDEF);
    expect(c.state, FavoriteColorsController.defaults);
  });
}
