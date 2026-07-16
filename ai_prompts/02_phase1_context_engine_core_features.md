# InkFlow AI Integration — Phase 1: Live Context Engine + Core AI Features

You are continuing the AI integration of **InkFlow**, a Flutter ink-canvas notebook app. **Phase 0 (foundation) must be complete before this prompt is used.** Read `AI_PROGRESS.md` in full before doing anything else — it tells you what provider abstraction, on-device model runtime, and handwriting-to-text pipeline already exist. Do not re-derive or second-guess those decisions in this phase; build on top of them.

## 1. Recap of what you're building on (from Phase 0)

- `AiProvider` interface + a working `LocalGemmaProvider` (`lib/features/ai/domain/ai_provider.dart`, `lib/features/ai/data/providers/`).
- `PageContentExtractor` (`lib/features/ai/domain/page_content_extractor.dart`) turns a `NotePage` into a `PageContent` (recognized ink text + typed text + PDF text).
- Everything is local-first, on-device, no network calls.
- Architecture conventions: `lib/features/ai/{domain,data,presentation}`, Riverpod, get_it, Isar. Do not touch editor core.

## 2. What this phase is for

Turn raw page content into structured understanding (the Context Engine), then build the first set of AI features on top of it: Summarize, Explain, Writing Assistant, Flashcards, Quiz Generator. This is the phase where InkFlow starts to feel like it has a tutor watching over your shoulder — but everything here still runs on-device (Gemma E2B/E4B). Cloud routing is Phase 3, not this one.

## 3. Loop plan

### Loop 1.1 — Live Context Engine core

`lib/features/ai/domain/context_engine/`:

