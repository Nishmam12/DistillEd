# Margo — upgrade plan from competitor teardown

**Status: proposed; three decisions taken.** Written 2026-11-17. Nothing here
is built.

**Decisions (2026-11-17):**

- Note lock ships as **hide**, not encrypt; adding `local_auth` is approved for
  it.
- The additive schema changes in Phases 2, 3 and 6 are approved.
- Competitor package files stay out of git (`*.apk`, `*.xapk` ignored); the
  Uptodown installer was removed.
It lists what Samsung Notes and Evernote ship that Margo does not, how they
build it, and what is worth bringing over without changing what Margo is: a
calm, hand-drawn study notebook with an on-device tutor.

## 1. What was analysed

| File in the repo root | What it is | Result |
| --- | --- | --- |
| `Samsung+Notes_4.9.06.8_APKPure.apk` | `com.samsung.android.app.notes` 4.9.06.8, built against Android 11 (API 30) | Analysed |
| `Evernote+-+Note+Organizer_11.42.4_APKPure.xapk` | `com.evernote` 11.42.4, targets Android 16 (API 36); a base APK plus 19 split APKs | Analysed |
| `uptodown-com.evernote.apk` | **Not Evernote.** The Uptodown App Store installer (`com.uptodown` 7.45). | Ignored; can be deleted |

**Method.** Static only; neither app was run.

- **Samsung Notes** is a native Android app. Two passes: (1) the decoded
  manifest, 2,341 interface strings, the class inventory of 7 DEX files (311k
  methods), assets and 80 native libraries; (2) the code decompiled with JADX
  1.5.6 (17,546 classes; the 82 failures are all in bundled libraries), then
  the classes behind each feature read. The pen engine, recognisers, solver,
  stroke prediction and PDF renderer are native C++: for those the plan knows
  how the Java side drives them, not the algorithms inside.
- **Evernote** is a React Native app. Its logic is Hermes bytecode (v96) in
  `index.android.bundle` (126k functions) and a sync worker bundle (55k
  functions); JADX only sees the thin Android shell (12,037 classes, mostly
  libraries). The Hermes string tables were read with a small script that
  follows the published file format (245,518 strings). That yields every screen,
  setting, interface sentence and API name, but **not function bodies**: a
  Hermes decompiler was not installed (the install was blocked by a permission
  check). The editor, a plain-JavaScript web view (`assets/web/ce/ce.js`,
  12 MB), was read directly.

**Age.** The Samsung build predates its generative "Note Assist" features. The
Evernote build is current (late 2026) and leans heavily on cloud AI.

## 2. How the two apps are built

### Samsung Notes (observed in decompiled code)

- **Editor:** native C++, about 80 `libSPen*.so`; each pen is a plug-in
  library. Separate libraries for stroke prediction (with TFLite), handwriting
  alignment, shape recognition and equation solving.
- **Database:** Room/SQLite: notes, tags, auto-tags, a folder tree with a
  closure table, per-page search text, per-stroke search data, templates, and
  an indexing retry queue.
- **In and out:** share targets for text, images, audio and PDF (one or many),
  "open with" for PDF; export to PDF, Word, PowerPoint, image, text (Office via
  Apache POI). Sync through Samsung Cloud and OneNote.

| Feature | How Samsung does it | Source class |
| --- | --- | --- |
| Note replay | Each ink object stores a wall-clock time. Each recording keeps an event log: start (1), pause (2), resume (3), stop (4). Audio position = ink time − start − paused time. | `VoiceManager.getPlayingTime`, `requestSeekToByTimeStamp` |
| Search indexing | Durable queue `retry(sdocUUID, lastModifiedAt, state)`. Each run adds a "ready" row for every live note without one; one worker processes rows and marks them done; PDFs have their own state. Failures are retried; an edit makes a new row. | `ReadyStateCollectExecutor`, `RetryState`, `CollectWorker` |
| Suggested titles | Tracks changed pages; opening the title field jumps the queue for those pages, then takes the top 5 key phrases. Off in power saving. | `AutoTitleModel`, `TitleMiningExtractor` |
| Suggested tags | Top 10 key phrases, mined in the background, stored apart from the user's tags. | `TagMiningExtractor`, `NotesAutoTagEntity` |
| Action links | Entity extraction over handwriting and text: web address, email, map address, phone, date. | `HyperTextEntityExtractor` |
| Solve | Lasso, "Formula calculation"; native recogniser and solver; two error messages (no handwriting found; out of range). | `ContextMenuFormulaCalculation` |
| Folders | Closure-table tree; UI caps nesting at 5. | `FolderConstants.HOLDER_MAX_DEPTH` |
| Note lock | Real encryption: a password-derived key (PBKDF2-SHA1, 4,000 iterations) wrapped by an Android Keystore key; biometrics unlock it. Search skips locked notes. | `PasswordEncryptUtils`, `NotesSearchDAO` |
| Custom toolbar | Two JSON arrays of tool ids in preferences (shown, spare), with reset. | `HwToolbarOrderManager` |
| Stroke prediction | Only on an allow-list of tuned device models, with a user toggle. | `SpenLatencyConfiguration` |

