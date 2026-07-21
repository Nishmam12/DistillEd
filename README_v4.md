# Notepad— · Iteration 4 Release Notes

> **Branch:** `fix/v4-handwriting-import-ocr-placement`
> **Target:** `v2.0.0`
> **Date:** 2026-07-21

---

## What Changed in This Iteration

This iteration is a **pure quality pass** on the Phase 2 / Phase 3 AI feature set. Every item below was found by running the real app on a real device with real handwritten notes — not by code inspection — so each fix is diagnosed from device evidence and verified on-device before shipping.

---

### 🐛 Bug Fixes

#### 1. Handwriting recognition was effectively broken for all AI features
**Files:** `lib/features/ai/data/ocr/handwriting_recognition_service.dart`, `lib/features/ai/domain/handwriting/ink_lines.dart`

The entire ML Kit digital-ink pipeline was sending one giant `Ink` object per page, in raw **scene coordinates** whose pixel scale depended on whatever zoom level the user happened to be at when they wrote. ML Kit received a single enormous smear of marks and returned `":::::::::"`. No AI feature that depends on page text (Live Context, Ask-your-notes, Summarize, Knowledge Graph, Study Planner, RAG indexing) was actually reading handwriting.

**The fix:**
- Strokes are now **grouped into lines** by Y-centroid proximity before recognition.
- Each line is **normalised** to a canonical 32 px cap-height so ML Kit always sees writing at a consistent size regardless of zoom.
- **Underlines and ruled-line artefacts** are dropped before grouping so they don't corrupt the word boundaries.
- **Table columns** are detected and split at gap thresholds so each column is recognised separately and then rejoined.
- Each segment is given `preContext` (the text already recognised on the page) so the recogniser can resolve ambiguous letters against the sentence so far.

On-device result: a table row that produced `"ape assiiions"` now returns `"Topic" / "Classification" / "Regression"`.

---

#### 2. AI Insights "Worth revisiting" filled with handwriting misreads
**Files:** `lib/features/ai/domain/context_engine/context_engine.dart`

After the handwriting fix above, some residual misreads (e.g. `"ge sin"`, `"ug ns"`) still leaked into the **Live Context** suggestions as supposed knowledge gaps. Score-based filtering cannot distinguish a legitimate short concept from a garbled fragment.

**The fix:** The model prompt now explicitly tells the LLM that the text is handwriting-transcribed and instructs it to **omit anything it cannot confidently resolve** rather than quoting fragments back at the user as study topics.

---

#### 3. "Insert as note" placed notes off-screen or on top of existing work
**Files:** `lib/editor/ui/notebook_editor_screen.dart`, `lib/editor/ui/editor_controls.dart`

When an AI answer was inserted as a note:
- It was placed **below the visible viewport** on a busy page, requiring zoom-out to find it.
- Collision detection only avoided *other previously-inserted notes*, not strokes, text, images, or shapes.
- Sizing was in absolute pixels, so notes appeared at wildly different apparent sizes depending on zoom.

**The fix:**
- Placement is now **bounded by the visible scene rectangle**.
- Collision uses `ElementBounds.of` across **every element** on the page.
- The note is **sized relative to the current zoom level** so it always reads at the same apparent size.
- If no empty space exists in the current view, a snackbar says "No empty space in view" instead of silently hiding the note off-screen.

---

#### 4. The page shrank when the AI panel was docked
**Files:** `lib/editor/ui/notebook_editor_screen.dart`, `lib/editor/ui/scene_canvas.dart`, `lib/editor/state/viewport_controller.dart`

Opening the AI insights panel in side-by-side mode caused the canvas to narrow. Because `pageSize` and `viewportSize` were both derived from the same canvas constraints, and the page rect also acts as the **scene clip**, writing on the right-hand side of the page was clipped as if it had never existed.

**The fix:**
- `pageSize` is now **latched once** at page load and never changes when the canvas resizes.
- Narrower canvas dimensions are reported separately as the **viewport** for pan/zoom calculations.
- When the panel opens and the page would no longer fit, zoom is **re-fitted** automatically (user-set zoom is left alone).
- The latch lives in `NotebookEditorScreen`, not `SceneCanvas`, because `SceneCanvas` is keyed by page ID and rebuilt on every page turn.

---

#### 5. Handwriting recognition failing entirely on Android
**Files:** `pubspec.yaml`, `pubspec.lock`

A recent upstream update to `google_mlkit_digital_ink_recognition` broke recognition silently on Android — no exception thrown, just nothing recognised.

**The fix:** Pinned back to the **last working release** (`0.15.0`).

---

### ✨ New Features

#### Import PDFs and photos into a notebook
**Files:** `lib/editor/import/`, `lib/editor/ui/notebook_editor_screen.dart`, `lib/editor/ui/editor_controls.dart`

A new import button in the notebook toolbar supports:
- **PDF import** — every page becomes its own notebook page, sized-to-fit and locked for annotation. Re-importing the same PDF is instant (content-hashed, no duplication on disk).
- **Photo import** — from library or camera, with a choice of "on this page" or "on a new page."

#### Turn an imported page into editable text (on-device OCR)
**Files:** `lib/features/ai/data/ocr/`, `lib/editor/ui/editor_controls.dart`

Select an imported PDF page or photo and tap **Extract text**. The words become real text boxes positioned where they appeared on the page — editable and searchable. The source image stays behind them. Runs entirely on-device via ML Kit. One undo reverses the whole extraction.

#### Edit already-placed text boxes
**Files:** `lib/editor/ui/text_input_dialog.dart`, `lib/editor/ui/editor_controls.dart`

Select any text box and tap **Edit text** to correct its content. Previously text could only be created, never edited.

---

### 🧪 Tests

| Suite | Status |
|---|---|
| Total tests passing | 691 ✅ |
| `flutter analyze` | clean |
| New tests added | ~280 across handwriting, viewport, placement, import |

New test files:
- `test/features/ai/domain/handwriting/ink_lines_test.dart`
- `test/editor/ui/insert_note_placement_test.dart`
- `test/editor/state/viewport_controller_test.dart`
- `test/editor/import/`

---

### 📦 Files Changed

| Area | Files |
|---|---|
| Handwriting pipeline | `handwriting_recognition_service.dart`, `ink_lines.dart` |
| AI context engine | `context_engine.dart`, `page_content.dart`, `page_content_extractor.dart` |
| AI providers | `ai_providers.dart` |
| Editor / note placement | `notebook_editor_screen.dart`, `editor_controls.dart`, `scene_canvas.dart` |
| Viewport / page size | `viewport_controller.dart` |
| Renderer | `scene_element_painter.dart` |
| Import pipeline | `lib/editor/import/` (new directory) |
| OCR | `lib/features/ai/data/ocr/` (new directory) |
| Text editing | `lib/editor/ui/text_input_dialog.dart` (new file) |
| Dependencies | `pubspec.yaml`, `pubspec.lock` |
| iOS support | `ios/` (initial scaffold) |
| Progress / docs | `AI_PROGRESS.md`, `CHANGELOG.md`, `STABILITY_REPORT.md` |

---

### 🗺 What's Next (Phase 2 Device Validation)

- Knowledge Graph stress test on real notebooks.
- Study Planner walkthrough on device with a real set of notes.
- RAG ("Ask your notes") end-to-end on-device with a 20+ page notebook.
- Cloud gateway deployment to Render so Research and Explain-cloud can actually fire.

---

*Iteration 4 of the Notepad— v2.0.0 development cycle.*
