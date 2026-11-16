# Changelog

All notable changes to Margo are recorded here. The running app shows its
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
- **Backups keep the last five snapshots of each notebook, and you can pick
  which to restore.** Each backup that finds a change is saved as a new dated
  `.margo` file (for example `Biology (3) 2026-11-16 1601.margo`), and the
  sixth oldest is removed. "Back up now" on a notebook that has not changed
  adds nothing. The readable `.md` copy stays a single latest file. Settings →
  Backup → "Restore from a backup…" now opens a list of the backups, grouped
  by notebook, newest first; tap one to bring it back as a new notebook
  (nothing is overwritten). After a reinstall Android may hide earlier
  backups from the app, so "Pick a file instead…" is still there. Five
  snapshots of a notebook with many PDF pages take about five times the space
  in Downloads.
- **A PDF's contents and links come with it.** When a PDF is imported, its
  table of contents and the links on its pages are kept. The Outline now starts
  with "PDF contents", indented as the PDF has it; tap an entry to open that
  page. With the hand tool (or the select tool's Text mode) the links on a page
  are underlined and tapping one follows it: a link to another page opens that
  page, and a web link asks "Open this link?" and shows the address first. Only
  web (http and https) addresses are ever opened. A link to a PDF page you did
  not import says so. A resting palm is not taken for a tap. PDFs imported
  before this version have no contents or links (the PDF itself is not kept),
  but re-importing one adds them. Pages the PDF has turned (a "rotate" setting)
  have no links, and their words are read off the picture instead of the PDF.
- **Search hits are marked on the page.** Open a result from Find in notebook,
  or from Search on a text selection, and the words it found on a PDF page or
  photo are tinted, with a "3 matches on this page" chip that clears the tint.
  The tint goes when you leave the page. Handwriting and typed text hits still
  jump to the page but are not tinted.
- Links and contents are kept in a small file beside each page picture
  (`.links.json`), carried in backups. No database change, no new dependency.

### Changed
- **PDF export is now a real vector PDF with searchable text.** Ink, shapes and
  the paper pattern are drawn as vector lines, so the PDF stays sharp at any
  zoom and is much smaller than pictures of the pages. Typed text is real text
  you can search and copy. The words of imported PDF pages and photos (where
  Margo has kept them, see 5.4.0) are laid invisibly over the page, so they can
  be searched too. Pictures are embedded from their original files.
- Exporting a notebook first asks whether to **include searchable
  handwriting**: the writing is read on this device and laid invisibly over
  each line, so a search finds handwritten words. On by default and
  remembered; turn it off for a quicker export.
- A notebook laid out on real paper exports at that size (A4 is 595 x 842 pt).
- Sharing a selection as PDF is vector too.
- Known limits: the pencil's grain and the hand-drawn look of shapes are drawn
  clean; Bangla typed text is embedded as a sharp picture of the text box
  (the PDF fonts cannot join Bangla letters) with its text searchable over it.
  If the vector PDF cannot be made, the export falls back to pictures of the
  pages and says so.
- Fonts embedded in PDFs: Noto Sans and Noto Sans Bengali (SIL Open Font
  Licence), only the letters each PDF uses. No new package, no database change.

## [5.4.0] - 2026-11-15
### Added
- **Page manager.** A full-screen grid of every page, opened from the grid
  button in the editor's page bar or the Book view's app bar. Long-press a page
  and drag it to a new place; "Select" lets you pick several pages to
  duplicate, move to the start or end, or delete (it asks first, and the last
  page can't be deleted). Thumbnails use the notebook's real page shape, and
  tapping one opens it.
- **Bookmarks, page names and an outline.** Bookmark or name a page from its
  menu (or bookmark several in the page manager). The page manager shows a
  bookmark badge and the name, and can show bookmarked pages only. The outline
  lists the bookmarked or named pages; tap one to open it.
- **A paper template for one page.** In the page sheet, "This page only" gives
  the current page its own template; "Whole notebook" changes the notebook's
  and puts the page back to following it. Duplicating a page keeps all three.
- **Four more paper templates:** Cornell (cue column, notes area and summary
  band), Music (staves), Isometric (a triangular dot grid) and Checklist (ruled
  lines with a tick box on each). On the infinite canvas Cornell shows as ruled
  paper with a margin, since it needs a page's edges.
- **Select the text on a PDF page or a photo.** The select tool has a third
  mode, Text: drag across the printed words to select them, then Copy them,
  Highlight them (a clean mark over exactly those words, in your highlighter's
  colour), Ask the AI about them, or Search the notebook for them.
- **The highlighter snaps to printed text.** Highlight over the words of a PDF
  page or a photo and the stroke becomes a straight mark over just those words.
  Undo brings your stroke back. Settings: "Snap highlighter to text" (on by
  default).
- Where each word sits is kept beside the page picture (`.words.json`): from the
  PDF's own text at import, or read once on the device the first time you select
  or highlight on a page without it (a scan, a photo, or an older PDF).
  Re-importing an older PDF adds its words without rendering it again.

### Changed
- **Database: three new columns on NotePage** (approved 2026-11-15):
  `bookmarked` (false), `title` (empty) and `templateOverride` (-1 = follow the
  notebook). Existing pages read as the defaults; an older build ignores the
  columns. Backups carry them, and an older backup restores as the defaults.
- Templates and word positions need no other database change: templates are
  stored by number, and word positions live in a file beside each page picture.

### Fixed
- **Android build tools raised** so Flutter 3.50.0 builds again: Gradle 9.1.0
  to 9.3.1, and Android Gradle Plugin 9.0.1 to 9.1.1. The first build downloads
  them.
- **Cloud error messages are readable.** A cloud 404 says "Cloud gateway
  unreachable"; other statuses say "Cloud request failed (HTTP …)".
- **Flashcard and Quiz loading panels** span the full width of the screen, like
  the other AI panels.

## [5.3.0] - 2026-11-14
### Changed
- **Database: one new column on Notebook, `pageSize`** (approved 2026-11-14).
  0 means "fit screen", which every existing notebook keeps; new notebooks
  start at A4. Isar adds the column on its own; an older build ignores it and
  lays the notebook out at fit screen. Nothing is lost either way.
- `layoutMode` gains the value 2 (continuous). An older build shows such a
  notebook as the infinite canvas.

### Added
- **Real page sizes.** A4, Letter and 16:10, portrait or landscape, or Fit
  screen (today's screen-shaped page), chosen under Layout in the page sheet.
  A page is the same shape on every device, and imported PDF pages now fill it
  instead of sitting small in the middle. Changing the size leaves the writing
  where it is.
- **Continuous layout.** Pages stacked top to bottom, the page width filling
  the window, scrolled through like a document. The page in the middle of the
  window is the one being written on, and the view does not jump when it
  changes; touching the page above or below makes it current. Page size and
  layout are saved in backups.

## [5.2.0] - 2026-11-14
### Changed
- **Database: one new column, one new element kind** (approved 2026-11-14).
  `SceneElementRecord` gains `tapeRevealed` and `SceneElementKind` gains
  `tape` (appended, index 5). Isar adds the column on its own; no migration.
  **Everyone should update to this build:** an older build reads tape as an
  empty pen stroke, shows nothing there, and if it saves that page the tape is
  lost for good. Restoring a backup on an older build does the same.

### Added
- **Revision tape.** A Tape tool in the tool row: drag over notes to cover
  them with an opaque strip (five colours; a quick stroke along a line still
  lays a usable strip). Tap tape to peek underneath and tap again to cover it;
  Peek / Cover in the selection bar does the same for selected tape. Whether
  tape is lifted is remembered with the page; peeking is not an undo step.
  Tape moves, resizes, recolours, deletes and undoes like anything else, is
  saved in backups, and exports as it is shown. The AI still reads what is
  under it.
- **Convert handwriting to text in place.** Select ink and tap Convert to
  text: it is read line by line on the device (ML Kit, no network), shown for
  checking with doubtful lines marked, then each line becomes a text box where
  it was written, in its ink colour. Lines left empty stay as handwriting;
  "Keep the handwriting" leaves the ink under the text. One undo step.
- **Straighten handwriting.** Levels each line of selected writing that was
  written on a slant (1.5 to 30 degrees), about its own centre. One undo step.
- **Lasso select.** With the select tool, pick Lasso (beside Rectangle) and
  draw a loop round things: ink, shapes and text mostly inside it are selected,
  and a loop that only clips an edge takes nothing.
- **Colour and thickness of a selection.** The selection bar recolours ink,
  shapes and text and sets the line thickness of ink and shapes (Fine to Very
  thick); each is one undo step.
- **Copy as image.** Renders the selection to a PNG with a transparent
  background and opens the share sheet, whose Copy, Save and Send put it where
  it is wanted.

## [5.1.2] - 2026-11-14
### Fixed
- Three-finger redo registers reliably: three fingers get a longer, looser tap
  window than two (500 ms and 26 px, against 300 ms and 12 px).
- The tool row shows a scrollbar and packs tighter when the AI panel narrows
  the editor, so no tool is left half off the edge.
- **A page full of photos no longer hangs the AI or gets the app killed.**
  One read gives the on-device model at most 4 pictures per page (1 in
  background indexing, 12 when the cloud reads); the rest are read for their
  text and picked up by **Read more**. The first device test read 23 photos
  on one page for over ten minutes until Android killed the app for memory.
- A read stops asking for the model when Android reports memory pressure,
  instead of reloading it for every remaining picture.

### Added
- **Type text straight onto the page.** The Text tool opens a field where you
  tap, at the page's zoom and in the text's own font, size and colour, with a
  small strip for bold, italic, alignment, ticking checklist items and Done.
  Touching the page elsewhere, changing tool, switching page or closing the
  note keeps the text; Escape throws it away. Double-tap a text with the lasso,
  or use Edit text, to type into it where it is; clearing it deletes it. The
  page scrolls up to keep the text above the keyboard, and back afterwards.
  Each add, edit or delete is one undo step. Replaces the Add text / Edit text
  dialog.
- **The AI panel floats over the page** on tablets: drag it by its header,
  resize it from the bottom-right corner, and it remembers where it was left.
  The page keeps its full size underneath, and the panel lifts above the
  keyboard and goes back when it closes. The header's dock button puts it back
  beside the page, as before.
- A **finger-draw switch** in the editor tool row (same setting as Settings >
  Pen), so a pen user can stop a finger drawing without leaving the page.
- **Straighten lines** is its own setting in Settings > Pen, off by default. It
  used to be always on and fired when it was not wanted.
- A locked PDF page now shows **Unlock to move** when selected, and dragging it
  with the lasso says how to move it.
- The AI panel shows "Reading picture 2 of 4" with a **Stop** button, and
  says how many pictures were left for later.
- Importing photos that would put more than 4 pictures on a page asks first,
  and offers a page each.
- PDF import has a **Read the text now** switch: off imports the pages as
  they are and reads each when it is opened.

## [5.1.1] - 2026-11-14
### Changed
- **Pens are one clear system.** Each pen type (ballpoint, fountain, pencil,
  highlighter) keeps its own colour and size: switching type brings it back
  as it was last used instead of carrying the previous type's size and colour
  across. The pen button shows the type in use with a dot of its colour;
  saved pens are colour dots in their own strip.
- **Thinner pens.** New defaults: ballpoint 2, fountain 2.5, pencil 2,
  highlighter 14. Pens left on the old defaults move to the new ones.
- The eraser and shapes have their own size, separate from the pen.
- **Settings redesign** (merged from `SettingsUI-upgrade`): two columns of
  icon cards on tablets, one column on phones; AI models and the HuggingFace
  token move to their own **Settings → AI Models** screen. Backup is now its
  own card, and "Draw with finger" sits in the Pen card.

### Fixed
- Settings no longer overflows on narrow phones at large text sizes: option
  chips (handwriting language, export format, backup frequency) wrap onto a
  second line. "How often" for backup is now a row of chips, not a dropdown.
- Scribble-to-erase now erases long and L-shaped strokes whose ink it covers;
  it used to judge a stroke by its bounding box.
- A wide eraser no longer leaves the pen thick afterwards.

## [5.1.0] - 2026-11-13
### Added
- **Automatic notebook backup.** Settings → Backup switches on automatic
  backup to Downloads/Margo, at a chosen frequency, with "Back up now" and a
  status row. Notebooks are also exported and restored as `.margo` files
  (**Share notebook (.margo)** in the editor menu). Backups survive an
  uninstall. The Android side has not yet been compiled on a device.
- **Garden plan (proposal only).** `docs/GARDEN_PLAN.md` sets out a calm,
  study-driven garden as a later phase. Nothing is built.
- **Figure benchmark (developer only).** Settings → Developer → Figure
  benchmark measures figure understanding on test notebooks.

### Changed
- **The AI reads each figure on its own.** A page used to be shown to the AI
  as one picture, so a small diagram on a full page was a blur and two
  diagrams came back as one confused description. Margo now finds each
  drawing on the page, shows the AI just that drawing, and remembers where on
  the page it is. Writing next to a drawing (its caption) is given to the AI
  as context.
- **The AI looks at the figure when you ask about it.** Ask used to answer
  from the short description made when the page was first read, so a question
  that description had not thought of ("what is the value at x = 3?", "which
  arrow leaves B?") could not be answered. When a question is about a figure,
  Margo now shows the figure itself to the vision model together with your
  question, and the answer draws on what it sees. The Sources list shows what
  was seen. It runs on the device; a figure is sent to the cloud only under
  the same setting as other page images.
- **Figures on this page.** The AI panel now lists every chart, diagram and
  picture it read on the page: a thumbnail, what it understood, whether it was
  read on the device, by the cloud or exactly from shapes, and a "Not
  confirmed" mark when the labels in the reading were not found on the page.
  Each one can be read again, sent to the cloud model (when cloud AI is on),
  or fixed by writing what it shows yourself. Your description replaces the
  AI's and is what summaries, answers and quizzes use from then on.
- **Maths and tables are kept as maths and tables.** When the AI finds an
  equation it now also writes it out as LaTeX, and when it finds a table it
  keeps the rows and columns, so a question about one term or one cell has
  something exact to answer from. The Figures list shows the equation drawn
  as maths and the table as a grid.
- **Figure reading is kept light on the device.** The on-device model reads
  at most two separate drawings per page one by one (more are read together),
  and when a whole notebook is indexed in the background it does the minimum:
  one figure read per page, no extra look at PDF slides, no LaTeX or table
  follow-up. The rest happens when you open the page in the AI panel or ask
  about the figure. With cloud-first reading on, the cloud does the full job
  and the device does none of it.
- **Flowcharts made with the shape tools are read exactly.** Boxes with typed
  labels joined by arrows are read straight from the shapes — every label and
  every arrow, with no AI model involved, so it is instant, works without the
  model downloaded, and cannot misread.
- **Charts on PDF slides are no longer skipped.** A PDF page whose text Margo
  already had was never looked at for figures. Pages that mention one
  ("Figure 2", "the graph shows") now are.
- **A confident wrong reading is caught.** What the AI says a figure shows is
  checked against the labels Margo can read another way (typed text, the
  PDF's own text, handwriting recognition). A reading that names things which
  are not there is sent to the stronger model when you have allowed the
  cloud, and otherwise kept but marked as unconfirmed.
- **Opening the AI panel keeps your page as it was.** The same writing stays
  on screen, just narrower, instead of the page jumping to 100 % or staying
  zoomed in with half of it cut off. Closing the panel puts the view back
  exactly. The keyboard no longer shrinks the page while you type in the panel.
- **Drag the AI panel's left edge to make it wider or narrower.** Margo
  remembers the width.
- **Pictures arrive ready to place.** A photo lands in a clear part of the page,
  selected, so the next drag moves it and a corner resizes it. A bar offers
  Done, Own page (for a whiteboard shot to write over) and Remove, and your pen
  comes back when you finish. The "Where should it go?" question is gone, and
  you can pick several photos at once.
- **PDF pages stay put.** Imported PDF pages, scans and photos given their own
  page are locked, so the Select tool picks up the ink on them instead of
  sliding the page away. Tap a bare part of the page to select it, then Unlock
  it to move it.
- **Choose what to import from a PDF.** Pick a page range and whether the pages
  go after the page you're on or at the end. Progress is shown page by page,
  and you can cancel.

### Added
- **Automatic backup** (Settings → Backup). Switch it on and Margo saves every
  notebook that changed to **Download/Margo**: a `.margo` file you can restore,
  and a readable `.md` copy of the text. Pick how often: after each note,
  hourly, daily or weekly. **Back up now** runs it at once, and the screen
  shows when it last ran, where it went, and any error. These files survive
  uninstalling the app.
- **Restore from a backup** (Settings → Backup). Pick one or more `.margo`
  files; each comes back as a new notebook. Nothing is overwritten.
- **Share notebook (.margo)** in the editor's ⋯ menu sends a whole notebook,
  with its pictures and PDF pages, to another Margo.
- **Four pens.** The pen panel now offers a pen, a fountain pen (strong
  thick-thin), a pencil (grainy graphite) and a highlighter (wide and
  see-through, so the writing under it stays readable). Each stroke remembers
  which pen drew it; existing ink stays as it was. The laser pointer has its
  own icon.
- **Saved pens on the toolbar.** Next to the pen tool: tap one to write with
  it, long-press to replace or remove it, **+** to save the pen you're using
  (up to five). You start with a pen, a blue fountain pen, a pencil and a
  yellow highlighter.
- **Margo remembers your pen.** A note opens with the pen, colour and size you
  last used.
- **Any colour.** **Custom…** in the colour palette opens hue, colour and
  brightness sliders and a hex field. Colours you pick there are kept under
  **Recent**.
- **Hold to straighten.** Draw a line and hold the pen still at the end: it
  snaps straight. One undo brings back the line as drawn.
- **Tap with two fingers to undo, three to redo.** A small vibration confirms
  it, and confirms a straightened line or snapped shape too.
- **Draw with finger** (Settings → Pen). Turn it off and one finger scrolls the
  page while only the pen draws. The first time you write with a pen, Margo
  offers to turn it off for you.

## [5.0.0] - 2026-10-24
### Changed
- **Search runs on EmbeddingGemma 2.** Ask your notes now uses Google's
  EmbeddingGemma 2 (text only, ~165 MB) instead of EmbeddingGemma 300M. It is
  free to download with no Hugging Face account or token. If you already had
  notes indexed, the app downloads the new model and re-indexes them in the
  background; questions keep working on the old index until it finishes, and
  then the old model's files are removed. Notebook titles now go into the slot
  the model was trained with, and a passage too long for the model is shortened
  instead of failing. Expect slightly more memory use while searching.
- **On-device AI packages updated** to `flutter_edge_ai` 2.5.2,
  `flutter_edge_ai_litertlm` 1.17.0, `flutter_edge_ai_embeddings` 2.3.2 and
  `flutter_edge_ai_speech` 0.5.10. The debug-only rollout dry run in Settings is
  gone; the real switch to EmbeddingGemma 2 replaces it.
- **The app is now called Margo.** The launcher label, window title, About
  screen, recording notification, exports and Anki decks all say Margo; the
  Dart package is `margo`, and the Android package is `com.margo.margo`. On
  Android this is a new app, so notes and settings from earlier installs don't
  carry over.
- **Home screen matches the margo design.** Cards sit three across at tablet
  size with the design's spacing, larger titles and ink-coloured meta; the
  sidebar uses the design's type sizes and compact selection pill; the header
  icons are full size with the sort control under them; search opens a frosted
  panel in place of the search icon; **+ new** and the template dialog are
  frosted glass. The knowledge graph moved off the card face into the
  long-press menu.
- **Home screen redesigned ("margo").** The Notes screen is now a sage sidebar
  (Notes, Favorites, Shared — coming soon — and your folders and tags) beside a
  grid of note cards, each a thumbnail over a footer with the title, page count,
  date and a bookmark to favourite it. On narrow screens the sidebar opens from a
  menu button. Search moved to a popover under the search icon, and **+ new**
  opens a redesigned template dialog where you also pick the page colour (white,
  ivory or dark).
- **Adapts to every Android screen size.** The home screen, its search popover and
  new-note dialog, Settings, About and Trash now lay out correctly from a small
  320 dp phone to a 14" tablet, in portrait and landscape, on a foldable's cover
  and inner screens, and at large system font sizes. Wide windows (840 dp+) pin
  the sidebar and show more columns; narrower ones use a drawer. Cards grow with
  the font size instead of clipping, and the About page scrolls when it must. A
  device-matrix test suite (12 devices × 2 orientations × 3 font scales) guards
  this.
- **New sage palette and Modulus Pro typeface, app-wide**, with a matching dark
  theme (light sage on forest charcoal). Note: Modulus Pro is licensed for
  personal use only — a commercial licence from its author is needed before any
  public release.

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
- Developer Mode, its settings section and the Canvas 2.0 playground are no longer shown in release builds.
- Deleting a notebook library item that cannot be saved no longer drops it from the screen; the removal is rolled back and the error is shown.
- Opening a notebook that is missing or unreadable shows an error and a way back to the notes list, instead of a spinner that never ends.
- Importing an image waits until the image is saved before reporting success.
- Duplicating or deleting a page waits for that page's pending edits, so no stray data is left behind.
- A library file that cannot be read is no longer treated as empty, so it cannot be overwritten by the next save.
- Pending edits are saved when the app is sent to the background (best effort).
- Pages that the one-time v1 to v2 migration cannot read are recorded in the error log.
- The database can grow to 4 GiB instead of stopping at 1 GiB.

### Changed
- **Navy and gold theme.** The whole app now uses the navy and gold design, in place of the warm coral skin: navy on warm off-white in light mode, gold and cream on near-black in dark mode. Paper and pen colours are unchanged, so your drawings look the same. Error messages and the recording indicator use the standard Material red. The old green, honey and periwinkle highlights are now navy or gold, so a few status colours are harder to tell apart: the study planner's task kinds, and the knowledge graph's practiced and mastered levels.
- **On-device AI packages replaced.** The `flutter_gemma` packages were discontinued on 5 October 2026, so the on-device model stack now runs on their maintained successors: `flutter_edge_ai` 2.1.0, `flutter_edge_ai_litertlm` 1.9.0, `flutter_edge_ai_speech` 0.5.4 and `flutter_edge_ai_embeddings` 2.2.2. No user-visible change is intended. The Phase 1 device checks in `docs/TECH_MIGRATION_PLAN.md` are still to be run.
- **Local database library replaced.** The Isar database now uses `isar_community` 3.3.2, the maintained fork of the Isar 3.x line, because plain `isar` was last released in April 2023. The collection and property layout is unchanged, so existing data should still open. A debug build logs the row count of each collection at startup. The device checks for this upgrade are still to be run.
- **Dependencies refreshed.** Riverpod 3.4, go_router 18, record 7.1, just_audio 0.10, pdfx 2.11, image_picker 1.2, file_picker 10.3 and package_info_plus 9, with flutter_lints 6. file_picker 11 does not build for Android yet. file_picker 12 and later, and package_info_plus 10 and later, need a newer win32 than the pinned share_plus 12.0.2 allows. The device checks for navigation, background indexing, downloads and recording are still to be run.

### Changed
- **Search runs on EmbeddingGemma 2.** Ask your notes now uses Google's
  EmbeddingGemma 2 (text only, ~165 MB) instead of EmbeddingGemma 300M. It is
  free to download with no Hugging Face account or token. If you already had
  notes indexed, the app downloads the new model and re-indexes them in the
  background; questions keep working on the old index until it finishes, and
  then the old model's files are removed. Notebook titles now go into the slot
  the model was trained with, and a passage too long for the model is shortened
  instead of failing. Expect slightly more memory use while searching.
- **On-device AI packages updated** to `flutter_edge_ai` 2.5.2,
  `flutter_edge_ai_litertlm` 1.17.0, `flutter_edge_ai_embeddings` 2.3.2 and
  `flutter_edge_ai_speech` 0.5.10. The debug-only rollout dry run in Settings is
  gone; the real switch to EmbeddingGemma 2 replaces it.
- **The app is now called Margo.** The launcher label, window title, About
  screen, recording notification, exports and Anki decks all say Margo; the
  Dart package is `margo`, and the Android package is `com.margo.margo`. On
  Android this is a new app, so notes and settings from earlier installs don't
  carry over.
- **Home screen matches the margo design.** Cards sit three across at tablet
  size with the design's spacing, larger titles and ink-coloured meta; the
  sidebar uses the design's type sizes and compact selection pill; the header
  icons are full size with the sort control under them; search opens a frosted
  panel in place of the search icon; **+ new** and the template dialog are
  frosted glass. The knowledge graph moved off the card face into the
  long-press menu.
- **Home screen redesigned ("margo").** The Notes screen is now a sage sidebar
  (Notes, Favorites, Shared — coming soon — and your folders and tags) beside a
  grid of note cards, each a thumbnail over a footer with the title, page count,
  date and a bookmark to favourite it. On narrow screens the sidebar opens from a
  menu button. Search moved to a popover under the search icon, and **+ new**
  opens a redesigned template dialog where you also pick the page colour (white,
  ivory or dark).
- **Adapts to every Android screen size.** The home screen, its search popover and
  new-note dialog, Settings, About and Trash now lay out correctly from a small
  320 dp phone to a 14" tablet, in portrait and landscape, on a foldable's cover
  and inner screens, and at large system font sizes. Wide windows (840 dp+) pin
  the sidebar and show more columns; narrower ones use a drawer. Cards grow with
  the font size instead of clipping, and the About page scrolls when it must. A
  device-matrix test suite (12 devices × 2 orientations × 3 font scales) guards
  this.
- **New sage palette and Modulus Pro typeface, app-wide**, with a matching dark
  theme (light sage on forest charcoal). Note: Modulus Pro is licensed for
  personal use only — a commercial licence from its author is needed before any
  public release.

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

### Changed
- **Navy and gold theme.** The whole app now uses the navy and gold design, in place of the warm coral skin: navy on warm off-white in light mode, gold and cream on near-black in dark mode. Paper and pen colours are unchanged, so your drawings look the same. Error messages and the recording indicator use the standard Material red. The old green, honey and periwinkle highlights are now navy or gold, so a few status colours are harder to tell apart: the study planner's task kinds, and the knowledge graph's practiced and mastered levels.
- **On-device AI packages replaced.** The `flutter_gemma` packages were discontinued on 5 October 2026, so the on-device model stack now runs on their maintained successors: `flutter_edge_ai` 2.1.0, `flutter_edge_ai_litertlm` 1.9.0, `flutter_edge_ai_speech` 0.5.4 and `flutter_edge_ai_embeddings` 2.2.2. No user-visible change is intended. The Phase 1 device checks in `docs/TECH_MIGRATION_PLAN.md` are still to be run.
- **Local database library replaced.** The Isar database now uses `isar_community` 3.3.2, the maintained fork of the Isar 3.x line, because plain `isar` was last released in April 2023. The collection and property layout is unchanged, so existing data should still open. A debug build logs the row count of each collection at startup. The device checks for this upgrade are still to be run.
- **Dependencies refreshed.** Riverpod 3.4, go_router 18, record 7.1, just_audio 0.10, pdfx 2.11, image_picker 1.2, file_picker 10.3 and package_info_plus 9, with flutter_lints 6. file_picker 11 does not build for Android yet. file_picker 12 and later, and package_info_plus 10 and later, need a newer win32 than the pinned share_plus 12.0.2 allows. The device checks for navigation, background indexing, downloads and recording are still to be run.


## [4.0.0] - 2026-07-31
### Fixed
- **The AI could only ever read the page you had open.** Importing a PDF and
  asking a question about it returned "I couldn't find that in your notes" for
  every page you hadn't manually flipped to — the indexer only ran on the page
  in front of you. A whole import is now read and indexed as soon as it lands,
  and there is an **Index all pages** action in the notebook's ⋮ menu for
  notebooks you imported before this build.

### Added
- **Choose what the AI reads.** Ask, Summarize and the Knowledge graph now let
  you pick *this page*, *the whole PDF*, or *the whole notebook*. The "whole
  PDF" option appears whenever the page you're on came from an import, and the
  Ask box shows which one it is searching so a "not found" is never ambiguous.
- **Maths is typeset.** Formulas in explanations, answers and summaries render
  properly instead of arriving as raw `\frac{}{}`.
- **A confidence check on every on-device answer.** When the small on-device
  model produces something broken — empty, looping, or an answer that ignores
  the passages it found — the app says so instead of presenting it as settled
  fact, and offers to re-check it with the cloud model. Nothing is sent without
  you asking: with the default privacy setting the cloud call only happens when
  you press the button.
- **A cloud switch in the AI panel**, so you no longer have to go to Settings
  mid-question. You can also type `/cloud on` or `/cloud off` straight into the
  Ask box.

### Changed
- **The tutor sounds like a tutor.** Explanations, answers and summaries share
  one rewritten voice with the AI-assistant habits stripped out — no "Certainly!",
  no "Let's break this down step by step", no padded lists of three, no
  "Furthermore". Varied sentences, direct address, and examples taken from your
  own notes. The rules about never inventing facts, and refusing when your notes
  don't cover something, are unchanged.
- The Knowledge graph can now be built for one page or one imported document,
  not just for a whole notebook.

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
