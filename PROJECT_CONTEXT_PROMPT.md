# DistillEd (InkFlow) — Master Project Context & Prompt

> **Purpose:** Use this document as a system prompt, developer onboarding document, or context injection prompt for AI assistants, new contributors, or IDE agents working on DistillEd.

---

## 1. System Identity & Mission

**App Name:** DistillEd (Internal package: `inkflow`, Version: `5.0.0+30`)  
**Platform:** Flutter / Dart (cross-platform: Android, iOS, Desktop)  
**Nature:** Offline-first, high-performance digital notebook, freehand sketching canvas, and AI-powered study companion.

DistillEd merges the infinite/flexible drawing canvas capabilities of **Excalidraw** with the structured multi-page document model of **GoodNotes / Notability**, augmented by an **on-device AI tutor** that learns alongside the student while strictly preserving user privacy.

---

## 2. Core Tech Stack & Tooling

| Domain | Technology / Package | Notes |
|---|---|---|
| **Framework** | Flutter (SDK `>=3.0.0 <4.0.0`) | Material Design 3 enabled |
| **State Management** | `flutter_riverpod` (`^2.5.1`) | Pure Riverpod provider tree (no `get_it`, no static singletons) |
| **Routing** | `go_router` (`^14.2.0`) | Declarative navigation (`/`, `/note/:id`, `/note/:id/book`, `/settings`, etc.) |
| **Database** | `isar` (`^3.1.0+1`) + `isar_generator` | Embedded NoSQL database with code generation via `build_runner` |
| **Stroke Rendering** | `perfect_freehand` (`^2.5.1`) | Pressure-sensitive, variable-width freehand ink |
| **Vector & Shapes** | `flutter_svg` (`^2.3.0`) + Custom Rough renderer | Seeded two-pass wobble + 45° hachure fill |
| **Math Rendering** | `flutter_math_fork` (`^0.7.3`) | Pure Dart LaTeX `$…$` / `$$…$$` rendering in tutor and note UI |
| **PDF & Documents** | `pdfx` (`^2.6.0`), `pdf` (`^3.12.0`), `printing` (`^5.13.1`) | Multi-page PDF import, annotation, and 300 DPI A4 export |
| **Media & Audio** | `image_picker`, `image`, `record`, `just_audio` | PDF/photo import + synchronized lecture voice recording |
| **Flashcards / Anki** | `sqlite3` (`^3.4.0`) + `archive` (`^4.0.9`) | Native compilation of Anki `.apkg` packages |
| **On-Device OCR & Ink** | `google_mlkit_digital_ink_recognition` (`0.14.2`), `google_mlkit_text_recognition` (`0.15.1`) | Pinned for Android stability; line-grouped, normalized OCR |
| **On-Device LLM & RAG** | `flutter_gemma` (`1.3.0`), `flutter_gemma_litertlm`, `flutter_gemma_embeddings` (`1.0.2`) | Local Gemma LLM + EmbeddingGemma 300M offline semantic search |
| **Cloud AI Gateway** | Python FastAPI (`server/ai-gateway/`) + `dio` (`^5.7.0`) | Stateless SSE streaming, deployed on Render, tool calling & web search |
| **Testing** | `flutter_test`, `mocktail` | >1,380 passing unit, domain, repository, and widget tests |

---

## 3. Architecture & Codebase Map

```
DistillEd/
├── assets/                     # Fonts (Poppins, Phosphor, Nunito) & static templates
├── docs/                       # ARCHITECTURE.md, MIGRATION_TEST_PLAN.md, REGRESSION.md
├── server/
│   └── ai-gateway/             # FastAPI cloud proxy (stateless SSE, Exa search, OpenRouter)
├── lib/
│   ├── app/                    # App root widget, theme initialization, GoRouter routes
│   ├── core/                   # Design tokens (InkPalette), constants, icons, external links
│   ├── data/
│   │   ├── migration/          # Versioned migration engine (SceneMigratorV2, AppMeta gates)
│   │   └── persistence/        # Isar repositories, SceneElementRecord, LibraryRepository
│   ├── domain/
│   │   ├── commands/           # Command-pattern undo/redo mutations (per-page stacks)
│   │   ├── geometry/           # Bounds, collision, distance, affine transforms, snapping
│   │   ├── model/              # Sealed SceneElement hierarchy, StrokePoint, Notebook, Page
│   │   └── services/           # Arrow binding, lasso hit-testing, grouping, alignment
│   ├── editor/
│   │   ├── import/             # PDF & image import services, layout fitters
│   │   ├── input/              # Pointer router, palm rejection filter, gesture detector
│   │   ├── render/             # Multi-layer CustomPainters with RepaintBoundary
│   │   ├── state/              # SceneController, ViewportController, ToolController, HistoryController
│   │   ├── tools/              # Pen, eraser, lasso selection, shapes, text, laser, hand
│   │   └── ui/                 # NotebookEditorScreen, scene canvas, toolbars, styling sheets
│   ├── features/
│   │   ├── ai/                 # Core AI Tutor, RAG, handwriting OCR, Knowledge Graph, Study Planner
│   │   ├── audio/              # Lecture voice recording synchronized with notebook pages
│   │   ├── export/             # A4 PDF 300dpi, PNG, SVG export & system share sheet
│   │   ├── home/               # Folder & notebook bookshelf, CRUD, cover styling
│   │   ├── import/             # Import wizards and file pickers
│   │   ├── search/             # Notebook metadata and content search
│   │   ├── settings/           # AI model downloader (Gemma/EmbeddingGemma), theme, about
│   │   └── summarize/          # Standalone page and import-group summarizer
│   ├── shared/                 # IsarService database singleton
│   └── main.dart               # Bootstrap, uncaught error handlers, UI error boundary
└── test/                       # 1,380+ unit, domain, repository, and widget tests
```

