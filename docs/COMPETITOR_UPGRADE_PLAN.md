# Margo — upgrade plan from competitor teardown

**Status: proposed, not approved.** Written 2026-11-17. Nothing here is built.
It lists what Samsung Notes ships that Margo does not, and what is worth
bringing over without changing what Margo is: a calm, hand-drawn study
notebook with an on-device tutor.

## 1. What was analysed

| File in the repo root | What it really is | Result |
| --- | --- | --- |
| `Samsung+Notes_4.9.06.8_APKPure.apk` | `com.samsung.android.app.notes` 4.9.06.8, built against Android 11 (API 30) | Analysed |
| `uptodown-com.evernote.apk` | **Not Evernote.** It is the Uptodown App Store installer (`com.uptodown` 7.45). It contains no Evernote code or resources. | Nothing to analyse |

**Evernote is still owed.** A real Evernote APK (`com.evernote`) is needed; the
Uptodown file only downloads one when run on a phone. Section 7 lists what to
look at once it is here. Nothing in this plan is taken from Evernote.

**Method.** Static only; neither app was run. From the Samsung APK: the decoded
manifest, the default-language interface strings (2,341), the class and package
inventory of its 7 DEX files (311k methods), bundled assets and the 80 native
libraries. Method bodies were not decompiled: the REA skill's Android
decompiler needs a JADX component that is not installed on this machine, so
the Android SDK's own tools were used instead. That means this plan knows
**what** Samsung Notes does and how it is organised, and not the exact
algorithms inside each feature.

**Age of the build.** It targets API 30, so it predates Samsung's generative
"Note Assist" features. Its AI is limited to calls into system services
(key-phrase extraction, document category, entity extraction, speech-to-text)
plus title and tag suggestion. Margo is already well ahead here.

## 2. How Samsung Notes is built (observed)

- **The editor is native C++.** About 80 `libSPen*.so` libraries. Each pen is
  its own plug-in library: pencil (3 versions), marker (4), fountain, ink pen,
  calligraphy, oblique, crayon, brush, watercolour, oil, airbrush, smudge,
  "magic" pen, eraser. Separate libraries handle stroke prediction
  (`libSPenPredictor`, with a bundled TFLite runtime), handwriting
  straightening (`libSPenAlignment`), beautifying (`libSPenBeautify`), shape
  recognition (`libSPenRecognizerShape`, the largest recogniser), gesture
  recognition and an equation solver (`libSPenRecognizerSolver`).
- **PDF is a first-class page type**, with a 19 MB native PDF library, a
  separate PDF-only writer activity, password prompts and vector or raster
  export.
- **Search is fed by a background indexer** (`CollectService`). Separate
  collectors index handwriting, PDF text, objects in images, titles and tags,
  with a retry table for notes that failed. Handwriting hits are stored per
  stroke so matches can be highlighted on the ink.
- **Folders are a tree** stored with a closure table, with folder colours and
  a depth limit.
- **Audio is tied to ink** ("Note replay"): recorded audio plays back with the
  handwriting appearing in time.
- **Entry points everywhere**: three home-screen widgets, app shortcuts, a
  Quick Settings tile, "open with" for PDFs and documents, and web clipping
  from the browser.
- **Export is broad**: PDF, Word, PowerPoint, image, text. Word and PowerPoint
  cost them the whole Apache POI library (about 36k methods).
- **Sync and co-editing** run on Samsung Cloud, OneNote and a gRPC channel.

## 3. Where Margo stands

Already in Margo, so not in this plan: tags, pinning, bookmarks, page
duplicate/rename/move, 30-day trash with a countdown, three layout modes
(whiteboard, single page, continuous), 9 templates, hold-to-snap shapes and
lines, scribble-to-erase, pen presets, recent colours, handwriting to text,
document scanning, OCR, PDF import with links and a text layer, vector PDF
export, lecture recording with transcription, global search, backup.

Margo leads on: the AI tutor, flashcards with Anki export, quizzes, the
knowledge graph, the study planner, the hand-drawn shape engine (rough
rendering, bound arrows, frames, tape, laser).

Gaps found, by area:

| Area | Samsung Notes has | Margo today |
| --- | --- | --- |
| Getting things in | "Open with" for PDF/images/text, share into a new or existing note, many PDFs into one note or one each, password PDFs, web clip | No intent filters beyond the launcher |
| Audio | Ink replays in sync with audio; tap ink to jump; playback speed | Recording and transcript, not linked to ink |
| Pens | About 15 pen types, eyedropper, favourite-pen mini bar, restyle ink after writing | 4 pen kinds, presets |
| Eraser | Erase highlighter only, erase all handwriting, erase page | Stroke and pixel eraser |
| Writing aids | Straighten handwriting, zoomed "easy writing pad", write-to-text as you go, lock canvas, reading mode | Line straightening only |
| Smart ink | Phone, email, web address, date and maths in handwriting become tappable actions; "Solve" | ML Kit entity extraction is installed but only used for dates in the planner |
| Organising | Nested folders, folder colours, note lock, suggested titles and tags, "get organised" suggestion | Flat folders, no lock |
| Search | Recent searches, match highlight on the ink, background indexer with retry | Global text search |
| Pages | Page sorter grid, 15 templates plus your own image or PDF as a template, apply to all pages | Move left/right, 9 templates |
| Toolbar | User reorders and removes tools | Fixed |
| Outside the app | Widgets, app shortcuts, Quick Settings tile | None |
| Export | Word, PowerPoint, text | PDF and image |

## 4. The plan

Ordered by value to a student per unit of work. Each phase stands alone and
ends at the usual checkpoint (`flutter analyze` clean, tests green, tried on a
device).

### Phase 1 — Get material into Margo (small, high value)

