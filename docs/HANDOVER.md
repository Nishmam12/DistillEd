# Margo polish roadmap: handover

Written 2026-11-13, updated 2026-11-14 after the first device test. Read this
first, then `CLAUDE.md`, then the roadmap file named below. Everything here was
true at the commit that last changed this file.

## 1. Where things stand

| Item | State |
| --- | --- |
| App | Margo, Flutter, Android only. `pubspec.yaml` version `5.1.1+32`. |
| Branch | **`margo-device-fixes`** (pushed to `origin`, DistillEd), cut from `margo-backup-figures` (`9437aaf`, `5.1.0+31`). Adds: merge `9a493fe` of `origin/SettingsUI-upgrade` (Afnan's Settings redesign), the Settings overflow fix `5cc9e11`, and the pen rework `43ca580`. |
| Roadmap | `C:\Users\nabil\.claude\plans\go-through-the-entire-humble-gem.md` (approved 2026-11-11). Order: 0 → A → E1/E2 → D2 → B → C → D → F → G → H. |
| Done in code | Phase 0, Phase A, Phase E1/E2, Phase D2. |
| Next | Fix the device-test findings in section 4a, in the order and on the models listed there. Then Phase B. |
| `flutter analyze` | Clean. |
| Settings | Redesigned by Afnan (`SettingsUI-upgrade`, merged 2026-11-13): two-column icon cards, AI models and HuggingFace token on `/settings/models`. Backup is its own card; "Draw with finger" is in the Pen card. `settings_backup.dart` uses the new SVG `AppIcons`. Option chips (`AppChipGroup`) now wrap. If Afnan keeps working on the old branch, the Backup card will conflict again. |
| `flutter test` | 2,929 pass, 44 skipped. `test/core/error_log_test.dart` ("once past 100 KB…") fails in some full runs and passes alone. It is flaky under load and unrelated to this work. |
| On-device testing | First device test 2026-11-14 on a Xiaomi tablet (`2410CRP4CG`, Android 16, 7.6 GB RAM), profile build. Results in section 4a. |

Commits on top of `01cc65d`:

| Commit | Phase | Summary |
| --- | --- | --- |
| `d3e0aca` | pen 1 | Device-decided pressure, erase from the pen, in-place live stroke. |
| `57062a8` | 0 | AI panel keeps the view, finger-scroll setting, easier import. |
| `b6c4bfc` | A | Four pens, saved pens, custom colours, straighten, tap gestures. |
| `a5e6f0c` | E | Automatic backup to Downloads/Margo, `.margo` export/import. |
| `e851145` | D2 | Figures the AI can locate, re-examine, correct and measure. |

Deliberately **left uncommitted** in the working tree. They are older,
separate work; do not fold them into roadmap commits without asking:

- `android/app/build.gradle.kts`, `android/build.gradle.kts`,
  `android/app/proguard-rules.pro`: an unfinished R8 setup (roadmap Phase H).
- `lib/features/home/presentation/screens/notes_screen.dart`,
  `lib/features/home/presentation/widgets/search_popover.dart`.
- `.vscode/`.

## 2. Standing rules

These come from `CLAUDE.md`, project memory and the user. They are not
optional.

1. Run `graphify query "<question>"` before reading or grepping code, and
   `graphify update .` after changing code. A hook enforces the first.
2. Do not start a phase unprompted. Summarise the handoff and wait for a
   go-ahead, even on a bare "continue".
3. **Stop and ask** before: any Isar schema change, any new dependency, any
   `git push`.
4. Isar enums are append-only. A schema change needs a migrator test.
5. Do not alter palm rejection in `scene_pointer_listener.dart`.
6. Before any push: bump `pubspec.yaml` version and update `CHANGELOG.md`.
7. **Never add a `Co-Authored-By: Claude` trailer** to commits in this repo.
8. Installs and caches go on `G:` (`C:` is full).
9. Repository visibility has changed before and an old Hugging Face token is
   still in the history of the old `Notepad-` remote. Check before acting on
   anything involving remotes or secrets. Keep the user's email and project
   details out of requests to outside services.
10. **Figure recognition must be light on the device.** The user's words:
    "should be efficient and should not be heavy on device at all, if needed
    we can move it to cloud as 2nd option". Count on-device vision calls per
    page whenever the figure pipeline changes.
11. At every handoff, name the model the next step belongs on, and stop if
    the session is on the wrong one.
12. End each phase with: analyze clean, tests green, a summary, then stop.

Shell quirks on this machine (Windows, Git Bash):

- A bash heredoc containing an apostrophe fails with "unexpected EOF". Write
  scripts and commit messages to a file with the Write tool and run them
  (`python script.py .`, `git commit -F file`).
- A literal `\n` inside Dart source is easy to corrupt from Python string
  replacement. Use the Edit tool, or `chr(92) + 'n'`.
- `build_runner` reformats unrelated `.g.dart` files. Revert those with
  `git checkout`.

## 3. What each finished phase added

### Phase 0: fixes for the two reported pain points

- **AI side panel no longer distorts the page.** A viewport resize keeps the
  same content on screen and restores the exact view on close
  (`viewport_controller.dart`: `_resizeViewport`, `_restorePoint`). The
  keyboard no longer resizes the canvas. The panel can be dragged wider or
  narrower and remembers its width.
- **"Draw with finger" setting.** Off means one finger pans and only the pen
  draws (`fingerPans` in `scene_pointer_listener.dart`, after the palm gate).
- **Import rework.** Pictures arrive in a placement mode (move, resize,
  confirm). PDF import has a sheet with page range, insert position, progress
  and cancel. Imported PDF pages are locked backgrounds.

### Phase A: writing feel

- `PenKind { ballpoint, highlighter, fountain, pencil }` stored on
  `FreehandElement` and `SceneElementRecord` (schema field approved by the
  user).
- Up to five saved pens on the toolbar; tool state persists between sessions
  (`lib/editor/state/pen_presets.dart`).
- Custom colour dialog with hex entry and recent colours.
- Hold at the end of a stroke to straighten it; two-finger tap undo,
  three-finger tap redo; haptics.
- **Not done:** latency work (A5), turning snap-shapes on by default (A7).

### Phase E: backup

- `.margo` archive: a zip with `manifest.json` (lossless), `notebook.md`
  (readable) and `media/`. Code in `lib/data/backup/`.
- Settings → Backup: on/off, frequency, "Back up now", status, restore from
  a file. Backups are written to **Downloads/Margo** through MediaStore
  (`MainActivity.kt`, channel `com.margo.margo/backup`).
- Unchanged notebooks are skipped. Restore always adds a copy.
- Step 17: the last five dated snapshots of each notebook are kept
  (`<title> (<id>) <date time>.margo`, pruned from the saved state), and
  Settings → Backup → Restore opens a list of them
  (`lib/features/backup/restore_list_screen.dart`). Android shows an app only
  the files it wrote, so the list can be empty after a reinstall; the file
  picker stays as a fallback.
- **Not done:** offering restore on first launch or after a failed database
  open.
- **Never compiled:** the Kotlin side. Expect the first Android build to
  need fixes.

### Phase D2: figures

The pipeline lives in `lib/features/ai/domain/`.

| File | Job |
| --- | --- |
| `figure_locator.dart` | Finds separate drawings on a page (shapes plus ink that is not handwriting). |
| `scene_graph_figure.dart` | Reads a flowchart made of labelled shapes and arrows exactly, with no model. |
| `figure_analyzer.dart` | Vision read: on-device first, quality bar, cloud escalation. `cacheVersion = 'fig2'`. |
| `figure_grounding.dart` | Checks a reading's labels against text read another way. |
| `figure_detail.dart` | Second read for equations (LaTeX) and tables (Markdown table). |
| `features/figure_qa.dart` | Shows the figure and the question to the vision model at question time. |
| `figure_benchmark.dart` | The benchmark runner and scoring. |
| `page_content_extractor.dart` | Ties it together. Also `figureImage`, `rereadFigure`, `correctFigure`, `extractPage(economy:)`. |

User-visible results:

- Each drawing is read on its own, with its caption as context, and knows
  where it is on the page.
- A reading whose labels are not on the page goes to the cloud when allowed,
  otherwise it is kept and marked "Not confirmed".
- Ask looks at the figure itself when the question is about one, and shows
  what it saw as an extra source card.
- The AI panel has a "Figures on this page" list with Re-read, Ask the cloud
  and Fix it (`presentation/sidebar/ai_figures_strip.dart`). A correction is
  pinned in the read cache and outranks later model reads.
- Equations are kept as LaTeX and tables as tables.
- Debug-only benchmark: Settings → Developer → "Figure benchmark (dev)".

On-device cost rules now in the code:

| Situation | On-device vision work |
| --- | --- |
| Background indexing (`economy: true`) | One figure call per page for everything drawn. No look at text-layer PDF pages, no LaTeX/table follow-up. |
| Page opened in the AI panel | At most two drawings read separately (`kLocalFigureRegions`), a look at a PDF page that mentions a figure, LaTeX/table follow-up. |
| A question about a figure | One look. |
| Cloud-first mode | None. The cloud reads up to four drawings per page. |
| Pictures on a page (photos, scans), any mode | At most 4 uncached pictures per read on the device (1 in background indexing, 12 on the cloud). Read pictures are cached and free. A memory-pressure signal ends the deep pass. |

Known limits of D2, none of them bugs:

- A drawing the model fails on does not appear in the Figures list; there is
  no "couldn't read this" card yet.
- A correction on a drawn figure is tied to how the drawing looks. Adding a
  stroke makes it a new figure.
- Corrections are stored in the AI read cache. Whether any "clear AI cache"
  action wipes them has not been checked.
- Between deep reads the Figures list keeps the last figures it knew, so an
  erased drawing can linger until Re-read or the panel is reopened.
- For a figure on a PDF page the whole page image is sent, not a crop.
- The keyword rule that decides which text-layer PDF pages get a figure look
  is a first cut.
- The two-drawing limit and the economy rules are choices, not measurements.

## 4. The device test (the user does this next)

Nothing below has been confirmed on the tablet.

1. **Build.** First Android build since the backup channel was written.
2. **Phase 0.** Open and close the AI panel at fit, zoomed in, and with the
   keyboard up: the writing must not jump and must return exactly. Import a
   photo and place it. Import a long PDF after page 2, then lasso ink on it
   without the page moving.
3. **Phase A.** Write with each of the four pens. Saved pens survive closing
   the note. Straighten a line. Two- and three-finger taps.
4. **Phase E.** Turn backup on, edit, check a `.margo` file appears in
   Downloads/Margo. Clear app data, restore.
5. **Phase D2.** On a page with a drawn diagram, a pasted chart, a
   handwritten equation and a table: open the AI panel and check the Figures
   list, try Re-read / Ask the cloud / Fix it, ask a question about a figure,
   and note how long each takes.
6. **Benchmark.** Needs about 40 test pages with `Q:` / `A:` text boxes, and
   the cloud gateway deployed for the cloud column. The gateway is still not
   deployed.
7. **Settings (new layout).** Open Settings on the tablet (two columns) and
   on a phone or a narrow window (one column). Check Backup, Pen and the
   AI Models screen (download a model, add the HuggingFace token) still work,
   in light and dark. Turn backup on and check the "How often" chips wrap.

### Schema change: page bookmarks (2026-11-15)

Approved by the user: three columns on `NotePage`: `bookmarked` (bool),
`title` (string), `templateOverride` (int, -1 = follow the notebook, else a
`TemplateType` index, append only). Existing rows read as the defaults. Set
through `PageRepository.setPageInfo` / `PageNotifier.setBookmarked`,
`toggleBookmarks`, `renamePage`, `setPageTemplate`; `templateForPage` resolves
the paper. Backups carry the fields (omitted when default, so an old backup
restores as defaults). Still needs a device check: an existing notebook opens
with the new columns.

### Schema change: page size (2026-11-14)

Approved by the user: one new column, `Notebook.pageSize` (`PageSizeKind`
index, append only). 0 = fit screen, the default every existing row reads, so
old notebooks keep the screen-shaped sheet latched in the editor
(`_screenSheet`); `createNotebook` gives new notebooks A4 portrait
(`PageSizeKind.newNotebookDefault`). Backups carry `pageSize` (missing = 0, so
an old backup restores as fit screen, not A4). `layoutMode` 2 = continuous: an
older build checks `== 1`, so it shows the notebook as infinite.

Continuous layout: the scene is still the current page's. The viewport lets
the view scroll one page plus `ViewportController.pageGap` above and below when
there are pages there (`setNeighbours`), the editor watches `pageAtMiddle()`
and steps the page with `shiftPage`, which moves the view by exactly one page
so nothing on screen jumps. `NeighbourPagesLayer` draws the pages either side
read-only. A touch on a neighbour only switches to it
(`SceneCanvas.onNeighbourTouched`). Writing that starts on the current page
and runs past its edge is clipped, as in single page.

### Schema change: revision tape (2026-11-14)

Approved by the user: `SceneElementKind.tape` appended (index 5) and one new
column, `SceneElementRecord.tapeRevealed`. Isar adds the column itself. An
older build reads a tape row as an empty freehand stroke (the generated
`kindValueEnumMap` falls back to `freehand`), and re-saving that page loses
the tape; the backup codec falls back the same way. So teammates must update
past this build. Peek is stored, but is not an undo step (`updateMany`, no
history). Device check still to do: opening an existing database with the new
column (the real-Isar tests are skipped on Windows).

## 4a. First device test results (2026-11-14)

Worked:

- First Android build, including the never-compiled backup channel.
- Pen latency feels natural; palm rejection works; two-finger tap undo.
- The canvas no longer moves when the keyboard opens.
- Backup: with it on, `Download/Margo` gets a `.margo` and a `.md` per
  notebook (checked through MediaStore). The folder appears only after the
  first run (leaving a note, or the chosen frequency).

Fixed already (`43ca580`): pens clashing (switching type kept the previous
type's size and colour; eraser shared the pen's size), pens too thick,
confusing pen icons, scribble-erase missing long strokes.

Fixed already, **not yet tried on the device** (findings 1 to 4 below):
one read gives the on-device vision model at most `kLocalImageReads` (4)
pictures per page, `kEconomyImageReads` (1) in background indexing,
`kCloudImageReads` (12) for the cloud; the rest get ML Kit text and are
counted in `PageContent.picturesReadLightly`. A read's deep pass ends on
Stop (`PageReadControl`) or when `ModelMemoryObserver.pressureCount` changes.
The panel shows picture progress, Stop and "Read more"
(`ContextEngineNotifier.readMore`, which must not vary the read or it would
skip the cache). Photo import asks past the limit (`PhotoLimitDialog`); PDF
import has "Read the text now". Finding 3 was partly a misreading: the
action buttons were never disabled, the screenshot was dimmed by a dialog.

Still to fix, in this order:

| # | Finding | Cause (as far as known) | Model |
| --- | --- | --- | --- |
| 1 | FIXED, needs device check. **AI reads a page of 23 imported photos for 10+ minutes, then Android kills Margo** (`LOW_MEMORY`, 1.1 GB, in the foreground). | The image loop in `PageContentExtractor._extractFrom` has no per-page limit: 1 to 3 on-device vision calls per image. Likely also a release/reload loop: `ModelMemoryObserver` releases the model on every memory-pressure signal and the next image reloads 2.6 GB. Not confirmed: the log rotated before it could be read. | Fable 5.2 |
| 2 | FIXED, needs device check. Importing many photos onto one page is allowed with no warning. | No cap. Same limit as #1; warn past it, offer "put the rest on new pages". | Fable 5.2, with #1 |
| 3 | FIXED (progress, Stop), needs device check. AI panel locked ("Reading your page…", all actions greyed) for the whole read. | Actions wait for the read. Needs progress, Cancel, and actions usable meanwhile. | Fable 5.2, with #1 |
| 4 | FIXED, needs device check. PDF import: user wants a choice between importing pages as they are and extracting the text. | Not offered. | Fable 5.2, with #1 |
| 5 | FIXED, needs device check. "Draw with finger" prompt has no clear way to turn it off. | The switch is only in Settings. | Sonnet 5.5 |
| 6 | FIXED, needs device check. Three-finger redo responds rarely. | Not investigated (likely the tap time window). | Sonnet 5.5 |
| 7 | FIXED, needs device check. Straighten fires when not wanted. | Always on, no setting, and the same 600 ms hold as Snap shapes (`ink_gestures.dart`, `scene_canvas_tools.dart` `_commitStroke`). | Sonnet 5.5 |
| 8 | FIXED, needs device check. Toolbar runs under the AI panel; the Text tool is half hidden. | The tool row does not adapt to the narrowed canvas. | Sonnet 5.5 |
| 9 | FIXED (unlock visible; real page sizes in step 10), needs device check. Imported PDF page sits small in the middle of the sheet and cannot be moved. | Locked on purpose (Phase 0), but the unlock is hidden, and the page is smaller than the sheet. | Sonnet 5.5 (unlock); Opus with Phase C (page size) |
| 10 | FIXED, needs device check. AI panel should float: draggable and resizable. | New feature. | Opus 5.5 |
| 11 | FIXED, needs device check. Text tool is a modal dialog over everything. | Phase B step 7 (inline text). | Opus 5.5 |

Later, by the user's choice: overall design direction (panel title cut to
"AI insigh…", an unlabelled switch beside it, crowded top bar), diagram
detection quality.

