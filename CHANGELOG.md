# Changelog

All notable changes to InkFlow are recorded here. The running app shows its
version on **Settings → About**, so you can confirm which build is installed on
any device.

Versioning: `MAJOR.MINOR.PATCH+BUILD`
- **MAJOR** – breaking changes / major reworks
- **MINOR** – new features, backwards compatible
- **PATCH** – bug fixes and small tweaks
- **BUILD** – auto-incremented on **every push to `main`** by the GitHub Actions
  workflow `.github/workflows/version-bump.yml` (runs on GitHub, so every
  collaborator gets it with no setup). A monotonic counter that never resets.
  Entries below are keyed by the semantic version; the exact `+BUILD` you see
  in-app is whatever commit you're on.

## [Unreleased]
### Added
- **Study planner.** A new planner icon in the notebook toolbar turns what the AI
  has learned about your notes into a day-by-day study plan. Pick a horizon
  (7 / 14 / 30 days, or an exam countdown) and it schedules the concepts you're
  struggling with, the ones due for review, and the ones your notes mention but
  never explain — spread sensibly across the days, with checkboxes to tick off
  each day and a progress bar. Built entirely on-device and instantly: no model
  download needed, because the schedule comes from your real progress data, not
  a language model guessing.
- **Knowledge graph.** A new graph icon in the notebook toolbar opens a concept
  map built automatically from your notes: each concept is a node coloured by
  how well you know it (learning → practiced → mastered), linked by the
  relationships the AI spotted while reading. Concepts your notes *mention but
  never actually explain* are ringed as "gap" nodes, so you can see what's
  missing at a glance. Pan and zoom to explore. Built entirely from analysis
  that was already happening — no extra waiting.
- **Ask your notes (on-device).** A new **Ask notes** button in the AI sidebar
  opens a question box: ask something in plain language and get an answer drawn
  *only* from your own notes across the whole notebook, with **source cards**
  showing the passages it used. If your notes don't cover it, it says so instead
  of making something up. Fully offline — one model retrieves the relevant
  passages, another answers from them.
- **Semantic search foundation (on-device RAG).** As you write, each page's text
  is quietly split into passages and embedded on-device with **EmbeddingGemma**,
  so *Ask your notes* can find the *relevant* passages across a whole notebook
  rather than keyword-matching. Everything is local: indexing runs in the
  background after your text settles (not on every keystroke), only re-embeds
  what actually changed, and never leaves the device.
  - Download the search model from **Settings → AI Models → EmbeddingGemma**.
    It's a gated Google model, so it needs the HuggingFace token you add just
    above it (accept the licence once, paste a read token). ~185 MB.

- **Cloud AI foundation (dev-only, not yet enabled).** A new, optional cloud
  tier for tasks the on-device model genuinely can't handle alone — nothing
  changes by default, and nothing is ever sent without an explicit prompt
  showing exactly what's about to leave the device. Explain is the first
  feature wired to it: a "Cloud" badge shows whenever an answer used it.
  Everything else (Summarize, Ask your notes, Quiz, Flashcards, live context)
  is unaffected and stays fully on-device. The gateway itself isn't deployed
  anywhere yet, so this has no visible effect until that happens.
- **Research (dev-only, not yet enabled).** A new **Research** button in the
  AI sidebar answers free-form questions that go beyond your notes — it can
  do arithmetic, look things up on Wikipedia, and search the web, showing
  which of those it used for each answer. Unlike *Ask your notes*, which
  only ever answers from your own writing, Research is explicitly for
  reaching outside it — so it always uses the cloud tier and always asks
  first, with the same "here's exactly what's about to be sent" prompt as
  Explain. Same as the cloud foundation above: has no visible effect until
  the gateway is actually deployed somewhere.

### Added
- **Import PDFs and photos into a notebook.** A new import button in the
  notebook toolbar takes a **PDF** — every page comes in as its own page, sized
  to fit and locked so you can write straight over it — or a **photo**, from
  your library or the camera, which asks whether you want it on the page you're
  on or on a page of its own. Re-importing the same PDF is instant and doesn't
  duplicate anything on disk.
- **Turn an imported page into editable text.** Select an imported PDF page or
  photo and tap **Extract text**: the words in it become real text boxes sitting
  where they were on the page, which you can select, edit and search like
  anything else you've typed. The picture stays behind them — so you can always
  check a misread against the original, and diagrams don't vanish — with a
  one-tap **Remove picture** if you only wanted the text. Runs entirely
  on-device, no network. One undo takes the whole extraction back.
- **Edit text you've already placed.** Select a text box and tap **Edit text**
  to change its words. Previously text could only be created, never corrected —
  you had to delete it and start again.

### Fixed
- **"Insert as note" dropped notes out of sight, on top of your work.** An
  inserted answer only avoided *other* inserted answers, so it could land over
  your own writing, and on a busy page it was placed below the visible area
  entirely — you had to zoom out to find it. It now lands in the first clear
  space inside the part of the page you're actually looking at, clear of
  everything already there, sized to read the same whether you insert at 14% or
  300%. When there's genuinely no room in view it says so instead of hiding the
  note somewhere off-screen.
