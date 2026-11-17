# Team changelog

This is a log of everything pushed to GitHub (`Nishmam12/DistillEd`) by anyone on the team: what changed, and what the others need to do about it. The newest entry is at the top.

It's not the same file as [`CHANGELOG.md`](CHANGELOG.md). That one records what changed in the **app**, by version. This one records **who pushed what, where and when**, so that someone who wasn't there can catch up.

**Every push adds an entry here, in the same push.** Each Claude session follows this through the rule in [`CLAUDE.md`](CLAUDE.md). If someone pushes without Claude, the next Claude session that pushes adds the missing entry from the git history.

## The team

| Who | GitHub name(s) in commits | Machine |
| --- | --- | --- |
| Nabil | `Nishmam12` | RTX 4070 Ti Super |
| Afnan | `Afnan Mojumder`, `afnan-mojumder` | RTX 2070 Super |
| Daniel | `capitalD`, `capitalD10` | RTX 5060 |

## Entry format

```
### <date> · <who> (<machine>) · <branch> · <version or "no version bump">
Commits: <first>..<last>
**What changed** (in plain words, for someone who wasn't there)
**What you need to do** (update first? database change? new dependency? nothing?)
**Tested** (analyze / tests / on which device, or "not on a device yet")
```

---

## Push log

### 2026-11-17 · Afnan (RTX 2070 Super) · `release/5.5.0-37` · no version bump
Commits: `d76552d`..`01d9409` (2 commits), plus this changelog commit

**What changed** (phase 3 items 5 and 6 of `docs/COMPETITOR_UPGRADE_PLAN.md`;
phase 3 is now finished):
- **Recent searches.** The home search shows the last 8 searches whose result
  was opened, as chips under the empty field, with Clear. Tap one to run it
  again. Kept in shared_preferences.
- **Search tint on handwriting.** A page opened from search now also tints
  the handwritten lines holding the match (before, only words on page
  pictures were tinted). The ink is read again with ML Kit while the tint is
  shown; no model download is started for it.
- **Search text kept current, with retry.** Before, a page's search text was
  only saved when the AI panel analysed it or a PDF import indexed it, so
  handwriting on a page nobody opened the panel on could never be found. Now
  every element write marks the page in a new queue, and a background worker
  reads marked pages on the device (ML Kit only, no vision model, no cloud)
  and saves their search text. Runs 5 s after start, on resume and when a
  notebook is closed; waits when the device is hot or low on battery. No
  handwriting model: the page waits, no attempt used. Other failures: 3 tries,
  then it waits for the next edit. Pages that already had search text are
  left as they are at first, so earlier deeper reads are kept.

**What you need to do:** pull. **Database change:** a new Isar collection,
`PageIndexTask` (additive, approved for phase 3; nothing to migrate). On the
first launch the app reads every page that has no search text yet, in the
background. No new dependencies.

**Tested:** `flutter analyze` clean (no errors or warnings); full suite
3,606 passing. On the Pixel Tablet emulator: a word typed on a new page was
found under "On pages" right after closing the note, without the AI panel;
recent chip shown after opening the result, and tapping it re-ran the search.
The handwriting tint is covered by a widget test, not tried on a device.

### 2026-11-17 · Afnan (RTX 2070 Super) · `release/5.5.0-37` · no version bump
Commits: `f728c39`..`5f0e993` (5 commits). *Added from the git history by
Afnan's Claude: these were pushed without an entry.*

**What changed** (phase 3 items 1 to 4):
- **Links between pages.** Select something and link it to another page, a
  notebook or a web address; "Open link" follows it. A page that others link
  to shows a "Linked from" chip (backlinks).
- **"Matched by meaning" in the home search.** Pages that mean what was typed
  without containing it, from the embeddings the tutor already keeps, on the
  device and offline. A setting hides it. Empty until the on-device search
  model is downloaded.
- **Filters and saved searches.** The sort button opens one sort & filter
  sheet: date, "has handwriting", "has a lecture recording", plus folder,
  tags and favourites. "Save this view…" names it. Saved in
  shared_preferences.
