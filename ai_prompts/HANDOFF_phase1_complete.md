# Session Handoff — Phase 1 COMPLETE (all of Loops 1.1–1.7)

> Plan of record: `INTEGRATION_ROADMAP.md` (§5 feature roadmap). Phase spec:
> `02_phase1_context_engine_core_features.md`. Durable log: `../AI_PROGRESS.md`
> (read it first — this file is the fast path into a new session; that file is
> the full per-loop record and is kept current). Branch: **Inkdot-2.0**
> (canonical; `main` is frozen, 7 commits behind and not to be touched). Every
> commit below is committed AND pushed to `origin/Inkdot-2.0`.
>
> This file supersedes `HANDOFF_phase1_loop1.2.md` (now stale — kept only as a
> historical record of the Loop 1.1/1.2 handoff; do not follow its "Immediate
> Next Step" section, it describes Loop 1.3 which is long done).

---

## ⏱ UPDATE — 2026-07-17 (read first; supersedes §0/§4 below)

Nabil resolved the three "what's left" items and one new feature shipped:

- **`.apkg` flashcard export — DONE.** Loop 1.8 shipped a real SQLite-backed Anki
  deck (`.apkg`) **and** a richer directive-CSV (named deck + auto field-mapping),
  both offline and host-tested. Deps: `sqlite3` (native assets) + `archive`; the
  EOL `sqlite3_flutter_libs` was deliberately not used; `.apkg` degrades to CSV
  on any failure. See `AI_PROGRESS.md` "Loop 1.8".
- **Afnan handoff — DONE.** Nabil confirmed Afnan is informed and his code is
  merged into Nabil's; Nabil's pushes are canonical. No action remains.
- **Device validation — blocker LIFTED, still Nabil-owned.** Nabil now runs an
  Android Studio emulator + a Xiaomi Pad. The on-device DoD pass — now also
  covering the `.apkg`/CSV Anki import round-trip and confirming the
  native-assets Android build bundles sqlite3 — is the remaining Phase-1
  close-out.
- **Versioning:** bumped to **2.0.0** on a new branch off `Inkdot-2.0`; **every
  push now bumps the pubspec version** (manual — the auto-bump workflow only runs
  on the frozen `main`).
- Tests now **421/421**, `flutter analyze` clean.

The sections below are the original handoff, kept for context.

---

## 0. DECISIONS PENDING NABIL'S INPUT (do not build past these without asking)

Both of Phase 1's STOP CONDITIONS were already raised and resolved this build
— **no open STOP CONDITIONS remain in Phase 1.** What's still open is
Nabil-owned and non-codeable, or a genuinely new decision for whatever comes
next:

- **Device validation (R5 + Phase 1 DoD) — Nabil-owned, still OPEN.** No
  Android device/emulator has been attached in any session so far; nothing in
  `features/ai` has run on real hardware. Runbook: §4 below and
  `AI_PROGRESS.md`'s "Next Loop" section.
- **`.apkg` flashcard export — logged fast-follow, not started.** Loop 1.7
  shipped CSV-only per Nabil's explicit call (STOP CONDITION resolved via
  AskUserQuestion: "CSV first"). A `.apkg` (SQLite-backed Anki deck) importer
  would need a maintained plain-SQLite Dart package vetted first — nothing
  chosen yet.
- **Afnan handoff (decision #5) — still pending Nabil.** Tell Afnan `main` is
  frozen; all AI work targets `Inkdot-2.0`. This is a communication task, not
  a coding task — do not act on it from a coding session.
- **What comes after Phase 1 — genuinely open.** The three items above are
  the only *documented* remaining Phase 1 work; the natural next body of work
  is Phase 2 (Learning Memory / RAG / Knowledge Graph / Study Planner, see
  §5), but **it has not been requested**. Do not start Phase 2 loops, the
  `.apkg` work, or any other new feature without the user explicitly saying so
  — the correct move on entering a fresh session is to summarize this file and
  ask what's next, the same way the original phase-1 kickoff worked.

---

## 1. TL;DR

- **Status: Phase 1's entire coded feature set is DONE.** Platform (Phases
  R+U) complete, and all seven Phase 1 loops (1.1 Context Engine → 1.7
  Flashcards) are built, tested, `flutter analyze` clean, committed, and
  pushed.
