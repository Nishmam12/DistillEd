# InkFlow 2.0 — Migration Test Plan (1.0.2 → 2.0)

> Proves that a notebook authored in InkFlow **1.0.2** opens in **2.0** with
> every stroke, shape, text, PDF/image, and setting intact. This is the
> safety net for the user-approved storage consolidation
> (unified `SceneElementRecord` Isar collection + written migrator). See
> `docs/ARCHITECTURE.md` §4–5 for the model and migrator design.

## 0. Why this matters

The migrator (`SceneMigratorV2`) is the single most safety-critical artifact in
the rebuild: it converts the legacy split storage (`.ink` files + embedded
`NotePage.shapes`/`importedContents`) into the unified `SceneElementRecord`
collection. It must be **lossless, idempotent, and non-destructive**. No phase
that touches it is "done" until every test below is green.

## 1. Test harness

- Location: `test/data/migration/`.
- Isar in tests: open a real Isar instance in a unique temp directory per test
  (`Isar.open([...], directory: tmp, name: 'test_<uuid>')`); tear down + delete
  the dir in `tearDown`. (Isar has no in-memory mode; temp-dir is the standard
  test approach. Requires the native test binary via `isar_flutter_libs` /
  `Isar.initializeIsarCore(download: true)` in a setup hook, or run as an
  integration test on device.)
- `.ink` fixtures: write JSON strings to a temp dir and read through the real
  `InkFileStorage` API so we exercise the actual loader (incl. `.bak`/`.tmp`
  fallback), not a reimplementation.
- Old-format data: the legacy `Notebook`/`NotePage`/`ShapeElement`/
  `ImportedContent` schemas remain in the codebase during the transition, so
  old-format pages are constructible directly in-test.

## 2. Fixtures

- **F1 — `.ink` strokes:** a JSON array covering: a stroke with explicit
  `opacity`, a stroke omitting `opacity` (expect default `1.0`), points with
  `sim:true` present and points with `sim` absent (expect `false`),
  `isEraser:true` stroke.
- **F2 — shapes:** one `ShapeElement` of **each** `ShapeType` including
  `diamond` (enum index 8); an `arrow` with non-empty `startBindingId` +
  `endBindingId`; a shape with default `seed=0` and `roughness=0`; a `textBox`
  with text/font fields; an `svgImage` with `svgRelativePath`.
- **F3 — imported content:** one `freeImage` and one `pdfBackground`, each with
  a `relativeImagePath`, transform (`x/y/width/height/rotation/opacity`), and
  `zOrder`.
- **F4 — representative page:** a single `NotePage` combining F1 strokes + F2
  shapes + F3 imported content with known relative z-stacking.

## 3. Test cases

### `.ink` parse fidelity
- `ink_parse_fidelity_test.dart`
  - F1 → `FreehandElement`s; assert per-point `x/y/pressure` and `sim` preserved
    exactly; missing `opacity` → `1.0`; `isEraser` preserved.
  - Empty `.ink` file → zero elements (no crash).
  - Corrupted final file with a valid `.bak` → loads from `.bak`.

### Shape conversion
- `shape_conversion_test.dart`
  - Each `ShapeType` maps to the correct unified element:
    `textBox→TextElement`, `svgImage→ImageElement`, all others→`ShapeElement`.
  - `geometryData` copied byte-for-byte; `rotation`, `seed`, `roughness`,
    `color`, `strokeWidth`, `hasFill`, `fillColor`, `opacity`, `zOrder`
    preserved.
  - Arrow `startBindingId`/`endBindingId` preserved.
  - `diamond` (index 8) survives the round-trip (guards enum-order contract).

### Imported content conversion
- `imported_content_conversion_test.dart`
  - `freeImage` → `ImageElement` with `relativeImagePath`, transform, opacity.
  - `pdfBackground` → locked `ImageElement` placed at the back (lowest z band).
  - Paths preserved verbatim (relative, never absolute).

### Whole-page golden
- `page_migration_golden_test.dart`
  - Seed temp Isar (F4 page) + matching F1 `.ink` → run `SceneMigratorV2`.
  - Assert: total element count = strokes + shapes + imported items;
    each element's key fields; **z-order ordering** = imported (back) <
    strokes < shapes, intra-band order preserved.

### Idempotency
- `migration_idempotency_test.dart`
  - Run the migrator twice → element count unchanged; no duplicate
    `(pageId, elementId)` rows; `AppMeta.schemaVersion == 2`.

### Non-destruction
- `migration_non_destruction_test.dart`
  - After migration: original `.ink` files still exist on disk; old
    `NotePage.shapes` and `NotePage.importedContents` still populated.

### Gate behavior
- `migration_gate_test.dart`
  - Fresh DB (no `AppMeta`) → migration runs, sets version 2.
  - `AppMeta.schemaVersion == 2` already → migrator is a no-op.

## 4. Manual verification (device/emulator, end of Phase 1)

> **Status: NOT RECORDED.** The automated cases (`test/data/migration/`, including
> the per-page "migrated" marker and a pre-migration database copy,
> `inkflow_before_v2.isar`) pass, but nothing in the repo records this walkthrough
> being run on a real device with a copied 1.0.2 data set. Run it and tick the
> boxes below before calling the migration verified.

1. Build 2.0 over an existing 1.0.2 app-docs directory (copy a real 1.0.2
   `inkflow.isar` + `notes/` tree onto the device).
2. Launch → every notebook appears; open each page → strokes, shapes, text,
   PDF backgrounds, and free images render identically to 1.0.2.
3. Per-notebook `backgroundColor` and `templateIndex` still applied.
4. Re-launch → no re-migration, no duplicates (idempotency holds in the field).

## 5. Definition of done (migration)

- All §3 tests green under `flutter test`.
- Manual §4 walkthrough passes on a copied 1.0.2 data set.
- No legacy data deleted; rollback path intact until a later, separately
  approved cleanup phase.