- **Nested tags and tag colours.** "Physics / Optics" nests a tag; the
  sidebar shows the tree. Long-press a tag for a colour (shared_preferences,
  so colours don't travel in backups).

**What you need to do:** pull. **Database change:** one additive field on
`SceneElementRecord` (the element's link target). No new dependencies.

**Tested** (from the commit messages): analyze clean, tests passing; tried on
the Pixel Tablet emulator.

### 2026-11-17 · Afnan (RTX 2070 Super) · `release/5.5.0-37` · no version bump
Commits: `c0f8376`..`8fd36a2` (7 commits), plus this changelog commit

**What changed** (phases 1 and 2 of `docs/COMPETITOR_UPGRADE_PLAN.md`):
- **Share to Margo / Open with Margo (Android).** Margo now appears in the
  share sheet for text, links, images, PDFs, `.txt` and `.md` files (one or
  several), and in "Open with" for PDFs and text files. A sheet asks: new
  note or an existing one. Several PDFs into a new note: one note, or a note
  each. Only `content://` links from other apps are read; Margo's own files
  can't be pulled in through a share.
- **Password-protected PDFs** ask for the password and import an unlocked
  copy (PDFium does the unlocking; the password is not kept).
- **Text and Markdown files** become typed text pages, split to fit the page.
  Also in the editor's import sheet: "Text or Markdown file".
- **A shared web link** becomes a small text card (title, site, address).
  Nothing is fetched from the web; it isn't tappable yet (comes with phase 3).
- **Lecture recording:** a pause/resume button while recording (the paused
  time is not in the file, and later ink still lines up); a player bar when a
  lecture plays (play/pause, time, 0.5×–2× speed); while it plays, ink
  written later in the lecture is faint and fills in (note replay); tapping a
  transcript line shows the ink written while it was said.
- **Study summary after a transcript:** new setting "Summarise lectures" (on
  by default, only acts with transcripts on). The page is summarised on the
  phone only, never the cloud, and shown in the transcript sheet with "Make
  flashcards from this lecture".
- **Bug fixed:** "Play from here" always started a recording at 0:00, because
  strokes were stamped by mixing two different clocks. New recordings seek
  correctly; strokes in older recordings keep their wrong 0:00 time.
- **Bug fixed:** opening a PDF with Margo showed "Page Not Found" (Flutter's
  deep linking is now off in the manifest; Margo has no deep links).

**What you need to do:** pull, then do a full rebuild (not hot reload): the
Android manifest and `MainActivity.kt` changed. No new packages, no
`flutter pub get` needed, no database change. Summaries are saved as
`*.summary.txt` files next to lecture transcripts.

**Tested:** `flutter analyze` clean (0 errors, 0 warnings); all 3,586 tests
pass. On the Pixel Tablet emulator: locked PDF via "Open with" (wrong and
right password), Markdown and a link shared with the app open, pause during
a recording (a ~9 s pause is absent from the file), play from a stroke,
replay fading, 2× speed. Not tried: "a note each" for several PDFs (adb can't
send a multi-file share), transcript→ink and the summary (need the speech and
language models on a device), and nothing on a real phone yet.

### 2026-11-17 · Afnan (RTX 2070 Super) · `release/5.5.0-37` · no version bump
Commits: the commit after `a44587b` (this push)

**What changed:**
- `docs/COMPETITOR_UPGRADE_PLAN.md` now covers Evernote 11.42.4 as well as
  Samsung Notes. Samsung Notes was decompiled with JADX, so the plan records
  how its features actually work (note replay, the retrying search indexer,
  suggested titles and tags, note lock). Evernote is a React Native app; its
  feature set was read from the compiled bundle's strings and its editor code.
- The plan has 8 phases, from "Share to / Open with Margo" to templates and
  export, each checked against Margo's code. It corrects the first draft:
  linking ink to audio and recolouring/straightening ink already exist.
- Decisions recorded: note lock will hide notes (not encrypt them) using
  `local_auth`; the stored-data additions in phases 2, 3 and 6 are approved.
- `.gitignore` now also ignores `*.xapk`, so competitor packages stay local.

**What you need to do:** nothing. Docs and `.gitignore` only; no code,
package or database change. Nothing in the plan is built yet.

**Tested:** not applicable (no code changed).

### 2026-11-17 · Afnan (RTX 2070 Super) · `release/5.5.0-37` · no version bump
Commits: `a44587b`

*Added from the git history by Afnan's Claude.*

**What changed:** added `docs/COMPETITOR_UPGRADE_PLAN.md`, the first version
of the upgrade plan, based on Samsung Notes only.

**What you need to do:** nothing. Docs only.

**Tested:** not applicable (no code changed).

### 2026-11-17 · Nabil (RTX 4070 Ti Super) · `release/5.5.0-37` · 5.5.0+37
Commits: `fbe07be`..(this release commit), including Afnan's `1ae6e71`, `14c30c8` and `a5ebd54`

**What changed:**
- Vector PDF export with searchable typed text, imported-page text and optional
  on-device handwriting recognition; PDF contents, page links and search-hit
  tinting are retained on import.
- Home search finds pages across notebooks; a Recent strip and multi-notebook
  selection support opening, pinning, filing, tagging and trashing notes.
- Backups keep five dated snapshots per notebook, with a restore browser and
  fixes for a cleared destination folder and leaving the restore screen.
- Own-key cloud AI: a default connection for cloud page reading, additional
  answer-only connections, a model picker and `/model`, selected-model routing
  across answer features, consent prompts and error-log key scrubbing.
- Integrated Afnan's independent cloud implementation and gateway removal.
  One provider retains both implementations' text, tool and image behavior;
  both provider test suites are kept. The default connection appears in the
  picker, and answer-only connections work without a default page-reading key.
- Published on a new release branch; the remote `margo-device-fixes` branch
  is unchanged by this push.
- Teacher-persona constants and learner-profile helpers are in the code;
  feature wiring is still pending. Retrieval and conversation work is design
  only. No teaching-style control or conversation memory is claimed here.

**What you need to do:**
- Pull and run `flutter pub get` to register the embedded PDF font assets.
  No new package or database schema change in this release.
- Configure your own key under Settings → AI Models to use cloud AI. The
  Render gateway and its web-search tool are removed; Research offers
  Calculator and Wikipedia. Margo's bundled cloud tiers remain unavailable.
- A default cloud connection may read pages when the processing mode and
  privacy setting permit it. Connections added with "Add an AI" are used only
  when selected to answer. Cloud-off and an explicit on-device pick still win.
- Re-import older PDFs to add their contents and links. No existing notebook
  needs to be migrated.
- The unrelated local R8/Gradle edits, `pubspec.lock` edit and `.vscode/` are
  excluded from this push and preserved on this machine.

**Tested:** `flutter analyze --no-pub` clean. Full `flutter test --no-pub`:
3,517 passed, 44 skipped, no failures, including the error-log test that had
failed in earlier full runs. Cloud integration regressions also passed
separately. Flutter 3.47.6 / Dart 3.13.5 with this machine's resolved packages;
the pre-existing local `pubspec.lock` edit is excluded from the commit.
No APK build, tablet check or live-provider call has been performed here.

### 2026-11-17 · Afnan (RTX 2070 Super) · `margo-device-fixes` · no version bump
Commits: `a5ebd54`

**What changed:** Added `docs/CLOUD_KEY_PLAN.md`, an implementation plan for
using a student's own cloud provider key.

**What you need to do:** No dependency or database change; read the plan for
the default cloud-provider workflow. The integrated implementation is
documented in the 5.5.0+37 entry above.

**Tested:** No test result recorded in this commit; documentation only.

*Added from the git history by Nabil's Codex.*

### 2026-11-15 · Afnan (RTX 2070 Super) · `margo-device-fixes` · no version bump
Commits: `1ae6e71`..`14c30c8`

**What changed:** Cloud AI calls the user's own OpenAI-compatible provider
directly, with a Settings dialog for a key and model, streamed answers, tool
calls and image reading. Removed the Render gateway, its server sources,
web-search tool and gateway CI job. Added cloud-connection and settings tests.

**What you need to do:** Configure your own cloud key and model in Settings.
The old Render gateway is no longer used. No new package or database change.

**Tested:** Not independently recorded here; the merged code is covered by the
verification in the 5.5.0+37 entry above. No device result inferred.

*Added from the git history by Nabil's Codex.*

### 2026-11-15 · Nabil (RTX 4070 Ti Super) · `margo-device-fixes` · 5.4.0+36
Commits: `2a84c44`..(this release commit), including the merge of Afnan's `0bb8452` and `b990117`

**What changed:**
- **Page manager:** a full-screen grid of every page. Long-press a page and drag it to reorder. "Select" then duplicates, moves or deletes several pages at once (it asks first; the last page can't be deleted). Open it from the grid button in the page bar or the Book view.
- **Bookmarks, page names and an outline.** Bookmark a page or name it from its menu, filter the grid to bookmarked pages, and see them in the outline (the list button in the page bar).
- **One paper per page:** the page sheet's template section has "Whole notebook" and "This page only".
- **Four new paper templates:** Cornell, Music, Isometric and Checklist. On the infinite canvas Cornell looks like ruled paper.
- **Select text on PDF pages and photos:** the select tool's new Text mode. Drag over words to Copy them, Highlight them, Ask the AI, or Search the notebook.
- **The highlighter snaps to printed words** (Settings → "Snap highlighter to text", on by default). Undo brings back your stroke.
- **Afnan's changes are in this push too:** the Gradle and AGP bump, and the readable cloud error messages (see their entries below).

**What you need to do:**
- **Database change.** Pages gained three columns: `bookmarked`, `title` and `templateOverride`. **Update to 5.4.0+36 before using bookmarks, page names or a per-page template.** An older build ignores them.
- **Gradle:** the first build after pulling downloads Gradle 9.3.1 and AGP 9.1.1.
- No new dependency. No `flutter pub get` needed for this push.
- **Text on old PDFs and photos:** the first time you select words on one, the page is read once on the device. Nothing is sent anywhere.

**Tested:** `flutter analyze` clean; 3,100 tests passing, 44 skipped; `error_log_test` (a known flaky test) fails in the full run. Not on a device yet. The merged Gradle bump was not built here.

### 2026-11-15 · Afnan (RTX 2070 Super) · `margo-device-fixes` · no version bump
Commits: `b990117`..(this commit)

**What changed:**
- **Android build tools raised so Flutter 3.50.0 builds again.** Flutter now refuses to build below Gradle 9.3.1 and Android Gradle Plugin (AGP) 9.1.1, and the project was on 9.1.0 and 9.0.1.
  - Gradle wrapper: 9.1.0 to 9.3.1, in `android/gradle/wrapper/gradle-wrapper.properties`.
  - AGP: 9.0.1 to 9.1.1, in `android/settings.gradle.kts`.
- **Not done:** Flutter warns it will soon drop support for Gradle 9.3.1 and wants 9.5.0 or newer. The build still passes today.

**What you need to do:**
- Update, then build as usual. The first build downloads Gradle 9.3.1 and AGP 9.1.1, so it takes longer and needs a network connection.
- You no longer need `--android-skip-build-dependency-validation`.
- No database change, no `flutter pub get`.

**Tested:** `flutter build apk --release` succeeds without the bypass flag (219 MB all-architecture APK). The new build was not installed on a device after this change; the Pixel 7 Pro install earlier was built with the old Gradle and the bypass flag. CI was not run.

### 2026-11-15 · Afnan (RTX 2070 Super) · `margo-device-fixes` · no version bump
Commits: `65c9235`..`b990117`

**What changed:**
- **Flashcards and Quiz loading panels** now span the full width of the screen, like the other AI panels. Before, the loading, download and error views shrank to a narrow card in the middle.
- **Cloud error messages are readable.** A cloud 404 now says "Cloud gateway unreachable", and any other unexpected status says "Cloud request failed (HTTP 500)." instead of a long Dio paragraph. Every cloud feature shares this, so Research, Explain and the rest all show the shorter text.
- **Known problem, not fixed by this push:** Research (and every cloud feature) fails right now because the Render service `margo-ai-gateway` has no server behind it. Every path, including `/health`, returns 404 with `x-render-routing: no-server`. It needs redeploying from `render.yaml` in the Render dashboard, with `OPENROUTER_API_KEY` and `EXA_API_KEY` entered again. If it comes back at a different address, `cloudGatewayBaseUrl` in `ai_providers.dart` must change to match.
- **Build note:** Flutter 3.50.0 requires Gradle 9.3.1 and the project was on 9.1.0, so `flutter build` and `flutter run` stopped at a version check. This push doesn't change that; the next entry (2026-11-15, Gradle and AGP bump) does.

**What you need to do:**
- Nothing for the code: no database change, no new dependency, no `flutter pub get`.
- Whoever has Render access: redeploy the gateway (see above).

**Tested:** `flutter analyze` shows only the existing `material.dart` deprecation notices. All 1,422 tests under `test/features/ai` pass, including 2 new ones for the 404 and other-status messages. Release build installed on a Pixel 7 Pro: the flashcard loading panel is full width. The cloud error message was not checked on the device.

### 2026-11-14 · Nabil (RTX 4070 Ti Super) · `margo-device-fixes` · 5.3.0+35
Commits: `933ebcc`..(this release commit), including the merge of Afnan's `064b454`

**What changed:**
- **Real page sizes:** A4, Letter and 16:10, each portrait or landscape, or **Fit screen**.
  - Fit screen is the old screen-shaped page, and existing notebooks keep it. New notebooks start at A4 portrait.
  - Choose the size in the page sheet, under Layout.
  - A page is now the same shape on every device, and imported PDF pages fill it.
- **Continuous layout:** pages stacked top to bottom and scrolled like a document.
  - The page in the middle of the window is the one you write on.
  - Touching the page above or below switches to it.
- **This team changelog**, and the rule in `CLAUDE.md` that every push adds an entry to it.

**What you need to do:**
- **Database change.** There's a new `Notebook.pageSize` column, and continuous adds `layoutMode` value 2. **Update to 5.3.0+35** to use page sizes or the continuous layout.
- On an older build nothing is lost: the notebook shows at Fit screen, and continuous shows as the infinite canvas.
- Run `flutter pub get`, since this push includes Afnan's `pubspec.lock` update.
- **When you push next:** your Claude will add your entry here (see `CLAUDE.md`).

**Tested:** `flutter analyze` clean, 3,030 tests passing. Not on a device yet: check that an existing notebook still opens.

### 2026-11-14 · Afnan (RTX 2070 Super) · `margo-device-fixes` · no version bump
Commits: `064b454`

**What changed:**
- Dependency versions refreshed in `pubspec.lock`. No app code changed.

**What you need to do:**
- Run `flutter pub get` after pulling.

**Tested:** not recorded.

*Added from the git history by Nabil's Claude.*

### 2026-11-14 · Afnan (RTX 2070 Super) · `iPadOS-build` · no version bump
Commits: `804ee25`..`f1e00f6`

**What changed:**
- The first iOS / iPadOS port: the iOS project structure, a macOS build workflow, and `Podfile.lock`.
- The Apple-silicon simulator script for `google_mlkit_commons` moved to the Podfile's `post_install` block.
- The port plan's build status was updated.

**What you need to do:**
- Nothing for Android work. The iOS port is on its own branch.

**Tested:** not recorded.

*Added from the git history by Nabil's Claude.*

### 2026-11-14 · Nabil (RTX 4070 Ti Super) · `margo-device-fixes` · 5.2.0+34
Commits: `b656658`..`9c77da7`

**What changed:**
- **Lasso select:** a free-form loop as well as the rectangle.
- **Colour and thickness of a selection.**
- **Copy as image:** opens the share sheet.
- **Convert handwriting to text in place:** ML Kit reads the handwriting on the device, and you check the result before it replaces the ink.
- **Straighten slanted handwriting.**
- **Revision tape:** a Tape tool lays a strip over notes, and a tap lifts it to peek underneath.

**What you need to do:**
- **Database change.** Tape added a new element kind and a new column, `tapeRevealed`. **Everyone must update to 5.2.0+34 before using tape.**
- On an older build, tape shows as an empty pen stroke. If that build saves the page, the tape is lost.

**Tested:** `flutter analyze` clean, 3,017 tests passing. Not on a device yet.

### 2026-11-14 · Nabil (RTX 4070 Ti Super) · `margo-device-fixes` · 5.1.2+33
Commits: `8256076`..`b656658`

**What changed:**
- **First device test, fixed:**
  - The AI no longer hangs, or gets the app killed, on a page full of photos. It reads at most 4 pictures per page, with Stop and Read more.
  - Importing many photos onto one page now asks first.
  - PDF import has a "Read the text now" switch.
  - There's a finger-draw switch in the tool row.
  - Three-finger redo is reliable.
  - Straighten is its own setting, off by default.
  - The tool row fits when the AI panel is open.
  - Locked PDF pages show "Unlock to move".
- **The AI panel floats** over the page: drag it, resize it, or dock it.
- **Type text straight onto the page.** This replaces the Add text dialog.

**What you need to do:**
- Nothing special.

**Tested:** `flutter analyze` clean, 2,979 tests passing. Not on a device yet.

### 2026-11-14 · Nabil (RTX 4070 Ti Super) · `margo-device-fixes` (new branch) · 5.1.1+32
Commits: up to `8256076`

**What changed:**
- Afnan's Settings redesign (`SettingsUI-upgrade`) is merged in.
- Settings option chips no longer overflow on narrow phones.
- **Pens rebuilt after the first device test:**
  - each pen type remembers its own size and colour
  - the eraser and shapes have their own sizes
  - thinner default pens
  - clearer pen icons
  - scribble-to-erase catches long strokes
- The device-test results are written up in `docs/HANDOVER.md` section 4a.

**What you need to do:**
- Use this branch to try the fixes. Settings now lives here too.

**Tested:** `flutter analyze` clean, 2,929 tests passing, and installed on the Xiaomi tablet for the first device test.

### 2026-11-13 · Afnan (RTX 2070 Super) · `SettingsUI-upgrade` · no version bump
Commits: up to `3490c28`

**What changed:**
- The card-based Settings redesign: new icons, theme swatches, segmented controls for light and dark mode.
- AI models moved to their own screen.

**What you need to do:**
- Nothing. It's merged into `margo-device-fixes`.

**Tested:** not recorded.

*Added from the git history by Nabil's Claude.*

### 2026-11-13 · Nabil (RTX 4070 Ti Super) · `margo-backup-figures` · 5.1.0+31
Commits: up to `9437aaf`

**What changed:**
- **Automatic notebook backup** to `Downloads/Margo`, plus `.margo` export and import.
- **Figures the AI can find, look at again, correct and measure** on a page.
- The handover for the Margo polish roadmap, and the "garden" plan proposal.

**What you need to do:**
- Nothing special.

**Tested:** `flutter analyze` clean, with the test suite passing.

---

## Nabil's work in this repo so far

This is a summary of everything Nabil (`Nishmam12`) has pushed to DistillEd up to 2026-11-14, oldest first. The work up to late July came across from the old `Notepad-` repo when the team moved here on 2026-07-30.

**June 2026: the editor**
- Single-page layout with a bounded viewport.
- Book view fixes and a UI redesign, down to zero lint issues.
- The toolbar scrolls instead of overflowing on narrow screens.

**16–18 July 2026: the AI platform (phases 0–3)**
- **Foundations:**
  - the AI provider layer, with on-device Gemma (`LocalGemmaProvider`) and a router that picks local or cloud
  - page reading (`PageContentExtractor`) and handwriting recognition fed by the editor's ink
  - the Live Context Engine and the AI sidebar
- **Study features:**
  - Summarize, including scoped summaries and chunk-and-reduce for long notes
  - Explain
  - the Writing Assistant
  - the Quiz Generator
  - Flashcards, with Anki `.apkg` and CSV export (2.0.0)
- **Your notes as a knowledge base:**
  - learning memory: concept mastery and quiz history
  - on-device RAG and "Ask your notes", whose answers link back to their source page
  - the Knowledge Graph and the Study Planner
- **Cloud:**
  - the cloud gateway and intelligent router
  - Research with tool calling, deployed on Render
- A per-user Hugging Face token setting for gated model downloads.

**21–31 July 2026: v4 and v5**
- **v4:**
  - PDF and photo import with on-device OCR
  - text editing
  - fixes to handwriting, placement and page size under the AI panel
  - Gemma vision as the main reader for handwriting and imports
  - RAG over the whole PDF, scoped AI, a tutor voice, maths rendering, and an accuracy fail-safe
- **v5:**
  - works with Flutter 3.44
  - an AI mode selector
  - provenance on answers
  - faster vision

**3 October 2026: performance**
- The model stays loaded between uses, and prompt sizes are budgeted.
- An unneeded network (DNS) check and the double run in cloud-first mode are gone.
- A smoother UI: no blur on each card, throttled streaming, cached eraser paths, saves only what changed.
- A page whose vision read failed to run is read again, rather than cached as empty.
- Fixes for flaky tests on Windows.

**11–14 November 2026: the Margo polish roadmap**
- **Pens:**
  - pressure from the device
  - erase with the pen's other end or its side button
  - four pen types, saved pens, custom colours
  - straighten and tap gestures
- **Editor:**
  - the AI panel no longer shifts the page
  - a finger-scroll setting
  - easier import
- **Backup and figures:** 5.1.0, then the device-test fixes in 5.1.1 and 5.1.2.
- **New features in 5.2.0:**
  - lasso select, recolour and thickness, copy as image
  - handwriting to text, straighten handwriting
  - revision tape
- See the push log above for these releases in detail.

**5.3.0** (pushed 2026-11-14):
- **Real page sizes** (A4, Letter, 16:10, or Fit screen) and a **continuous layout**, with pages stacked and scrolled like a document.
- This team changelog.

**5.4.0** (pushed 2026-11-15):
- Page manager, bookmarks, page names and an outline; one paper per page.
- Four more paper templates.
- Select the text on PDF pages and photos; the highlighter snaps to printed words.
- Word positions for PDF pages, read once on the device where a page has none.
