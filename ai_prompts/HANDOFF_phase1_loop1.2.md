# Session Handoff — Phase 1 after Loop 1.2

> Plan of record: `INTEGRATION_ROADMAP.md` (§5 feature roadmap). Phase spec:
> `02_phase1_context_engine_core_features.md`. Durable log: `../AI_PROGRESS.md`
> (read it first — this file is the fast path, that file is the full record).
> Branch: **Inkdot-2.0** (canonical; `main` is frozen). Both loops below are
> committed AND pushed.

## 0. DECISIONS PENDING NABIL'S INPUT (do not build past these without asking)
- **Loop 1.5 (Writing Assistant) — STOP CONDITION.** Phase spec §5: if the
  non-intrusive UI risks feeling like a nagging linter, *show Nabil a
  mockup/description before wiring it in broadly.* Do not ship intrusive
  inline markers unprompted.
- **Loop 1.7 (Flashcards export) — STOP CONDITION.** Confirm export approach
  (a plain-SQLite `.apkg` vs CSV-only first) *before* adding a dependency.
- **Device validation (R5) — Nabil-owned, still OPEN.** Runbook in
  `AI_PROGRESS.md §R5`. The Context Engine rides the same ML Kit + Gemma path,
  so validating Summarize also validates the engine. No Android device was
  attached this session.
