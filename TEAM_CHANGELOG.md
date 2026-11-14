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

**Committed but not pushed yet** (on Nabil's machine, `margo-device-fixes`):
- `933ebcc`: **real page sizes** (A4, Letter, 16:10, or Fit screen) and a **continuous layout**, with pages stacked and scrolled like a document.
- This is another database change: a new `Notebook.pageSize` column. Older builds ignore it.
