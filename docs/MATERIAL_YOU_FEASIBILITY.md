# Material You feasibility

Findings from a spike on 2026-10-30, against commit `e5fb4d6` (branch
`embeddinggemma-2`), Flutter 3.47.9. The spike ran in throwaway worktrees. None
of it is in the codebase, so the code below has to be re-applied. Nothing here
has been implemented or decided yet.

## Verdict

Feasible. Estimate for wallpaper colours as an opt-in setting: about 2-3 days
(a judgement, not a measurement).

The app already sets `useMaterial3: true`. What is missing is wallpaper-based
colour. Chrome reads 11 `AppColors` tokens (387 `context.colors` uses in `lib/`,
43 files), so deriving those tokens from a generated scheme recoloured the home
screen, dialogs and editor toolbar in about 30 lines.

## Recommendation

1. Ship route B (below) first. Do route A later as its own PR.
2. Add a "Use wallpaper colours" setting, off by default. Sage stays the default
   because it is Margo's identity; with wallpaper colours on, even the wordmark
   changes colour.
3. Fix the palette-change bug regardless of this feature. It affects users today.
4. Do not rebuild screens with stock Material components. The custom sidebar and
   cards are deliberate design (`NavigationBar`, `NavigationRail`, `Card` and
   `SearchBar` have 0 uses in `lib/`), so that would be a redesign with little
   payoff.
5. Do not chase Material 3 Expressive yet. Flutter's blog says official work is
   underway but gives no package or date.

## Test results

| Check | Result |
|---|---|
| Contrast rules from `app_colors_test.dart` on `ColorScheme.fromSeed` palettes: 218 seeds, light and dark | No failures. Lowest 4.5:1 pair was 5.23:1 (light `brand` on `surfaceSubtle`) |
| Route A: `flutter analyze` after `dart fix` | No issues |
| Route A: full test suite after `dart fix` | 2,714 pass, 3 skipped. Run before `DynamicColorBuilder` was wired in |
| Route A: `DynamicColorBuilder` plus bridge in `app.dart` | Analyzes with 1 info: the bridge is deprecated. Never built or run on a device |
| Route B: full test suite | 2,714 pass, 3 skipped |
| Route B: debug APK on `Pixel_Tablet` emulator (API 35, x86_64) | Builds and runs; blue and pink palettes work in light and dark |

The contrast sweep covers token pairs only. It does not catch hardcoded colours
or tokens drawn at reduced alpha, which is where the visual problems below came
from.

## Integration problem

`dynamic_color` 2.1.0 (material.io) imports `package:material_ui`, so its
`ColorScheme` is a different Dart type from the one in
`package:flutter/material.dart`, which the app imports. The standard setup fails
with `argument_type_not_assignable`. `DynamicColorPlugin` itself imports only
`flutter/services`, so it can be used without touching the app's Material import.

The SDK's Material library is frozen; `material_ui` is where development goes.
Flutter's docs say deprecation is scheduled for an unspecified upcoming stable
release, and the blog gives no removal date. A freeCodeCamp handbook says
November 2026, but no official source confirmed it.

## The two routes

| | A: migrate to `material_ui` | B: stay on the SDK's Material |
|---|---|---|
| Change | `dart fix --apply --code=migrate_design_widgets`: 120 files, 122 with pubspec and lock | Use only `DynamicColorPlugin`; seed the scheme from its palette |
| Colour accuracy | Should match the system palette (not verified on a device) | Close, but regenerated from one seed |
| Risk | `flutter_math_fork`, `pdfx`, `photo_view` and others still import the old Material, so it needs `MaterialUiCompatibilityBridge`, already deprecated | Eventually has to migrate anyway |

`go_router` already depends on `material_ui`, so it is in the dependency tree
transitively today. Before route A, check maths, PDF and image screens on a
device; the tests do not prove those packages pick up the theme at runtime.

## Route B spike code

Extra dependencies: `dynamic_color`, `material_color_utilities`.

`lib/core/theme/app_colors.dart`:

