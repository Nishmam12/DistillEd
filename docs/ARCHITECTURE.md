# InkFlow 2.0 — Architecture & Rebuild Decisions

> Living document. Authored at **Phase 0** of the ground-up rebuild. Captures
> the audit of the 1.0.2 codebase, the locked architectural decisions, and the
> persistence/migration contract. App version at start of rebuild: **1.0.2+6**.

---

## 1. Goal

Rebuild InkFlow on a clean, layered foundation reaching near-parity with
Excalidraw's drawing engine, **in Dart/Flutter only**, while keeping every
existing note-taking feature and **all user data**. Excalidraw
(`./excalidraw-master/`, React/TS) is a **spec only** — port algorithms, never
copy `.ts`/`.tsx`, no runtime dependency.

Delivered **one phase per turn**; each phase ends at a checkpoint
(`flutter analyze` clean, `flutter test` green) and waits for explicit approval.

## 2. Architecture map (1.0.2 — audited, what we are replacing)

Feature-first with `domain/` `data/` `presentation/` layers. ~85 Dart files.

| Area | Location | Notes |
| --- | --- | --- |
| App / routing | `lib/app/` | `app.dart`, `router.dart` (GoRouter: `/`, `/import/pdf`, `/note/:id`, `/note/:id/book`, `/settings`, `/about`) |
| Core | `lib/core/` | `constants/` (app_colors, storage_paths), `providers/settings_provider`, `theme/` |
| Isar singleton | `lib/shared/isar/isar_service.dart` | Opens DB `inkflow` at appDocs; registers `NotebookSchema`, `NotePageSchema` |
| Editor models | `lib/features/editor/domain/models/` | `stroke`, `stroke_point`, `shape_element`(+`.g`), `shape_type`, `imported_content`(+`.g`), `template_type` |
| Editor services | `lib/features/editor/domain/services/` | `shape_recognizer`, `eraser_service`, `lasso_hit_tester`, `binding_service` |
| Undo/redo | `lib/features/editor/domain/undo_redo/` | `command` + 7 command classes + `undo_redo_stack` |
| Editor storage | `lib/features/editor/data/storage/` | `ink_file_storage`, `page_cache_manager`, `thumbnail_cache_manager`, `pdf_cache_manager`, `page_thumbnail_service`, `autosave_manager` |
| Editor state | `lib/features/editor/presentation/` | 9 Riverpod `StateNotifier`s + undo/redo provider |
| Editor screens | `.../presentation/screens/` | `note_editor_screen.dart` (571 lines), `book_view_screen.dart` |
| Canvas | `.../presentation/canvas/` | `canvas_widget`, `rough_renderer`, `input/` (raw_pointer_listener, shape/lasso handlers), `layers/` (6 painters) |
| Home | `lib/features/home/` | `Notebook`(+`.g`), `NotePage`(+`.g`), `NoteRepository`, `PageRepository`, `home_notifier`, `home_screen` |
| Import | `lib/features/import/` | `pdf_service` (isolate), `image_service` (isolate) |
| Export | `lib/features/export/` | `canvas_export_service` (A4 300dpi), `export_share_service` |
| Settings | `lib/features/settings/` | settings + about |

**Render stack (6 RepaintBoundary layers):** Background → ImportedContent →
CombinedContent (committed strokes+shapes, pixel-erase, pending-erase preview) →
ActiveStroke (only fast-repainting layer; perfect_freehand) → Selection (lasso
preview + bounds/handles) → EraserTrail (ticker fade).

**Proven systems to PORT (do not reinvent):**
- Viewport: `screenX = scrollX + zoom*sceneX`, zoom 0.1–5.0, focal-anchored
  `zoomAtPoint` (`viewport_notifier.dart`).
- Palm rejection: 500 ms grace window, retroactive stylus-after-palm rejection,
  hover pre-arm (`raw_pointer_listener.dart`). **Hard-won — preserve exactly.**
- Rough rendering: two-pass wobble + 45° hachure, seeded (`rough_renderer.dart`).
- Arrow binding: `bindNewArrow`, `rerouteArrows`, Chebyshev (box) / radial
  (circle) edge anchor (`binding_service.dart`).
- Undo/redo: command pattern, per-page stacks; batch commands for lasso ops.
- Eraser: two-phase segment eraser (note editor, undoable) vs legacy point-based
  `eraseAtPoint` (book view, not undoable).
- perfect_freehand opts: `thinning 0.6, smoothing 0.5, streamline 0.5,
  easing sin(t·π/2)`.

## 3. Persistence contracts (confirmed — fixed unless migrated)

### Strokes — `.ink` JSON files (NOT in DB)
- Path: `<appDocs>/notes/<notebookId>/page_<pageId>.ink`. Both ids are Isar
  auto-increment ints; **`pageId` = `NotePage.id`** (not `pageIndex`).