---

## 4. Subsystems Deep-Dive

### A. Drawing Canvas & Scene Graph
1. **Unified Sealed Scene Model (`SceneElement`)**:
   - `FreehandElement`: Vector points with pressure, color, size, and eraser flags.
   - `ShapeElement`: Rectangle, diamond, circle/ellipse, line, elbow/straight arrow, with stroke and fill styles (solid, hachure, cross-hatch).
   - `TextElement`: Bound text (inside shapes) or standalone text blocks with font styling and alignment.
   - `ImageElement`: Imported photos and diagrams.
   - `PdfBackground`: Locked background image of an imported PDF page.
2. **6-Layer Rendering Stack (`RepaintBoundary`)**:
   - Background $\rightarrow$ Imported Content $\rightarrow$ Combined Content (committed strokes + shapes) $\rightarrow$ Active Stroke (fast-path dynamic drawing layer) $\rightarrow$ Selection (lasso, marquee, 8 handles, rotation) $\rightarrow$ Eraser Trail.
3. **Viewport Transformation**:
   - Screen-to-World mapping: `screenX = scrollX + zoom * sceneX`.
   - Focal-anchored zoom (0.1× to 5.0×).
4. **Hardware Stylus & Palm Rejection**:
   - 500ms grace window, retroactive stylus-after-palm rejection, and hover pre-arm in `raw_pointer_listener.dart`.
5. **Arrow Binding**:
   - Arrows anchor dynamically to edges of shapes via Chebyshev (box) and radial (circle) bounds (`binding_service.dart`).

### B. Persistence & Migration Contract
- **Isar Database Collections**:
  - `Notebook`, `NotePage`, `Folder`
  - `SceneElementRecord` (one row per canvas element; enables incremental autosave)
  - `PageTextRecord`, `FlashcardRecord`, `StudyPlanRecord`, `ConceptMasteryRecord`, `NoteChunkRecord`, `LectureRecordingRecord`
- **Data Migration (`SceneMigratorV2`)**:
  - Automatically migrates legacy 1.x `.ink` stroke files and embedded shape records to `SceneElementRecord`.
  - Gated by `AppMeta.schemaVersion`. Old data files are kept untouched as a non-destructive rollback source.

### C. On-Device AI Tutor & Intelligence Architecture
1. **Handwriting Recognition Pipeline**:
   - Raw strokes are grouped into lines by Y-centroid proximity.
   - Normalized to a canonical 32px cap-height before passing to ML Kit (zoom-independent).
   - Underlines/ruled lines are separated; table columns are split and processed individually.
   - Recognizer receives `preContext` to resolve ambiguous characters against sentence context.
2. **On-Device RAG ("Ask Your Notes")**:
   - Pages are chunked (`note_chunk_record.dart`) and embedded locally with **EmbeddingGemma 300M**.
   - Queries are resolved via `AiScope` (current page, imported PDF group, or whole notebook).
   - Grounded answering: The tutor answers strictly from retrieved context and refuses cleanly if the topic is absent.
3. **Tutor Voice & Formatting**:
   - Unified Socratic persona (`kTutorVoice`) across Ask, Explain, and Summarize.
   - LaTeX conventions: `$formula$` for inline, `$$formula$$` for display blocks, rendered with `flutter_math_fork`.
4. **Quality Guard (`AiQualityGuard`)**:
   - Analyzes local output for truncation, loops, or gibberish. Automatically retries or escalates to the cloud gateway.
5. **Knowledge Graph & Study Planner**:
   - Automatically identifies concepts and links them into a graph of learning states: `learning` $\rightarrow$ `practiced` $\rightarrow$ `mastered`.
   - Surfaces "knowledge gaps" (concepts mentioned in notes but never defined).
   - Generates deterministic spaced-repetition study countdowns without requiring model downloads or cloud calls.

---

## 5. Development Guidelines & Invariants

1. **State Management**:
   - Use Riverpod `Notifier` / `AsyncNotifier` / `StateNotifierProvider`.
   - Keep widget trees lean and avoid `setState` across architectural boundaries.
   - Never reintroduce `get_it` or static mutable singletons.
2. **Canvas Performance**:
   - Target 60fps on mid-range tablets under concurrent drawing and viewport transformations.
   - Avoid memory allocations inside `CustomPainter.paint` loops.
3. **Data Safety**:
   - **Never delete user notes or mutate Isar schemas** without an explicit versioned migrator in `lib/data/migration/`.
   - Always verify that old `.ink` files and Isar collections remain backward-compatible.
4. **Privacy First**:
   - All AI features default to on-device processing.
   - No notes or data ever leave the device unless the user explicitly triggers a cloud-badged feature.
5. **Code Quality & Testing**:
   - Keep `flutter analyze` completely clean (0 warnings, 0 errors).
   - Keep all unit and widget tests passing (`flutter test`).