- `page_context.dart` — the structured output value object:
  - `currentTopic` (String)
  - `subtopics` (List<String>)
  - `keyConcepts` (List<String>)
  - `namedEntities` (List<String>)
  - `definitions` (Map<String, String> — term → definition, only where the note actually states one)
  - `knowledgeGaps` (List<String> — e.g. "term X used but never defined", "section ends mid-thought")
  - `estimatedLevel` (enum: beginner/intermediate/advanced)
  - `confidence` (double — how confident the engine is in this read, since a page with 3 words of ink shouldn't produce a confident topic classification)
- `context_engine.dart` — `Future<PageContext> analyze(PageContent content, {PageContext? previousContext})`. Implementation: one structured-output prompt to the local Gemma provider asking for JSON matching `PageContext`'s shape, with a strict schema description and a fallback parser that degrapes gracefully if the model returns malformed JSON (retry once with a stricter "reply with JSON only" instruction, then fall back to a partial/empty result rather than crashing).
- **Debounced trigger, not polling**: hook into the existing page/canvas notifier (read-only — add a listener, don't modify `canvas_notifier.dart` itself) so analysis runs ~2-3 seconds after the user pauses typing/drawing, not on every stroke. Use a Riverpod `Notifier` (`context_engine_notifier.dart`) that owns a debounce timer and exposes `AsyncValue<PageContext>` for the current page.
- Cache the last `PageContext` per page (in-memory is fine for this phase; persistence comes in Phase 2 as part of Learning Memory) so switching pages and back doesn't re-run analysis unnecessarily.
- **Cost control**: analyzing a page on every pause is fine locally (no API cost), but it still burns battery/CPU. Skip re-analysis if the page content hash hasn't changed since the last run.

### Loop 1.2 — AI Sidebar shell

`lib/features/ai/presentation/sidebar/`:

- A collapsible sidebar/panel (not a modal — this needs to coexist with the editor, likely as a resizable side panel on tablet-width screens and a bottom sheet on phone-width, matching InkFlow's existing responsive patterns if any exist in `tool_bar.dart`/`shape_toolbar.dart`).
- Shows: current detected topic, key concepts as chips, knowledge gaps as gentle inline flags (not red error banners — this is a study aid, not a linter), and a "Learning progress: Beginner/Intermediate/Advanced" indicator.
- This sidebar is the anchor point for every feature added in the rest of this phase (Explain, Quiz, Flashcards all launch from here or from text selection).
- Wire into `app/router.dart` / the existing editor screen as an optional panel, not a new route — it needs to sit alongside the canvas.

### Loop 1.3 — Summarization

- Levels: selected text/strokes, current page, whole notebook (multi-page — iterate `PageContentExtractor` across pages in a notebook, respect a reasonable token budget, and chunk if needed — don't naively concatenate an entire notebook into one prompt against a small on-device model's context window).
- `lib/features/ai/domain/features/summarizer.dart` + presentation entry point (button in AI Sidebar + a context menu action on text/lasso selection, integrating with the existing `selection_notifier.dart`/`lasso` selection system as a read-only consumer).
- Respect `AiCapabilities.contextWindow` from the provider — if a summarization request would exceed it, chunk-and-reduce (summarize chunks, then summarize the summaries) rather than truncating silently.

### Loop 1.4 — Explain

- Modes from the plan doc: Beginner, Intermediate, Advanced, Child, Visual (produce a described diagram/structure, not an actual image yet — image generation isn't in scope), Mathematical, Real-world analogy.
- Triggered from a text/lasso selection or from a "knowledge gap" flag in the sidebar (tapping a flagged undefined term explains it in context).
- One `ExplainRequest { content, mode }` → streamed response rendered in the sidebar, with a "insert as note" action that hands text back to the editor's existing text-insertion path (find the right integration point in `text_box_overlay.dart`'s controller — don't bypass it).

### Loop 1.5 — Writing Assistant

- Continuous, non-interrupting suggestions: grammar, clarity, repetition, weak explanations (a claim made with no supporting detail), missing structure.
- Runs opportunistically off the same debounce trigger as the Context Engine (don't add a second independent polling loop — extend `context_engine_notifier.dart` or add a sibling notifier that shares the same debounce timer) — only against **typed text** initially (ink handwriting-recognition text is noisier; flag ink-derived suggestions as lower-confidence or skip grammar-level nitpicks on it and stick to content-level ones).
- Present as small, dismissible, non-blocking inline markers — this must never interrupt the writing flow. If you can't find a non-intrusive UI pattern that fits InkFlow's existing visual language, stop and ask rather than bolting on an intrusive one.

### Loop 1.6 — Quiz Generator

- Types: MCQ, True/False, Fill-in-the-blank, coding challenges (only offer coding challenges when the page's detected topic/entities suggest programming content — don't generate them for a history notebook).
- Difficulty: easy/medium/hard, informed by `PageContext.estimatedLevel`.
- `lib/features/ai/domain/features/quiz_generator.dart` generates structured `QuizQuestion` objects (question, options if applicable, correct answer, explanation) — structured JSON output from the local model, same schema-with-fallback approach as Loop 1.1.
- Simple quiz-taking UI (new screen or sheet) that scores the attempt. Store the raw result in a lightweight local structure for now — the durable "quiz score history" schema belongs to Phase 2 (Learning Memory); don't build persistence twice.

### Loop 1.7 — Flashcards

- Auto-generate flashcards from `PageContext.keyConcepts` and `definitions`.
- `lib/features/ai/domain/models/flashcard.dart`, Isar `@collection` for storage (this one *is* persistent now — flashcards are a durable artifact, not a transient quiz attempt) under `lib/features/ai/data/`.
- Export to Anki: implement `.apkg` export (it's a SQLite database with a specific schema — use a plain SQLite package, not a heavy Anki-specific dependency if a maintained one doesn't exist; verify current package availability before committing to one) or, if that proves too heavy for this loop, ship CSV export first (Anki can import CSV) and flag `.apkg` as a fast-follow in `AI_PROGRESS.md`.

## 4. Definition of Done for Phase 1

- [ ] Context Engine produces a `PageContext` for the active page within ~2-3s of the user pausing, without blocking the UI thread.
- [ ] AI Sidebar shows live topic/concepts/gaps/level and is the working entry point for every feature below.
- [ ] Summarize works at selection, page, and notebook scope, with chunking for content exceeding the local model's context window.
- [ ] Explain works in at least Beginner/Intermediate/Advanced/Real-world-analogy modes with streamed output.
- [ ] Writing Assistant surfaces at least grammar + clarity + repetition suggestions on typed text, non-intrusively.
- [ ] Quiz Generator produces valid, gradeable MCQ and True/False questions from real page content.
- [ ] Flashcards are generated, stored in Isar, and exportable (CSV minimum, `.apkg` if feasible).
- [ ] All of the above still work fully offline.
- [ ] `AI_PROGRESS.md` updated per loop; `flutter analyze` clean; tests added under `test/features/ai/...`.

## 5. Stop conditions

- If Writing Assistant's UI risks feeling intrusive (this is the single biggest way to make a "personal professor" feel like a nagging linter) — pause and show the user a mockup/description before wiring it in broadly.
- If on-device generation latency for any feature exceeds a few seconds in a way that breaks the "invisible assistant" feel, flag it rather than shipping a sluggish feature silently.
- Before choosing the Anki export approach (SQLite dependency vs. CSV-only).

Stop at Definition of Done and report. Phase 2 (`03_phase2_memory_rag_knowledge.md`) is a separate session.