- Schema: JSON array of
  `{id, color(int ARGB), size, opacity, isEraser, points:[{x, y, p, sim?}]}`
  where `p` = pressure, `sim` present only when `simulatePressure == true`.
- Atomicity: write `.tmp` → rename onto final + `.bak` backup; load falls back
  final → `.bak` → `.tmp`; corrupted files skipped.

### Isar `inkflow` (at appDocs)
- `Notebook { Id id; title; createdAt; modifiedAt; pageCount(@Index); backgroundColor; templateIndex }`
- `NotePage { Id id; notebookId(@Index); pageIndex; createdAt; modifiedAt; importedContents:[ImportedContent]; shapes:[ShapeElement] }`
- `ShapeElement` (`@embedded`, 20 fields): `id`, `@enumerated type` (ShapeType),
  `color`, `strokeWidth`, `hasFill`, `fillColor`, `opacity`,
  `geometryData:List<double>` (interpreted per type), `rotation`,
  `text/fontSize/fontFamily/isBold/isItalic`, `svgRelativePath`, `zOrder`,
  `seed`(=0 default), `roughness`(=0 default), `startBindingId/endBindingId`.
- `ImportedContent` (`@embedded`): `id`, `typeId` (pdfBackground|freeImage),
  `relativeImagePath`, `sourceDescription`, `x/y/width/height`, `rotation`,
  `opacity`, `zOrder`.

**ShapeType enum order is a fixed Isar contract** — `line, arrow, circle,
rectangle, triangle, polygon, textBox, svgImage, diamond` (diamond appended
last). Never reorder; only append.

### Images / PDFs
- Cached as files under `notes/<notebookId>/imports/` + thumbnails.
- `dart:ui.Image` lifecycle: `PdfCacheManager` clones + LRU-disposes;
  `PageThumbnailService` returns a fresh instance per read (partial mitigation
  of the "Cannot clone a disposed image" crash — 2.0 formalizes ref-counting).

### Discrepancies vs prompt §2 (recorded)
1. `get_it` is in pubspec but **unused** — DI is Riverpod + `IsarService`
   singleton only. 2.0 stays Riverpod-only; `get_it` should be dropped.
2. A lasso-based selection + move/resize/rotate (with `LassoTransformCommand`)
   already exists; Phase 4 **extends/replaces** it toward Excalidraw
   marquee + 8 handles + snapping + grouping.
3. No Isar migration logic exists (Isar auto-migrates additive changes only) →
   the unified collection requires an explicit migrator (§5).

## 4. Locked decision — unified model + consolidated Isar

**Chosen (by user): unify in memory AND consolidate storage into one Isar
collection with a written, versioned migrator.**

### In-memory model
Sealed `SceneElement` hierarchy, used uniformly by selection, transform,
snapping, grouping, z-order, alignment:

```
SceneElement (sealed) — id, kind, zOrder, rotation, opacity, isLocked, groupIds, bounds
 ├ FreehandElement — points:[StrokePoint], color, size, isEraser        (was Stroke / .ink)
 ├ ShapeElement    — shapeType, geometryData, stroke/fill style, fillStyle,
 │                   strokeStyle, edges, roughness, seed, start/endBindingId (was ShapeElement)
 ├ TextElement     — text, fontFamily, fontSize, bold/italic, align,
 │                   containerId (bound text)                            (was ShapeType.textBox)
 ├ ImageElement    — relativeImagePath, opacity         (was ImportedContent.freeImage + svgImage)
 └ PdfBackground   — locked ImageElement sent to back   (was ImportedContent.pdfBackground)
```

### On-disk (consolidation)
One new top-level Isar collection, **one row per element**, indexed by `pageId`
(+`notebookId`), replacing per-page embedded `shapes`/`importedContents` and the
`.ink` files going forward. Per-row storage enables incremental autosave (write
only changed elements) vs today's full-page / full-file rewrites.

```dart
@collection class SceneElementRecord {
  Id id = Isar.autoIncrement;        // row id
  @Index() late int pageId;          // FK → NotePage.id
  @Index() late int notebookId;
  late String elementId;             // stable element UUID
  @enumerated late SceneElementKind kind;  // freehand|shape|text|image
  late int zOrder; late double rotation, opacity; late bool isLocked;
  // freehand: List<double> points [x,y,pressure,...] + List<bool> pointSim (lossless vs .ink)
  // shape/image/text geometry: List<double> geometryData
  // style: color, strokeWidth, hasFill, fillColor, fillStyle, strokeStyle, edges, roughness, seed
  // shape kind: @enumerated ShapeType
  // text: text, fontSize, fontFamily, isBold, isItalic, align, containerId
  // image: relativeImagePath
  // bindings: startBindingId, endBindingId
}
@collection class AppMeta { Id id = 0; late int schemaVersion; }  // gates migration
```