### Evernote (observed in strings and the editor bundle)

- **Stack:** React Native on Hermes, with Reanimated, MMKV (key-value store),
  op-sqlite, PDFium, VisionCamera (scanning) and Sentry. The editor is
  **ProseMirror with Yjs** (real-time co-editing) inside a web view. Sync runs
  in a separate worker ("conduit"), talking GraphQL.
- **Editor blocks:** paragraphs, three heading sizes, lists, checklists,
  tasks and task groups, tables (with filter and border settings), toggles
  (collapsible sections), callouts, quotes, code blocks, **Mermaid diagrams**,
  formulas, rich link cards, embedded calendar events, contacts, maps, files,
  audio with **transcript segments and speaker names**, comments, encrypted
  text, and a floating table of contents.
- **Search:** keyword search runs on the device over SQLite FTS5 and includes
  text from attachments, scans and PDFs (`NewOfflineSearchIndicesMigration`,
  `AttachmentSearchTextOfflineSearch`). **Semantic search and "semantic
  answer" are server calls** (`semanticSearch()`, `generateSemanticAnswer()`).
  Semantic results are shown in their own section, labelled as matched by
  meaning, and can be switched off in settings.
- **AI:** reusable **AI Prompts** and **AI Playbooks** ("run a set of
  instructions on your notes, so you get the same result every time"), an AI
  Assistant chat, and an **AI memory** list the user can review, add to and
  delete from. Results names suggest OpenAI as the model provider.
- **Recordings:** record, then transcribe and summarise automatically (a
  setting); live transcript while recording; speaker recognition through
  **ElevenLabs**, behind its own consent screen; summary templates for
  transcripts (decisions, action items, next agenda, four-sentence recap).
- **Home:** a customisable dashboard: 10 widget kinds (Scratch Pad, Pinned
  Note, Notes, Recently Captured, Tasks, Calendar, Notebooks, Tags, Shortcuts,
  Filtered Notes), added, removed and reordered by the user, with reset.
- **Organising:** notebooks, stacks of notebooks, Spaces, nested tags with
  colours, saved searches, filter builder, note links with a **Backlinks**
  list, Daily Note created automatically from a template.
- **Tasks:** due dates, recurrence, flags, assignment, up to 5 default
  reminders, a calendar connection.
- **Import:** DOCX, HTML, TXT and Markdown become notes.
- **Annotation (Skitch):** arrows, shapes and blur over images and PDFs.

## 3. Where Margo stands

Already in Margo, so not in this plan: tags, pinning, bookmarks, page
duplicate/rename/move, 30-day trash, three layout modes, 9 templates,
hold-to-snap shapes and lines, scribble-to-erase, pen presets, recent colours,
handwriting to text, scanning, OCR, PDF import with links and a text layer,
vector PDF export, global search, backup, a page outline screen, and from the
selection bar: recolour and re-thicken ink, straighten handwriting, extract
text, copy as image, align, group, lock.

**Audio is further along than it first looked.** Strokes drawn while recording
already store `recordingId` and `audioOffsetMs` (`RecordingClock`), and the
selection bar has "Play from here".

**Search by meaning already exists, but only inside the tutor.**
`hybrid_search.dart` and the note-chunk embeddings are used for the tutor's
retrieval; the search screen does not use them.

Margo leads both apps on: an on-device tutor, flashcards and Anki export,
quizzes, the knowledge graph, the study planner, and a hand-drawn shape engine.
Evernote's semantic search and AI need its servers; Margo's run on the phone.

Confirmed gaps (each checked against the code):

| Area | Who has it | Margo today |
| --- | --- | --- |
| Share to / open with Margo | Both | No intent filters beyond the launcher |
| Import DOCX, HTML, TXT, Markdown | Evernote | PDF and images only |
| Pause while recording, ink replay, playback speed | Samsung | None of the three |
| Automatic summary after transcription, live transcript | Evernote | Transcript only, on request |
| Links between pages, backlinks | Evernote | None |
| Search by meaning in the search screen | Evernote (cloud) | Tutor only |
| Saved searches, filters, nested tags, tag colours | Evernote | None |
| Reusable AI prompts, editable AI memory | Evernote | Slash commands only control the app; memory is internal |
| Action links, Solve, suggested titles and tags | Samsung | Entity extraction only for planner dates |
| More pens, eyedropper, eraser modes, lock canvas, reading mode, custom toolbar | Samsung | None of these |
| Nested folders, folder colours, note lock | Both | Flat folders, no lock |
| Indexing with retry | Samsung | No retry |
| Customisable Home, scratch pad, reminders | Evernote | Fixed home, no reminders |
| Widgets, app shortcuts, Quick Settings tile | Both | None |
| Page sorter, own-image templates, text export | Samsung | Move left/right, 9 templates, PDF and image export |

## 4. The plan

Ordered by value to a student per unit of work. Each phase stands alone and
ends at the usual checkpoint (`flutter analyze` clean, tests green, tried on a
device).

### Phase 1 — Get material into Margo

1. **"Open with Margo" and "Share to Margo."** Register what Samsung does:
   `SEND` for `text/plain`, `image/*`, `application/pdf`; `SEND_MULTIPLE` for
   images and PDF; `VIEW` for PDF. Forward through `MainActivity.kt` to one
   sheet: *Add to new note* / *Add to existing note*. The import code already
   exists (`scene_import_service.dart`, `pdf_service.dart`).
2. **Several PDFs at once:** "one note or one note each".
3. **Password-protected PDFs:** ask for the password.
4. **Import TXT and Markdown** as typed text pages (Evernote). DOCX and HTML
   later: a DOCX is a zip of XML and `archive` is already a dependency.
5. **Shared web links become a link card** (title and site name).

### Phase 2 — Lectures: audio, ink and transcript together

1. **Pause and resume while recording.** `RecordingClock` stores only the
   start, so a pause would shift later strokes. Keep Samsung's pause/resume
   log and subtract paused time in `offsetFor`. Test first: draw, pause 10 s,
   resume, draw; the second offset must not include the 10 s.
2. **Note replay:** while playing, dim ink drawn after the playhead.
3. **Playback speed** (0.5×–2×) through `just_audio`.
4. **Transcript ↔ ink:** tap a transcript line to jump to the ink written then.
5. **Automatic study summary after transcription** (Evernote's "transcribe and
   summarise" setting, turned toward studying): key points, terms to know, and
   "make flashcards from this lecture", all from the on-device model. A setting,
   on by default only when the device can run the model.
6. **Live transcript** while recording, when the speech model is fast enough
   on the device. Speaker labels are left out: Evernote sends audio to
   ElevenLabs for them, and Margo keeps audio on the phone.

### Phase 3 — Connect and find

1. **Links between pages and backlinks.** Link a selection or a text element to
   another page or notebook; each page shows "Linked from" (Evernote's
   Backlinks). Store links as an additive field on the element; build backlinks
   with a query. The links also give the knowledge graph real edges.
2. **Search by meaning in the search screen.** Reuse `hybrid_search.dart` and
   the chunk embeddings the tutor already builds. Show meaning matches in their
   own section, labelled, below exact matches, as Evernote does, with a setting
   to hide them. Unlike Evernote, this runs on the device and works offline.
3. **Filters and saved searches:** by notebook, folder, tag, date, "has
   handwriting", "has recording"; save a filter by name.
4. **Nested tags and tag colours** (Evernote's parent tags).
5. **Recent searches**, and highlight the match on the handwriting itself.
6. **Indexing with retry** (Samsung's design): a small Isar collection
   `(notebookId, pageId, modifiedAt, state)`, filled at launch for pages
   without a row, drained by one worker, rows marked done. Stops search and the
   tutor from silently missing pages.

### Phase 4 — Smart ink and reusable AI

1. **Action chips** on recognised handwriting for web address, email, address,
   phone and date (Samsung's set; ML Kit entity extraction is already a
   dependency). Dates offer "add to study plan".
2. **Solve:** lasso a handwritten sum and write the answer beside it, using
   the calculator tool and `flutter_math_fork`; reuse Samsung's two error
   messages; add "explain the steps" through the tutor.
3. **Suggested title and tags** (Samsung's pattern): changed pages only, titles
   when the title field opens (top 5), tags in the background (top 10), skipped
   in battery saver, suggested tags kept apart until accepted.
4. **Study recipes** (Evernote's Prompts and Playbooks): saved, named
   instructions run on a page, a notebook or a lecture, e.g. "Cornell summary",
   "10 flashcards", "explain like I'm new to this". Ship a few built in; let
   people save their own from the tutor panel. Run as `/recipe-name`.
5. **"What the tutor knows about you":** a screen to review, add and delete
   the learning memories and preferences the tutor already keeps (Evernote's
   AI memory screen).

### Phase 5 — Writing comfort

1. **Eraser modes:** highlighter only, all handwriting on the page, clear page.
2. **Eyedropper** in `universal_color_palette.dart`.
3. **Lock canvas** (one finger never pans) and **reading mode** (no tools).
4. **Three more pens** that suit the hand-drawn look: flat marker, calligraphy,
   tilt-shaded pencil, in `freehand_path.dart`.
5. **Customisable toolbar,** stored as Samsung does: two JSON lists of tool ids
   in `shared_preferences`, with reset; unknown ids dropped on read.
6. **Easy writing pad** for phones.
7. **Stroke prediction, as an experiment:** off by default, behind a setting,
   measured on a real stylus first.

### Phase 6 — Organising and privacy

1. **Nested folders and folder colours:** `parentId` and `color` on `Folder`;
   cap nesting at 5.
2. **Note lock — hide (decided).** Uses `local_auth` (approved). Fingerprint
   or device PIN to open; locked notes left out of search, thumbnails, the
   tutor and cloud calls; called "hidden", not "encrypted", everywhere in the
   interface. Encryption (Samsung's approach) stays a possible later step; if
   it ever happens, use a stronger key derivation than Samsung's 4,000
   iterations.
3. **Page sorter:** a grid with multi-select and drag.

### Phase 7 — Home and outside the app

1. **A "Today" strip on Home,** using Evernote's widget idea but fixed and
   calm rather than a full dashboard builder: cards due, today's study-plan
   item, last-opened notebook, and a scratch pad. Each can be hidden.
2. **Reminders:** a notification for cards due and for study-plan days, using
   dates Margo already has.
3. **App shortcuts:** New note, Scan, Record lecture, Review cards (a static
   `shortcuts.xml`).
4. **Quick Settings tile:** New note.
5. **Home-screen widgets:** a pinned note and "cards due today", in Margo's
   palette. The due-cards widget fits the Garden plan.

### Phase 8 — Pages and export

1. **Templates:** line, grid and dot in three spacings, weekly and monthly
   planner, own image or PDF page as a template, "apply to all pages", and an
   optional **daily study page** created from a chosen template (Evernote's
   Daily Note).
2. **Text and Markdown export** from recognised handwriting and typed text.
3. **Word export**, only if asked for, written directly with `archive`.

## 5. Deliberately left out

- Cloud sync, live co-editing (Evernote's Yjs, Samsung's gRPC) and sharing:
  server work, and against Margo's on-device stance.
- Server-side semantic search and answers: Margo does both on the device.
- Speaker recognition through a third party (Evernote uses ElevenLabs).
- Evernote's typed-document editor blocks (toggles, callouts, code, Mermaid,
  tables): Margo is a handwriting canvas, not a block editor. Typed text pages
  from Phase 1 cover imports.
- Tasks with assignment and recurrence, Spaces, calendar sync: team and
  productivity features beyond a study notebook.
- Samsung hardware features (screen-off memo, Air actions, Bixby, DeX, phone
  as toolbar), art brushes, Apache POI.

## 6. Design guardrails

- New controls use the existing sheets, the sage segmented control and the
  current icon set. No floating Samsung panels, no Evernote dashboard builder.
- New pens must look right beside rough-rendered shapes.
- Suggestions (titles, tags, chips, summaries) are quiet, dismissible and
  computed on the device.
- Anything sent off the device follows the existing cloud privacy and
  confirmation settings.
- Schema changes are additive. The ones in Phases 2, 3 and 6 are approved;
  any other still needs asking first, as `ARCHITECTURE.md` requires.

## 7. Housekeeping

- The package files are ignored by git (`*.apk`, `*.xapk` in `.gitignore`)
  and stay local. The Uptodown installer has been removed.
- JADX 1.5.6 is installed at `~/.local/share/jadx` (linked as
  `~/.local/bin/jadx`). Decompiled output was kept in a temporary folder that
  will be cleared. To look again:
  `JAVA_OPTS=-Xmx12g jadx -r -d <out> <file>.apk` (a couple of minutes each).
  For Evernote, unzip the `.xapk` first and use `com.evernote.apk`; its real
  logic is in `assets/index.android.bundle` (Hermes bytecode), which needs a
  Hermes decompiler such as `hermes-dec` to read beyond its strings.