```dart
factory AppColors.fromScheme(ColorScheme s) {
  final dark = s.brightness == Brightness.dark;
  return AppColors(
    bgPrimary: s.surface,
    surface: s.surfaceContainerLow,
    surfaceSubtle: s.surfaceContainerHigh,
    accent: s.primary,
    onAccent: s.onPrimary,
    textPrimary: s.onSurface,
    textSecondary: s.onSurfaceVariant,
    border: s.outlineVariant,
    accentMuted: s.primary.withAlpha(((dark ? 0.16 : 0.12) * 255).round()),
    brand: s.primary,
    fieldFill: s.secondaryContainer,
  );
}
```

`lib/core/theme/margo_theme.dart`:

```dart
static ThemeData fromSeed(Color seed, Brightness b) => _build(
    b, AppColors.fromScheme(ColorScheme.fromSeed(seedColor: seed, brightness: b)));
```

`lib/app/app.dart`:

```dart
final _wallpaperSeedProvider = FutureProvider<Color?>((ref) async {
  final palette = await DynamicColorPlugin.getCorePalette();
  return palette == null ? null : Color(palette.primary.get(40));
});

// in MargoApp.build
final seed = ref.watch(_wallpaperSeedProvider).value;
// theme:     seed == null ? MargoTheme.light : MargoTheme.fromSeed(seed, Brightness.light)
// darkTheme: seed == null ? MargoTheme.dark  : MargoTheme.fromSeed(seed, Brightness.dark)
```

The spike has no setting and always applies wallpaper colours. Existing tests
that use `same(AppColors.light)` passed because the test wiring still uses the
static themes.

## Issues to fix

1. **Palette change leaves the open note (existing bug).** Changing the system
   palette while a note is open returns to Home. The unmodified app does it too.
   Strokes survived; undo history was not checked.
   - Adding `assetsPaths` to `configChanges` in `AndroidManifest.xml` keeps the
     note open (tested).
   - Colours then stay stale until the palette is re-read, so the fix also needs
     a refresh, such as invalidating the seed provider on a configuration change
     or resume (not built or tested).
2. **Placeholder nearly invisible.** The "Note title" hint is white at 50% on the
   generated field colour:
   `lib/features/home/presentation/widgets/new_note_dialog.dart:135`.
3. **Weak accent fills.** "+ new" (`notes_screen.dart`, around line 428) and the
   dialog's Cancel/Create pills use the accent at 50%.
4. **Fixed undo/redo colours.**
   `lib/editor/ui/controls/undo_redo_buttons.dart:54`.
5. **No themed launcher icon.** Only PNG mipmaps exist, with no `mipmap-anydpi-v26`.
   Needs an adaptive icon with a `<monochrome>` layer (Android 13+).

Leave alone: pen ink and paper are user content (`paper_colors.dart`), and the
page stayed white in the test. Other literals in `lib/editor/render/` are canvas
and export colours and were not reviewed individually.

## Not tested

- Android 12-14, phones, and any physical device.
- Real wallpapers. Palettes were set with a system setting, not a wallpaper change.
- Android below 12. `minSdk` is 26 and the plugin lists Android 12+, so these
  should fall back to sage, but that was not run.
- Settings screen and other screens under wallpaper colours (home, new-note
  dialog and editor were seen).
- Route A on a device.

## Reproducing on an emulator

The package is `com.margo.margo`, activity `.MainActivity`. The AVD also has a
separate `com.inkflow.inkflow` app with its own notes, so confirm the foreground
app before sending taps.

Set a palette (use a current timestamp in milliseconds):

```sh
adb shell "settings put secure theme_customization_overlay_packages '{\"android.theme.customization.system_palette\":\"1565C0\",\"android.theme.customization.color_source\":\"preset\",\"android.theme.customization.theme_style\":\"TONAL_SPOT\",\"_applied_timestamp\":1790000000000}'"
```

Restore: `adb shell settings delete secure theme_customization_overlay_packages`.

## Sources

- https://pub.dev/packages/dynamic_color
- https://pub.dev/packages/material_ui
- https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
- https://flutter.dev/blog/decoupling-material-cupertino
- https://www.freecodecamp.org/news/how-to-work-with-material-and-cupertino-decoupling-in-flutter-full-handbook/
- https://developer.android.com/develop/ui/views/launch/icon_design_adaptive?authuser=1