**Non-destructive transition:** the migrator reads old `.ink` + old
`NotePage.shapes`/`importedContents` and writes `SceneElementRecord`. It never
deletes `.ink` files or clears the old embedded fields (kept as rollback
source). Removing legacy fields/files is deferred to a later phase once parity
is confirmed, and is its own STOP-and-ASK.

## 5. Migrator (v1 → v2)

`SceneMigratorV2` (`lib/data/migration/`) runs once on launch when
`AppMeta.schemaVersion < 2`:
1. For each `Notebook` → each `NotePage`:
   - `.ink` via `InkFileStorage.loadStrokes` → `FreehandElement` rows.
   - `NotePage.shapes` → shape/text/image rows (textBox→Text, svgImage→Image,
     else→Shape); preserve `seed`, `roughness`, geometry, bindings, rotation.
   - `NotePage.importedContents` → ImageElement rows (pdfBackground → locked,
     sent to back).
2. z-order fidelity: bands preserving current stacking — imported (back) <
   strokes < shapes — intra-band order preserved. (Exact intra-CombinedContent
   order to be confirmed from `combined_content_layer.dart` in Phase 1.)
3. Set `AppMeta.schemaVersion = 2`. Idempotent (keyed by `pageId`+`elementId`).
4. Old data untouched (rollback-safe).

## 6. Target folder structure (2.0)

New top-level siblings coexist with the old feature folders during transition
(features are migrated in over phases, not moved in Phase 0):

```
lib/
  core/            theme, colors, constants, DI conventions, result/error types
  data/
    persistence/   IsarService, SceneElementRecord store, InkFileStorage (back-compat), file IO
    migration/     1.x → 2.0 migrators (SceneMigratorV2), AppMeta gate, versioned
  domain/
    model/         SceneElement hierarchy, Stroke, Notebook, Page, Viewport
    geometry/      bounds, collision, distance, transforms, snapping (ported)
    services/      binding, recognizer, eraser, grouping, z-order, alignment
    commands/      undo/redo command pattern (one command per mutation)
  editor/
    state/         SceneController, ToolController, SelectionController, ViewportController, HistoryController
    input/         raw pointer → palm rejection → tool router → gesture/command
    render/        layered CustomPainters
    tools/         pen, eraser, selection, shapes, text, image, laser, hand
    ui/            editor screen, toolbars, panels, pickers
  features/
    home/  bookview/  import/  export/  settings/
```

## 7. DI convention

No service locator. **Riverpod** providers form the dependency graph;
**`IsarService`** is the single DB singleton (opened in `main.dart` before
`runApp`). `get_it` is declared but unused and will be removed. New services
(e.g. `SceneElementStore`, `SceneMigratorV2`) are exposed as Riverpod providers
that depend on `IsarService.instance`.

## 8. Hard constraints (carry forward every phase)

1. Dart/Flutter only; Excalidraw is spec, not source.
2. Preserve user data; never destroy notes without a reviewed, tested migrator.
3. Phased delivery; each phase: analyze clean + tests green + summary + STOP.
4. No over-engineering — build only what the phase specifies.
5. STOP-and-ASK before: deleting files outside a phase's scope, changing an Isar
   schema / `.ink` format beyond the approved migrator, adding a dependency, or
   removing palm-rejection logic.
6. Perf budget: 60fps stylus while pan/zoom on ~500 strokes + 100 shapes
   (mid-range Android tablet). RepaintBoundary + static/active layer separation.
7. Every phase ships tests.

## 9. Phase roadmap

- **P0 (this)** Audit, decisions, migration test plan, directory skeleton. No behavior change.
- **P1** Unified `SceneElement` model + geometry primitives + `SceneElementRecord`/`AppMeta` Isar (build_runner — mind OneDrive `.dart_tool/build` lock) + `SceneMigratorV2` + `SceneController`. Migration tests green.
- **P2** Viewport + layered painters + perfect_freehand pen + exact palm-rejection port. 60fps/500 strokes.
- **P3** All shape tools (elbow arrows, rounded corners), rough renderer, bound + standalone text, first-class image elements, styling panel.
- **P4** Marquee multi-select, 8 handles + rotate (aspect/center), snapping + guides, grouping, z-order, align/distribute, arrow binding, duplicate/copy/paste/lock.
- **P5** Eraser (stroke+pixel) + laser, command history across all mutations, debounced autosave with ref-counted image lifecycle.
- **P6** Frames, element library, export PNG/SVG/PDF/clipboard/share.
- **P7** Home CRUD, correct Book View (spreads, page-turn animation, filmstrip, per-notebook paper color, no gesture conflict), templates, import, settings + About.
- **P8** Hardening, full regression, perf profiling, remove legacy code after parity (STOP-and-ASK), version bump + CHANGELOG.