- **The AI couldn't read your handwriting.** Every feature that works from page
  text — live insights, Ask notes, summaries, the knowledge graph — was getting
  nonsense back from handwritten pages. The whole page was being handed to the
  recogniser at once, in raw canvas coordinates, so it saw one enormous smear of
  marks rather than writing. It now reads your notes the way you wrote them: a
  line at a time, at a consistent size no matter what zoom you were at, with
  each line's underlines set aside, table columns read separately, and each
  piece given the words before it as context so it can tell what it's reading
  into.
- **AI insights suggesting gibberish to revisit.** "Worth revisiting" could fill
  up with fragments like "ge sin" or "ug ns" — misread handwriting quoted back
  at you as though it were a topic. The AI is now told the text comes from
  handwriting and to leave anything it can't read out of its answer entirely.
- **The page shrank when you opened AI insights.** On a single page, docking the
  panel beside the canvas cut the page down to the space left over, hiding the
  right-hand side of anything already written there. The page now keeps its
  size and simply scales to fit the narrower view — and back again when you
  close the panel. If you'd deliberately zoomed in, your zoom is left alone.
- **Handwriting recognition failing on Android.** A recent upstream update to
  the ML Kit digital-ink plugin broke recognition entirely on Android
  (affecting live context, RAG indexing, and anything else that reads page
  text). Pinned back to the last working release.
- **Explain sometimes described the question instead of answering it.**
  Asking to explain a short flagged term (rather than a full passage) could
  make the on-device model talk about the prompt itself instead of teaching
  the concept. Reworded the instructions so it stays focused on the subject.

## [2.0.0] - 2026-07-17
### Added
- **On-device AI study tools (private, offline).** A new AI sidebar in the
  editor, powered by an on-device model — no account, no network. After a
  one-time model download, everything runs locally:
  - **Live context** — reads the current page and surfaces its topic, key
    concepts, likely knowledge gaps, and difficulty as you write.
  - **Summarize** a selection, a page, or a whole notebook.
  - **Explain** any passage across a range of depths/styles, inserted back as a
    note.
  - **Writing assistant** — gentle grammar / clarity / repetition suggestions.
  - **Quiz generator** — gradeable multiple-choice, true/false and
    fill-in-the-blank questions (plus coding questions on programming pages).
  - **Flashcards** — a persistent deck built from a page, with a flip-through
    study view.
- **Flashcard export to Anki.** Export a deck as a ready-made **`.apkg`** (a
  named Anki deck that imports in one tap) or as **CSV** with import directives
  (named deck + automatic field mapping). Fully offline; `.apkg` degrades to CSV
  if the deck format is ever unavailable on a device.

## [1.1.0] - 2026-06-21
### Added
- **Canvas 2.0 — a ground-up rebuilt drawing engine (beta, opt-in).** Turn it
  on in **Settings → Editor → "Canvas 2.0 editor"** to open notebooks in the new
  engine; the classic editor stays the default and is unchanged. Built over a
  unified element model with near-Excalidraw drawing parity:
  - One model for ink, shapes, text, images and **frames**, with multi-select
    (marquee + 8 handles + rotate), grouping, alignment/distribution, snapping
    with guides, z-ordering, and lock.
  - Full shape styling: hachure / cross-hatch / solid fills, solid / dashed /
    dotted strokes, rounded edges, arrowheads, elbow arrows, and a
    hand-drawn "rough" look.
  - **Frames** — named containers that clip and move their contents together.
  - **Element library** — save a selection as a reusable item and drop it onto
    any page (persisted on-device).
  - **Export & share** to PNG, SVG and PDF (the selection or the whole page),
    and **copy/paste** elements across pages via the system clipboard.
  - Eraser (stroke and pixel), laser pointer, and full **undo/redo** across
    every edit.
  - A redesigned read-only **Book View** with swipeable spreads and a thumbnail
    filmstrip, on each notebook's paper colour.
- Real embedded images now render on the canvas and in exports.
### Changed
- Existing notebooks are migrated into the new unified storage on first launch.
  The migration is **non-destructive** — your original `.ink` files and page
  data are left untouched, so the classic editor keeps working exactly as before.

## [1.0.2] - 2026-06-16
### Fixed
- Palm rejection is now order-independent and far more consistent. Previously a
  touch was only ignored if the stylus was already down when it landed, so a
  palm resting *before* the pen (or lingering between strokes) slipped through
  and caused stray marks or unwanted pan/zoom. Now the pen retroactively drops
  any palm already on screen, a short grace window after each stroke ignores a
  settling/re-tapping palm, and a hovering stylus pre-arms rejection. Finger
  drawing and two-finger pan/zoom are unaffected when no stylus is in use.

## [1.0.1] - 2026-06-16
### Added
- Single-source version tracking: the app version now lives only in
  `pubspec.yaml` and is read at runtime via `package_info_plus`.
- Auto-incrementing build number via a GitHub Actions workflow, so the version
  bumps on every push for all collaborators with zero local setup.
- This `CHANGELOG.md` to track what ships in each version.
### Changed
- The About screen now displays the actual installed version and build number
  instead of a hardcoded string.

## [1.0.0] - baseline
- Infinite-canvas note taking with stroke rendering, shapes, and whiteboard
  (Excalidraw-style) tools.
- Book/notebook view, page templates, autosave, lasso transform.
- PDF rendering and import, image import, export & share.