1. **"Open with Margo" and "Share to Margo".** Add `VIEW` and `SEND`
   intent filters for PDF, images and plain text in
   `android/app/src/main/AndroidManifest.xml`, forward them through
   `MainActivity.kt`, and show one sheet: *Add to new note* / *Add to existing
   note*. The import itself already exists in `scene_import_service.dart` and
   `pdf_service.dart`.
2. **Several PDFs at once**: ask "one note or one note each".
3. **Password-protected PDFs**: prompt for the password instead of failing.
4. **Shared web links become a link card** (title and site name) on the page.
   Whole-page clipping is left out.

### Phase 2 — Audio that follows the ink (the best fit for Margo)

Stroke points already carry timestamps and recordings already exist. Store
each element's time offset into the recording that was running when it was
drawn, then:

1. Tap a stroke while a recording is loaded to jump the audio there.
2. During playback, dim ink that has not been "written yet".
3. Playback speed.
4. Margo-only addition: tapping a transcript line jumps to the ink written at
   that moment, and the tutor can cite "what you wrote while this was said".

Needs one additive field on `SceneElementRecord` (schema change: ask first).

### Phase 3 — Writing comfort

1. **Eraser modes**: highlighter only, all handwriting on page, clear page.
2. **Restyle after writing**: change colour and thickness of selected ink
   from `selection_bar.dart`.
3. **Eyedropper** in `universal_color_palette.dart`.
4. **Lock canvas** (one finger never pans; two fingers scroll) and **reading
   mode** (no tools, no accidental marks).
5. **Three more pens**, chosen to suit the hand-drawn look: flat marker,
   calligraphy (angled nib) and a tilt-shaded pencil. They go in
   `freehand_path.dart` beside the current four. The paint brushes
   (watercolour, oil, airbrush, smudge) are left out: they belong to a drawing
   app.
6. **Customisable toolbar**: reorder and hide tools in the bottom bar.
7. **Easy writing pad** for phones: a magnified strip at the bottom that
   writes at normal size on the page.
8. **Stroke prediction, as an experiment.** Samsung spends a whole library on
   it. Try a short extrapolation of the pen tip on `SceneActiveStrokeLayer`
   only, measure on a real stylus, keep it only if latency visibly improves.

### Phase 4 — Smart ink

1. **Action chips**: run the existing ML Kit entity extraction over recognised
   handwriting (`PageTextRecord`) and show a quiet chip next to a phone
   number, email, link or date. Dates offer "add to study plan".
2. **Solve**: lasso a handwritten sum or equation and get the answer written
   beside it, using the calculator tool and `flutter_math_fork` Margo already
   has. Offer "explain the steps" through the tutor, which Samsung cannot do.
3. **Suggested title and tags** for untitled notes, from the on-device model
   or the embeddings already computed. Suggest; never apply silently.
4. **Straighten handwriting**: level a selected line of writing using the
   word boxes in `word_geometry.dart`.

### Phase 5 — Organising and finding

1. **Nested folders and folder colours**: add `parentId` and `color` to
   `Folder`. A plain parent pointer is enough at Margo's scale; Samsung's
   closure table is not needed. Cap the depth.
2. **Note lock** with fingerprint or device PIN. Needs the `local_auth`
   package (new dependency: ask first). Locked notes stay out of search
   results, thumbnails and anything sent to cloud AI.
3. **Search**: recent searches, and highlight the match on the handwriting
   itself using the stored word positions.
4. **Indexing with retry**: record pages whose recognition failed and retry
   them later, so search does not silently miss pages.
5. **Page sorter**: a grid with multi-select and drag, replacing move
   left/right for long notebooks.

### Phase 6 — Outside the app

1. **App shortcuts** (long-press the icon): New note, Scan, Record lecture,
   Review due flashcards. A static `shortcuts.xml`; the cheapest item here.
2. **Quick Settings tile**: New note.
3. **Home-screen widgets**: a pinned note, and "cards due today". Kotlin
   `RemoteViews`, drawn in Margo's palette. The due-cards widget fits the
   Garden plan.

### Phase 7 — Pages and export

1. **Templates**: line, grid and dot in three spacings, weekly and monthly
   planner, and "use my own image or PDF page as the template", with "apply
   to all pages".
2. **Text export** (`.txt` / `.md`) from recognised handwriting and typed text.
3. **Word export**, later and only if asked for. A `.docx` is a zip of XML
   and `archive` is already a dependency, so a small writer is possible
   without anything like Apache POI. PowerPoint is left out.

## 5. Deliberately left out

- Cloud sync, OneNote sync and live co-editing: server work, and against
  Margo's on-device stance.
- Screen-off memo, Always On Display pin, Air actions, Bixby, DeX, "phone as
  toolbar": tied to Samsung hardware.
- Art brushes and PENUP posting.
- Apache POI for Office formats.

## 6. Design guardrails

- Every new control uses the existing sheets, the sage segmented control and
  the current icon set. No Samsung-style floating panels.
- New pens must look right beside rough-rendered shapes.
- Suggestions (titles, tags, action chips) are quiet and dismissible, and are
  computed on the device.
- Schema changes are additive, and each one is asked about first, as
  `ARCHITECTURE.md` requires.

## 7. When a real Evernote APK is supplied

Evernote is a typed-notes and capture product, so the questions are different:
the note editor's block types (tables, checklists, code, toggles), tasks and
reminders inside notes, the web clipper, document and business-card scanning,
note links and backlinks, templates, saved searches and search inside
attachments, and the home dashboard. Each would be checked against Margo the
same way as above.

## 8. Housekeeping

The two APKs (127 MB together) sit untracked in the repo root and are not
ignored. Do not commit them; move them out or add `*.apk` to `.gitignore`.