- **Afnan handoff (decision #5) — still pending Nabil.** Tell Afnan `main` is
  frozen; all AI work targets `Inkdot-2.0`.

---

## 1. TL;DR
- **Status:** Platform (Phases R+U) complete; **Phase 1 in progress** — the
  Live Context Engine is built and visible in the editor.
- **Done this session:** Loop 1.1 (Context Engine core) + Loop 1.2 (AI Sidebar
  shell). Both committed, pushed, 319/319 tests green, analyze clean.
- **Next:** Loop 1.3 — Summarization at selection / page / notebook scope,
  launched from the sidebar, chunk-and-reduce for long notebooks.
- **Blocked/waiting:** nothing blocks 1.3–1.4. 1.5 and 1.7 have STOP CONDITIONS
  (see §0). Device validation is Nabil-owned.

## 2. Completed This Session

### Loop 1.1 — Live Context Engine core — `cb5ab8b`
Debounced background read that turns a page's `PageContent` into a structured
`PageContext` (topic, subtopics, keyConcepts, namedEntities, definitions,
knowledgeGaps, `estimatedLevel` enum, `confidence`). One greedy structured-output
call to the local `AiProvider` behind a **robustness ladder** (see §3): strict
schema system prompt → balanced-brace JSON extraction → one stricter retry →
`PageContext.empty` fallback. Malformed output never throws; provider failures
(`AiException`) propagate. `ContextEngineNotifier` (`StateNotifier<AsyncValue
<PageContext>>`) debounces ~2.5s after the last scene change, skips re-analysis
via a content signature, caches the last good result per page, and does not
retry a failed run until content changes or `refresh()`. Wired as an
`autoDispose.family` provider that observes the editor **read-only**.
**Verify:** +30 tests → 314/314, `flutter analyze` clean.

### Loop 1.2 — AI Sidebar shell — `91ec582` (pushed)
The in-editor home for the engine and launch surface for the rest of Phase 1.
App-bar toggle (`Icons.psychology_outlined`) docks a 340px panel beside the
canvas on tablet width (`Row` → `Expanded` canvas + fixed panel) and opens a
bottom sheet on phone width — both wrap the same `AiContextView`. The view
renders every state of `pageContextProvider`: reading / empty / ready
(topic + 3-segment level bar + concept chips + honey-toned gap flags +
definitions) / model-not-ready (inline one-time download → `refresh()`) /
gentle generic retry. Keeps last good context on screen during re-analysis
(no spinner flicker). Panel is `autoDispose`, so the engine runs only while
open.
**Verify:** +5 widget tests → 319/319, `flutter analyze` clean.

## 3. Established Patterns & Conventions (extend these; don't re-invent)

- **Robustness ladder for structured model output** (reuse for Quiz 1.6 and any
  JSON feature): strict schema in the *system* prompt → `AiGenerationOptions
  (temperature: 0.0, maxTokens: 512)` (greedy; small models emit valid JSON far
  more reliably ungreedy-off) → `ContextEngine.tryExtractJsonObject` (balanced-
  brace scan that strips markdown fences/prose and honors string literals +
  escapes) → one stricter retry with a "JSON only" nudge → tolerant
  `fromJson` (missing/mistyped fields fall back to defaults, never throw) →
  `.empty` fallback. **Malformed model output never throws; real provider
  failures (`AiException`) DO propagate** for the caller to surface.
- **Value objects parse defensively.** `PageContext.fromJson` clamps
  `confidence` to 0..1, lowercases the level enum, drops non-string/blank list
  and map entries. Model JSON is never trusted to be well-shaped.
- **Debounce + content-signature caching** for anything that watches the page:
  ~2.5s after the *pause* (not per stroke; injectable for tests), skip when a
  content signature is unchanged, per-page **session** cache (durable
  persistence is Phase 2 Learning Memory), no-retry-on-failure until content
  changes or `refresh()`.
- **Signature semantics** (`sceneContentSignature`): pure geometry *moves* of
  ink do NOT invalidate (recognition is translation-invariant) but text edits
  AND text moves DO (text position feeds reading order). Deliberate.
- **AI features observe the editor read-only.** Pattern: `autoDispose.family`
  provider keyed by `ScenePageKey`, `ref.listen(sceneControllerProvider(key),
  …, fireImmediately: true)` inside the provider body. Never modify editor
  code. `sceneControllerProvider(key)` is the live scene the canvas mutates
  through (see Gotchas — its "not wired" comment lies).
- **Word budgeting is centralized — never hardcode.** `text_budget.dart`
  (`countWords` / `truncateToWords`) + `AiRouter.inputWordBudgetFor(caps)`
  (static). Budget = `(contextWindowTokens − 512 response − 200 scaffolding)
  / 1.35 words`. A model swap re-budgets everything automatically.
- **Sidebar is the anchor.** Every Phase 1 feature launches FROM it (or from a
  selection action). Constants `kAiSidebarWidth = 340`, `kAiSidebarBreakpoint
  = 720`. Reuse the "one body (`AiContextView`-style) + two chrome wrappers
  (docked panel / bottom sheet)" split.
- **Study aid, not a linter.** Gaps render honey-toned (`AppColors.accentYellow
  Wash`), never red. Design tokens come from `AppColors` (warm coral/cream).
- **Generation presets:** structured extraction = temp 0.0 / 512 max;
  summarization = temp 0.2 / topP 0.95 / 512 max.
- **Test conventions:** descriptive fakes; scripted providers record their
  inputs (`prompts`/`options` lists); mirror `test/features/ai/…` layout;
  widget-test a provider by overriding the family instance
  (`p(key).overrideWith((ref) => FixedNotifier(state))`).

## 4. Immediate Next Step — Loop 1.3 (Summarization levels)

**Spec (verbatim from `02_phase1_…md §3 Loop 1.3`):**
> - Levels: selected text/strokes, current page, whole notebook (multi-page —
>   iterate `PageContentExtractor` across pages in a notebook, respect a
>   reasonable token budget, and chunk if needed — don't naively concatenate an
>   entire notebook into one prompt against a small on-device model's context
>   window).
> - `lib/features/ai/domain/features/summarizer.dart` + presentation entry
>   point (button in AI Sidebar + a context menu action on text/lasso
>   selection, integrating with the existing `selection_notifier.dart`/`lasso`
>   selection system as a read-only consumer).
> - Respect `AiCapabilities.contextWindow` from the provider — if a
>   summarization request would exceed it, chunk-and-reduce (summarize chunks,
>   then summarize the summaries) rather than truncating silently.

**Context to reconcile:** a `SummarizationService` already exists
(`features/summarize/domain/services/`) doing whole-notebook summarize with
gate + cache + router + cloud fallback, but it **truncates** over-budget input
rather than chunk-and-reducing, and its only entry point is the app-bar button
(`notebook_editor_screen._startSummarize`). Loop 1.3 should add scope selection
(selection / page / notebook), chunk-and-reduce, and a sidebar launch — decide
whether to extend `SummarizationService` or add `domain/features/summarizer.dart`
on top of it (prefer extending; don't duplicate the gate/cache/routing).
Selection scope needs a read-only consumer of the editor's selection system
(`lib/editor/state/selection_controller.dart` — verify the exact provider/API).

**Acceptance criteria:** Summarize works at selection, page, and notebook
scope; content over the local context window is chunk-and-reduced (not silently
truncated); launchable from the AI sidebar; `flutter analyze` clean; new tests
under `test/features/ai/…` (or summarize/); `AI_PROGRESS.md` updated; commit.

## 5. Remaining Backlog (in order)
1. **Loop 1.3 — Summarization levels** (selection/page/notebook + chunk-reduce).
2. **Loop 1.4 — Explain** (selection → Beginner/Intermediate/Advanced/Real-world
   modes, streamed into sidebar, "insert as note" via the editor's existing
   text-insertion path).
3. **Loop 1.5 — Writing Assistant.** ⚠️ STOP CONDITION — show Nabil the UI
   approach before wiring broadly. Typed text only initially; share the
   Context Engine debounce, don't add a second polling loop.
4. **Loop 1.6 — Quiz Generator** (MCQ + True/False minimum, gradeable; reuse the
   robustness ladder for structured `QuizQuestion` JSON; difficulty from
   `PageContext.estimatedLevel`; coding questions only when topic is programming).
5. **Loop 1.7 — Flashcards.** ⚠️ STOP CONDITION — confirm CSV vs `.apkg` export
   before adding a dependency. Isar `@collection` (this one IS persistent).
- Phase 1 DoD: all features work fully offline; per-loop analyze/test/log.

## 6. Open Questions / Decisions Pending (mirror of §0)
- 1.5 Writing Assistant UI — needs mockup sign-off before broad wiring.
- 1.7 Flashcards export — CSV-first vs `.apkg` (SQLite) — needs a call.
- Device validation (R5) — Nabil-owned, still open.
- Afnan handoff (decision #5) — Nabil to notify.

## 7. Gotchas (discovered this session)
- **`flutter_riverpod` 2.5.1: `AsyncValue.hasError`, `.error`, and the
  `AsyncData/AsyncError/AsyncLoading` types are EXTENSION members** (`AsyncValueX`).
  A test file that inspects them must
  `import 'package:flutter_riverpod/flutter_riverpod.dart'` or they're invisible.
  (`.value` is a direct getter and works without the import — misleading.)
- **Flutter text finders don't traverse raw `RichText`.** `find.text` /
  `find.textContaining` only match `Text`/`EditableText`. Use `Text.rich(...)`
  so `textSpan.toPlainText()` is matched. (Cost us one red test.)
- **`scene_controller.dart` header comment is STALE** — it says "not yet wired
  into the running editor," but `scene_canvas.dart` reads and mutates through
  `sceneControllerProvider(key)` everywhere. The Context Engine's live updates
  depend on this being true; don't "fix" the editor to bypass it.
- **Context Engine debounce is 2.5s in prod but injectable.** Tests use 5ms +
  a 60ms settle; don't assert against wall-clock prod timing.
- Working tree always has untracked `.claude/`, `.vscode/`, `ios/`,
  `logcat_dump.txt` — never `git add` them; stage files explicitly.

## 8. File Map (created/modified this session)
- `lib/features/ai/domain/context_engine/page_context.dart` — `PageContext`
  value object + tolerant `fromJson`. **NEW**
- `lib/features/ai/domain/context_engine/context_engine.dart` — `analyze()` +
  the robustness ladder + `tryExtractJsonObject`. **NEW**
- `lib/features/ai/domain/text_budget.dart` — shared `countWords` /
  `truncateToWords`. **NEW**
- `lib/features/ai/presentation/context_engine_notifier.dart` —
  `ContextEngineNotifier`, `PageContextCache`, `sceneContentSignature`. **NEW**
- `lib/features/ai/presentation/sidebar/ai_context_view.dart` — state-by-state
  render of the live context. **NEW**
- `lib/features/ai/presentation/sidebar/ai_sidebar.dart` — docked panel +
  bottom-sheet chrome + breakpoint constants. **NEW**
- `lib/features/ai/domain/ai_router.dart` — added static `inputWordBudgetFor`.
- `lib/features/ai/presentation/ai_providers.dart` — `contextEngineProvider`,
  `pageContextCacheProvider`, `pageContextProvider` (autoDispose.family +
  read-only `ref.listen`).
- `lib/features/summarize/domain/services/summarization_service.dart` — now
  delegates word helpers to `text_budget.dart`.
- `lib/editor/ui/notebook_editor_screen.dart` — AI app-bar toggle + `Row` body
  hosting the docked panel; `_toggleAiPanel`.
- `test/features/ai/domain/context_engine/page_context_test.dart` — parse/clamp
  /drop-junk. **NEW**
- `test/features/ai/domain/context_engine/context_engine_test.dart` — ladder
  paths + brace-scanner edges. **NEW**
- `test/features/ai/presentation/context_engine_notifier_test.dart` — debounce
  /cache/signature/failure-no-retry. **NEW**
- `test/features/ai/presentation/ai_context_view_test.dart` — sidebar render
  states. **NEW**
- `AI_PROGRESS.md` — Loops 1.1 + 1.2 recorded; "Next Loop" = 1.3.