- **Test count: 400/400 passing.** (Was 319 at the end of the previous
  handoff's Loop 1.2 checkpoint; +81 tests across Loops 1.3–1.7 this build.)
- **No feature code is queued.** Everything left (§0) is hardware-dependent,
  a deferred fast-follow, or a people/communication task — none of it is
  "write more Dart right now" work.
- **If the user says "continue" with no other context:** don't. That
  instruction drove the whole Phase 1 build loop-by-loop in the prior
  session, but there is no next loop to continue into. Ask what they want
  (device validation support, `.apkg`, Phase 2, something else).

## 2. What Shipped (concise — full detail per loop is in `AI_PROGRESS.md`)

| Loop | Feature | Commit | Highlights |
|---|---|---|---|
| 1.1 | Live Context Engine | `cb5ab8b` | Debounced page analysis → `PageContext` (topic/concepts/gaps/level). Establishes the **robustness ladder** every later JSON feature reuses. |
| 1.2 | AI Sidebar shell | `91ec582` | Docked panel (tablet) / bottom sheet (phone) hosting `AiContextView`; the launch surface for everything after it. |
| 1.3 | Summarize (scoped) | `bc06600` | Selection / page / notebook scope; **chunk-and-reduce** replaces silent truncation for over-budget notebooks. |
| 1.4 | Explain | `88b3525` | 7 depth/style modes, streamed into the sidebar, **insert-as-note** via the editor's undoable history path. |
| 1.5 | Writing Assistant | `f1eab4a` | Grammar/clarity/repetition/weak-claim/structure suggestions on typed text. **STOP CONDITION resolved:** sidebar list (Nabil's call over inline markers). Rides the Context Engine's existing debounce — no second timer. |
| 1.6 | Quiz Generator | `7f1287f` | Gradeable MCQ/True-False/fill-blank/coding, difficulty from `PageContext.estimatedLevel`, coding gated on `looksLikeProgramming`. |
| 1.7 | Flashcards | `90ef36a` | **First durable AI artifact** — Isar-persisted deck, definition+LLM merge (definitions win ties), flip-through sheet. **STOP CONDITION resolved:** CSV export only (Nabil's call over `.apkg`). |

All seven ride one platform (`lib/features/ai/`) with one `AiProvider`
contract, one `AiRouter`, one `PageContentExtractor` read path — no feature
duplicated the gate/cache/routing/recognition plumbing.

## 3. Established Patterns & Conventions (apply these to any future loop, Phase 2 included)

- **Robustness ladder for structured model output** (used by Context Engine,
  Writing Assistant, Quiz, Flashcards — reuse for anything JSON in Phase 2):
  strict schema in the *system* prompt → `AiGenerationOptions(temperature:
  0.0, maxTokens: …)` (greedy — small on-device models emit valid JSON far
  more reliably ungreedy-off) → `ContextEngine.tryExtractJsonObject`
  (balanced-brace scan stripping markdown fences/prose, honoring string
  literals + escapes) → one stricter retry with a "JSON only" nudge →
  tolerant `fromJson` (missing/mistyped fields fall back to defaults, drops
  ungradeable/blank entries, never throws) → an `.empty`/`[]` fallback.
  **Malformed model output never throws; real provider failures
  (`AiException`, e.g. `AiModelNotReadyException`) DO propagate** so the
  caller can offer the model download.
- **Value objects parse defensively.** Clamp numeric confidence to 0..1,
  lowercase/normalize enums, drop non-string or blank list/map entries. Model
  JSON is never trusted to be well-shaped.
- **Debounce + content-signature caching** for anything that watches the
  page: ~2.5s after the pause (injectable for tests), skip when a content
  signature is unchanged, per-page **session** cache (durable persistence
  across app restarts is explicitly Phase 2 scope, not Phase 1), no-retry-on
  -failure until content changes or `refresh()`.
- **Don't add a second polling loop.** If a new feature needs "run after the
  page settles," hook into `ContextEngineNotifier`'s existing debounced
  extraction (see `onContent`, added for Writing Assistant) rather than
  building an independent timer.
- **AI features observe the editor read-only.** Pattern: `autoDispose.family`
  provider keyed by `ScenePageKey`, `ref.listen(sceneControllerProvider(key),
  …, fireImmediately: true)` inside the provider body. Never modify editor
  state directly from `features/ai`.
- **Provider lifecycle split:** `autoDispose.family` for passive/live
  features tied to sidebar visibility (Context Engine, Writing Assistant);
  plain `StateNotifierProvider` (session-scoped, survives a sidebar close)
  for anything with an in-flight model download or a user-facing sheet
  (Summarize, Explain, Quiz, Flashcards).
- **Platform layering is a hard invariant.** `features/ai` must never import
  a consumer feature (`features/summarize`, the editor). Sidebar widgets emit
  choice enums or invoke pure `resolveX()` closures; the **editor**
  (composition root, imports both sides) does the actual cross-feature
  wiring. Applied identically across Summarize/Explain/Quiz/Flashcards.
- **Text insertion into the canvas** always goes through the undoable
  history path: `ref.read(historyProvider(key).notifier).push(
  AddElementsCommand([TextElement(...)]))`. The phase-spec's references to
  `text_box_overlay.dart` describe the **legacy** editor; Canvas 2.0 uses
  this instead — documented explicitly so it isn't rediscovered.
- **Word budgeting is centralized — never hardcode.** `text_budget.dart`
  (`countWords` / `truncateToWords` / `chunkByWords`) +
  `AiRouter.inputWordBudgetFor(caps)` (static). A model swap re-budgets every
  feature automatically.
- **Isar conventions:** `@collection` classes, `Id id = Isar.autoIncrement`,
  plain (non-unique) `@Index()` fields. **A collection with two or more
  `@Index()` fields loses `findAll()`/`deleteAll()` off `.where()`** — use
  `.filter()` instead (discovered building `FlashcardStore`; same fix
  previously applied to `SummaryStore`). Schemas are registered in
  `main.dart`'s `IsarService.openDatabase([...])` list; regenerate with
  `dart run build_runner build --delete-conflicting-outputs`.
- **Generation presets:** structured extraction = temp 0.0; summarization =
  temp 0.2/topP 0.95; explain/writing/quiz/flashcard generation = temp
  0.4/topP 0.95. Max output tokens generally 512.
- **Study aid tone, not a linter.** Knowledge gaps and writing suggestions
  render in soft/honey tones, never red-error styling. Design tokens come
  from `AppColors`.
- **Test conventions:** descriptive hand-written fakes (not a mocking
  library) implementing `AiProvider`/`FlashcardStore`/etc. directly; scripted
  providers record `lastPrompt`/`lastSystemPrompt`/`lastOptions`/call counts;
  widget tests override the family/plain provider directly
  (`p(key).overrideWith((ref) => FixedNotifier(state))`); mirror
  `test/features/ai/…` layout 1:1 with `lib/features/ai/…`.
- **Git hygiene enforced all session:** stage files explicitly (never `git
  add -A`/`.`), never touch `main`, commit only at natural loop boundaries,
  push only when explicitly told (in practice: every loop this session was
  told to push).

## 4. What's Actually Left — Nabil-owned, none codeable right now

1. **On-device Phase-1 Definition-of-Done pass** (phase spec §4) — needs a
   real Android device, has never run this build:
   - `flutter run` or install `build/app/outputs/flutter-apk/app-debug.apk`.
   - Context Engine: handwrite a real page, confirm analysis lands ~2–3s
     after a pause and the sidebar shows topic/concepts/gaps/level.
   - Summarize at all three scopes (selection/page/notebook), including a
     notebook long enough to force chunk-and-reduce.
   - Explain in ≥4 modes, confirm streaming feel and insert-as-note placement.
   - Writing Assistant: type prose with a grammar issue, a repeated word, and
     a weak claim; confirm suggestions appear non-intrusively and dismiss
     correctly.
   - Quiz: generate on a real page, confirm MCQ/True-False are valid and
     gradeable; try a programming-topic page to confirm coding questions only
     appear there.
   - Flashcards: generate, confirm the deck persists (kill/reopen the app,
     re-open the same page), export CSV, and actually **import that CSV into
     Anki** to confirm the format round-trips.
   - Everything above must work **fully offline** (airplane mode) after the
     one-time model downloads (ML Kit ~20 MB/language, Gemma 4 E2B ~2.4 GB).
   - This shares the R5 ML Kit + Gemma path end-to-end, so validating
     Summarize alone exercises most of the stack.
2. **`.apkg` flashcard export** (fast-follow to Loop 1.7's CSV) — vet a
   maintained plain-SQLite Dart package before adding the dependency; no
   candidate has been evaluated yet.
3. **Afnan handoff** (decision #5) — Nabil tells Afnan `main` is frozen and
   all AI work now targets `Inkdot-2.0`.

## 5. What Comes After (Phase 2 — NOT started, NOT requested, context only)

Per `INTEGRATION_ROADMAP.md` and `03_phase2_memory_rag_knowledge.md`, the
natural next phase is **Learning Memory + RAG + Knowledge Graph + Study
Planner** — still local-only (Isar, no network, no auth), designed so a
future sync layer *could* attach later without a rewrite:

- **2.1 Learning Memory schema** — `ConceptMastery`, `QuizAttemptRecord`,
  `LearningPreferences` Isar collections; a `LearningMemoryRepository` with
  `weakConcepts()`/`masteredConcepts()`/`dueForReview()`. Wires Phase 1's
  Quiz results and the Context Engine's `knowledgeGaps`/`keyConcepts` output
  into durable mastery tracking for the first time (everything in Phase 1 is
  session-only).
- **2.2 On-device RAG** — chunk `PageContent` with overlap, real embeddings
  (Phase 1 left `AiProvider.embed()` a stub for this reason), brute-force
  cosine similarity over an Isar-stored `NoteChunk` collection (vector DB
  only if profiling proves brute-force isn't enough).
- **2.3 Wire RAG into existing features** — notebook summarization and a new
  "Ask your notes" sidebar query use retrieval instead of naive
  concatenation once content exceeds the context window.
- **2.4 Knowledge Graph** — extend the Context Engine's structured output
  with `relatedConcepts`, persist as `ConceptRelation` edges, a graph view
  colored by mastery.
- **2.5 Study Planner** — LLM-generated day-by-day plan grounded in real
  `weakConcepts()`/`dueForReview()` data, not generic filler.

**Do not start any of this unprompted.** It's here so a fresh session
understands the shape of "what's next" if the user asks, not as a queued
task list.

## 6. Gotchas (accumulated across the whole Phase 1 build)

- **`flutter_riverpod` 2.5.1: `AsyncValue.hasError`/`.error`/the
  `AsyncData`/`AsyncError`/`AsyncLoading` types are EXTENSION members**
  (`AsyncValueX`). A test file inspecting them needs `import
  'package:flutter_riverpod/flutter_riverpod.dart'` directly or they're
  invisible. (`.value` is a direct getter and works without the import —
  misleading if you assume the others do too.)
- **Flutter text finders don't traverse raw `RichText`.** `find.text` /
  `find.textContaining` only match `Text`/`EditableText`. Use `Text.rich(...)`
  so `textSpan.toPlainText()` is matched.
- **`scene_controller.dart`'s header comment is STALE** — it claims "not yet
  wired into the running editor," but `scene_canvas.dart` reads/mutates
  through `sceneControllerProvider(key)` everywhere, and every AI feature's
  live behavior depends on that being true. Don't "fix" the editor to match
  the stale comment.
- **Dart flow-analysis only promotes local variables, not fields.** A
  nullable callback field (`_onContent`) must be copied to a local (`final
  onContent = _onContent;`) before a null-check makes the call site
  analyzer-clean — `unchecked_use_of_nullable_value` otherwise (hit building
  the Writing Assistant hook).
- **Isar `.where()` on a collection with 2+ `@Index()` fields silently loses
  `findAll()`/`deleteAll()`.** Symptom is an `undefined_method` analyze
  error, not a runtime failure. Fix: use `.filter()` instead (see
  `FlashcardStore`, and previously `SummaryStore`).
- **Context Engine debounce is 2.5s in prod but injectable** — tests use 5ms
  + a short settle; never assert against wall-clock prod timing.
- Working tree always has untracked `.claude/`, `.vscode/`, `ios/`,
  `logcat_dump.txt`, and now also `ai_prompts/HANDOFF_phase1_loop1.2.md` (the
  superseded handoff) — never `git add -A`/`.`; stage files explicitly by
  name every time.
- **No Android device or emulator has been attached in any session so far.**
  Every "not device-run" note across Loops 1.1–1.7 is real, not boilerplate
  caution — literally nothing in `features/ai` has executed on hardware yet.

## 7. Where To Look For More Detail

- **`AI_PROGRESS.md`** — the full record: every loop has its own dated
  section with the complete file list, design rationale, and test deltas.
  This handoff intentionally does not repeat the per-file diff list (it's
  ~500 lines and would just go stale faster than the source of truth).
- **`INTEGRATION_ROADMAP.md`** — plan of record / phase sequencing.
- **`02_phase1_context_engine_core_features.md`** — the Phase 1 spec this
  build implemented against, including the full DoD checklist referenced in
  §4 above.
- **`03_phase2_memory_rag_knowledge.md`** — the Phase 2 spec summarized in §5.