## 5. Remaining roadmap, with the model for each step

**Confirmed by the user 2026-11-13 as their working plan.** It replaces the
earlier assignment (Opus for B, C, E, F, H) to save usage. Project memory
(`project_margo_polish_roadmap.md`) now points here.

Rule: Sonnet 5.5 for work contained to a few files with a clear acceptance
check; Opus 5.5 for work that cuts across the editor or changes stored data;
Fable 5.2 only for figure-pipeline bugs.

| # | Step | Model |
| --- | --- | --- |
| 4 | Device-test bugs: pen, import, backup, first Android build | Sonnet, escalate a bug to Opus if Sonnet fails it once |
| 5 | Device-test bugs: figures, Ask, Figures list | Fable |
| 6 | B: true lasso, recolour and thickness, copy as image | Sonnet |
| 7 | B: inline on-canvas text editing | Opus |
| 8 | B: convert handwriting to text in place, straighten | Opus |
| 9 | DONE (`TapeElement`, column `tapeRevealed`, approved 2026-11-14). B: tape element (schema change, ask first) | Opus |
| 10 | DONE (`PageSizeKind`, column `Notebook.pageSize`, `layoutMode` 2, approved 2026-11-14). C: real page sizes, continuous vertical scroll | Opus |
| 11 | DONE (`PageManagerScreen`, route `/note2/:id/pages`, `PageNotifier.movePages/deletePages/duplicatePages`, shared `PageThumbnail`; no schema change). C: page manager grid, drag-reorder, multi-select | Sonnet |
| 12 | DONE (`NotePage.bookmarked/title/templateOverride`, approved 2026-11-15; `PageOutlineScreen`, route `/note2/:id/outline`). C: page bookmarks and outline, per-page template | Sonnet |
| 13 | DONE (`cornell`, `music`, `isometric`, `checklist` appended to `TemplateType`; no schema change). C: extra templates | Sonnet |
| 14 | DONE (`PageWords` sidecar `.words.json`, `PageWordsService` with ML Kit fallback, select tool Text mode, `TextSelectionBar`, `settings.snapHighlighter`; no schema change). D: PDF word boxes, text selection, highlighter snapping | Opus |
| 15 | DONE (`vector_pdf_writer.dart` in an isolate, `VectorPdfExport`, `TemplateSink`, Noto fonts in `assets/fonts/pdf`, invisible text over handwriting and page words, raster fallback; no schema change). D: vector PDF export with searchable text | Opus |
| 16 | DONE (`.links.json` sidecar, `linksFromPdf`, `PdfLinkLayer`, `findLinkTargetPage`, outline PDF contents, `SearchHighlightLayer`; no schema change). D: PDF outline and links, search hits on the page | Sonnet |
| 17 | DONE (dated snapshots pruned to five, `RestoreListScreen`, `BackupTarget.list/copyOut`; Kotlin not compiled; no schema change). E leftovers: restore list, last-five snapshots | Sonnet |
| 18 | PARTLY DONE: recents (`recent_notebooks.dart`), multi-select (`selection_bar.dart`), global search (`global_search.dart`) are in; covers (Notebook cover fields) and nested folders (Folder.parentId) are approved but held until the tablet check of the step 12 schema changes. F: nested folders, covers, multi-select, recents, global search | Sonnet, one item per session |
| 19 | F: onboarding, launcher shortcuts, keyboard shortcuts, accessibility | Sonnet |
| 20 | F: share-into-Margo, multi-window, drag-and-drop | Opus |
| 21 | F: audio ink replay, shared-element transitions | Opus |
| 22 | G: lasso → Explain/Solve/Flashcard, auto-summary, tape + quiz | Sonnet |
| 23 | G: handwriting spellcheck, maths step-checking | Opus |
| 24 | H: R8 with keep rules, APK size | Opus |
| 25 | H: font replacement, error-log export, golden tests, store text | Sonnet |
| 26 | AI tutor part 1: own-key cloud models, model picker, routing. **Code-complete on branch `ai-own-key-models` (2026-11-17), unmerged, not tablet-tested.** Plan, progress and open decisions: `docs/AI_TUTOR_PLAN.md`. Remaining: tablet check with a real key, and the decisions in its section 10 | Opus for changes to routing or consent; Sonnet for screens |
| 27 | AI tutor part 2: one teacher persona for every feature (draft text in the plan, section 5) | Opus |
| 28 | AI tutor part 4c: retrieval depth and answer length that follow the model and what the student asked for. The user's stated priority after part 1 | Opus |
| 29 | AI tutor part 3: Margo's own free, budget and premium tiers (gateway is not deployed) | Opus |
| 30 | AI tutor part 4: tutor conversation, citations, notebook guide (needs its own design session; saved chats are a schema change) | Opus |

Usage habits agreed in principle: one step per session, Sonnet steps run
back to back, Opus sessions kept to one item, device tests batched after B,
after C+D and after F+G.

## 6. How to start the next session

Say which step from section 5 to do. The session should then:

1. Read this file and the roadmap file.
2. Confirm it is on the model that step names, and stop if not.
3. Run `graphify query` for the area it is about to touch.
4. Summarise what it will do and wait for a go-ahead.
