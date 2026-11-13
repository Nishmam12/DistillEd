# Margo polish roadmap: handover

Written 2026-11-13 for the next chat session picking this work up. Read this
first, then `CLAUDE.md`, then the roadmap file named below. Everything here was
true at the commit that added this file.

## 1. Where things stand

| Item | State |
| --- | --- |
| App | Margo, Flutter, Android only. `pubspec.yaml` version `5.0.0+30`. |
| Branch | `margo-backup-figures`, cut from `margo-next`, **pushed to `origin` (DistillEd)**. Version `5.1.0+31`. |
| Roadmap | `C:\Users\nabil\.claude\plans\go-through-the-entire-humble-gem.md` (approved 2026-11-11). Order: 0 → A → E1/E2 → D2 → B → C → D → F → G → H. |
| Done in code | Phase 0, Phase A, Phase E1/E2, Phase D2. |
| Next | The user's device test, then Phase B. |
| `flutter analyze` | Clean. |
| `flutter test` | 2,907 pass, 44 skipped. `test/core/error_log_test.dart` ("once past 100 KB…") fails in some full runs and passes alone. It is flaky under load and unrelated to this work. |
| On-device testing | **None since pen phase 1.** Phases 0, A, E and D2 have only ever run in unit and widget tests. |

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
- **Not done:** keeping the last five snapshots, a restore list screen,
  offering restore on first launch or after a failed database open.
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

## 5. Remaining roadmap, with the model for each step

**Proposed 2026-11-13, not yet confirmed by the user.** It replaces the
earlier assignment (Opus for B, C, E, F, H) to save usage. Project memory
still holds the earlier one; update `project_margo_polish_roadmap.md` once
the user agrees.

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
| 9 | B: tape element (schema change, ask first) | Opus |
| 10 | C: real page sizes, continuous vertical scroll | Opus |
| 11 | C: page manager grid, drag-reorder, multi-select | Sonnet |
| 12 | C: page bookmarks and outline, per-page template | Sonnet |
| 13 | C: extra templates | Sonnet |
| 14 | D: PDF word boxes, text selection, highlighter snapping | Opus |
| 15 | D: vector PDF export with searchable text | Opus |
| 16 | D: PDF outline and links, search hits on the page | Sonnet |
| 17 | E leftovers: restore list, last-five snapshots | Sonnet |
| 18 | F: nested folders, covers, multi-select, recents, global search | Sonnet, one item per session |
| 19 | F: onboarding, launcher shortcuts, keyboard shortcuts, accessibility | Sonnet |
| 20 | F: share-into-Margo, multi-window, drag-and-drop | Opus |
| 21 | F: audio ink replay, shared-element transitions | Opus |
| 22 | G: lasso → Explain/Solve/Flashcard, auto-summary, tape + quiz | Sonnet |
| 23 | G: handwriting spellcheck, maths step-checking | Opus |
| 24 | H: R8 with keep rules, APK size | Opus |
| 25 | H: font replacement, error-log export, golden tests, store text | Sonnet |

Usage habits agreed in principle: one step per session, Sonnet steps run
back to back, Opus sessions kept to one item, device tests batched after B,
after C+D and after F+G.

## 6. How to start the next session

Say which step from section 5 to do. The session should then:

1. Read this file and the roadmap file.
2. Confirm it is on the model that step names, and stop if not.
3. Run `graphify query` for the area it is about to touch.
4. Summarise what it will do and wait for a go-ahead.
