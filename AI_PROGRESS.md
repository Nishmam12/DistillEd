# AI Integration Progress Log

Durable memory for the AI integration work. Every loop reads this first and
updates it last. The plan of record is `ai_prompts/INTEGRATION_ROADMAP.md`
(which supersedes the phase-0 prompt's build-from-scratch assumptions); the
product vision remains `ai_prompts/AI_Notebook_Master_Plan.md`.

## Current Phase
**Phases R + U COMPLETE; Phase 1 IN PROGRESS.**
One AI platform (`features/ai/`) with one runtime, one router, one page-read
path. Phase 1 builds the master-plan features on it, **Live Context Engine
first** (decision #7) per `ai_prompts/02_phase1_context_engine_core_features.md`
+ INTEGRATION_ROADMAP §5. Loops 1.1 (Context Engine core), 1.2 (AI Sidebar
shell), 1.3 (Summarize levels), 1.4 (Explain) and 1.5 (Writing Assistant —
sidebar-list UI, Nabil-approved) done; next is Loop 1.6 (Quiz Generator).
Device validation (R5) is still open, owned by the user.

## The situation (context for any fresh session)
On 2026-07-16 we discovered Afnan had already shipped a complete AI
summarization feature (`lib/features/summarize/`, commit `0d97290`) on
`origin/main` — built on the **legacy editor**, unaware of the Inkdot-2.0
`SceneElement` rewrite. Both devs independently picked the identical stack
(flutter_gemma 1.3.0 + litertlm + ML Kit digital ink + Gemma 4 E2B), so the
runtime choice is settled and validated. Decisions locked with Nabil:
Inkdot-2.0 is canonical; Afnan's AI is **ported** here (not branch-merged);
one shared AI platform (Phase U) before any new feature; first feature after
the platform is the **Live Context Engine**; `main` is frozen → retired after
Phase R; Nabil owns R+U, Afnan moves to Inkdot-2.0 afterward.

## Decisions Locked In
- Local-first. Cloud = `CloudLlmClient` no-op stub, opt-in flag default OFF,
  real provider not before Phase 3.
- Isar remains the only on-device store (plus `SummaryCache` collection).
- Platform: Android-first; `ios/` exists but is not a blocker.
- DI: pure Riverpod (get_it is in pubspec but unused — follow repo reality).
- On-device runtime: **flutter_gemma 1.3.0 + flutter_gemma_litertlm 1.1.0**
  (LiteRT-LM engine, opt-in engine registration), model **Gemma 4 E2B**
  `.litertlm` (~2.4 GB) from litert-community (ungated — no HF token needed).
  Lazy engine init (`GemmaBootstrap.ensureInitialized`), load→generate→unload
  lifecycle with a mutex so at most one model is resident.
- Handwriting: **google_mlkit_digital_ink_recognition 0.15.0** (on-device,
  ~20 MB/language, en/bn), stroke-based with timestamp synthesis/rebasing.
- `AiProvider` abstraction (Loop 0.1, `lib/features/ai/domain/`) is the
  platform seam every provider implements from Phase U onward.

## Dependencies added (with justification)
- `flutter_gemma 1.3.0` + `flutter_gemma_litertlm 1.1.0` (MIT, verified
  publisher) — on-device Gemma inference; chosen over llama.cpp FFI (stale
  package, DIY NDK build, no turnkey GPU). Pinned exact: 1.x API still moving.
- `google_mlkit_digital_ink_recognition 0.15.0` — on-device stroke-based
  handwriting recognition (not image OCR); offline after model download.
- `crypto ^3.0.7` — SHA-256 of recognized text for the summary cache key.
- `shared_preferences ^2.5.5` — flutter_gemma requirement + settings persistence.

## Completed Slices

### Loop 0.1 — AI provider abstraction ✅ (`8defafb`)
`lib/features/ai/domain/`: `AiProvider` (streaming `generate`, `embed`,
`AiCapabilities`), `AiMessage`/`AiRole`, `AiGenerationOptions`, sealed
`AiException` hierarchy. Tests in `test/features/ai/domain/`. This is the
Phase U platform contract — unchanged by the reconciliation.

### Phase R1–R2 — Port Afnan's portable AI layer ✅
Ported verbatim from `origin/main` (`git checkout origin/main -- ...`), zero
code changes needed, `flutter analyze` clean, **255/255 tests pass**:
- `lib/features/summarize/` complete: `data/llm/` (GemmaBootstrap, seams
  `ModelInstaller`/`LlmRuntime`/`LlmSession`, `LocalLlmService`
  load→generate→unload+mutex, `ModelDownloadManager` with StatFs free-space
  check + progress + cancel, `DeviceStorage`), `data/cache/` (Isar
  `SummaryCache`, SHA-256 keyed store), `domain/` (`AiRouter` decision table,
  `MeaningfulnessGate`, `SummarizationService`, `recognition_result`),
  `presentation/` (state-machine notifier, providers, bottom sheet).
- `StrokePoint.t` (nullable capture-time ms, omitted-when-null serialization)
  — file was otherwise identical across branches; shared by legacy `Stroke`
  AND `FreehandElement` (both use the same `StrokePoint`), so 2.0 benefits
  directly.
- Native infra: `MainActivity.kt` StatFs MethodChannel
  (`com.inkflow.inkflow/storage`), `AndroidManifest.xml` (download
  permissions, Android 14+ dataSync foreground service merge, optional OpenCL
  `uses-native-library` for GPU).
- `main.dart`: `SummaryCacheSchema` added to the Isar open list.
- All of Afnan's tests ported (`test/features/summarize/`,
  `stroke_point_serialization_test.dart`).
- Discarded: Nabil's uncommitted Loop 0.2 WIP (own GemmaModelManager /
  LocalGemmaProvider / ai_bootstrap) — superseded by Afnan's equivalent,
  more complete runtime.

### Phase R3 — SceneElement input path ✅
The 2.0 pipeline now feeds recognition-quality ink to the ported feature:
- **`StrokePoint.t` persists through 2.0 storage.** Both persistence paths
  packed points positionally as [x,y,pressure] and silently dropped `t`;
  fixed with a parallel `pointT` list (−1 = unknown; empty/absent = legacy),
  mirroring the existing `pointSim` pattern: `SceneElementRecord.pointT`
  (Isar, additive auto-migrating field, .g.dart regenerated) +
  `SceneElementRecordMapper` + `SceneElementCodec` (library/clipboard JSON).
- **`t` captured at input**: `scene_pointer_listener._extractPoint` now sets
  `t: event.timeStamp.inMilliseconds` (Afnan's exact approach — monotonic
  engine clock, deltas-only semantics).
- **`SceneNotebookInkLoader`** (`features/summarize/data/`): pages via
  `PageRepository.getPagesForNotebook` (pageIndex order), elements via
  `SceneElementStore.loadForPage`, `FreehandElement` → `Stroke` field-for-field
  (same `StrokePoint`s, `t` flows untouched). Deliberate seam: keeps ALL of
  Afnan's service signatures and tests unchanged; Phase U's
  PageContentExtractor replaces it SceneElement-native.
  Provider: `sceneNotebookInkLoaderProvider`.
- Legacy `raw_pointer_listener`/`canvas_widget` confirmed dead code on this
  branch (no importers) — not touched.
- Tests: mapper/codec t round-trips + legacy-row null decode, loader
  (adaptation, ordering, empty pages), listener t monotonicity.
  `flutter analyze` clean, **263/263 tests pass**.

### Phase R4 — Editor entry point + settings ✅
- `settings_provider.dart`: taken wholesale from main (base was identical) —
  adds persisted `cloudAiEnabled` (default OFF) + `recognitionLanguage`
  (en/bn) via shared_preferences.
- `settings_screen.dart`: taken from main (AI + AI Models sections: cloud
  toggle, language pills, model install-status rows with delete), then the
  2.0-only "Canvas 2.0 (dev)" Developer row re-added — that row was the only
  divergence between the branches' settings screens.
- `notebook_editor_screen.dart` (editor 2.0): Summarize app-bar action →
  `SummarizeRequest(loadPages: sceneNotebookInkLoader.loadPagesStrokes(...))`
  → `showSummarySheet`. No current-page special-casing needed: the 2.0 scene
  store is written through on every mutation, so the store is always fresh
  (unlike main's legacy editor, which had to read the live canvas state for
  the current page).
- `flutter analyze` clean, **263/263 tests pass**.

### Phase R5 — Build proof ✅ / device validation ⏳ (blocked on hardware)
Automated portion done (2026-07-16, no Android device/emulator attached):
- `flutter build apk --debug` **succeeds** (302.5 s): LiteRT-LM android_arm64
  native libs auto-downloaded + checksum-verified by flutter_gemma's build
  hook, manifest merge + minSdk OK. Non-blocking warning: several plugins
  (flutter_gemma, mlkit, pdfx, share_plus, package_info_plus) still apply KGP;
  future Flutter versions will require updated plugins.
- Privacy grep gate **passes**: no `http`/`dio`/`HttpClient` anywhere in
  `lib/`; network use is exclusively model downloads (plugin-side) and the
  router's DNS reachability probe (no note content).
- 263/263 tests, analyze clean.

**Remaining — needs a physical Android device (steps for whoever runs it):**
1. `flutter run` (or install `build/app/outputs/flutter-apk/app-debug.apk`).
2. Settings → check the AI + AI Models sections render; leave Cloud AI OFF.
3. Open a notebook (editor 2.0), handwrite ~3–5 sentences of real notes.
4. Tap the ✨ Summarize app-bar button → expect: "en" ML Kit model (~20 MB)
   downloads inside the "Reading handwriting…" state; then an error state
   offering the Gemma download; tap it → 2.4 GB download with progress
   (foreground-service notification when backgrounded); then recognition →
   summary streams into the sheet.
5. Log HERE: recognition accuracy impression (with real `t` timing), model
   load time, tokens/sec feel, end-to-end latency vs the ~10 s/page target,
   and airplane-mode behavior (expect graceful offline error / local path).

### Phase U1 — LocalGemmaProvider on the platform contract ✅ (`79578e0`)
- `features/summarize/data/llm/` → `features/ai/data/llm/` (platform owns the
  runtime; imports must never point ai→summarize).
- Seams extended: `LlmSession.addTurn` + `respondStream`,
  `LlmRuntime.open(systemInstruction:, randomSeed:)`.
- `features/ai/data/providers/local_gemma_provider.dart`:
  `LocalGemmaProvider implements AiProvider` — streaming generate() with
  history/system mapping, typed `AiException`s, client-side stop sequences
  (cross-chunk hold-back), inter-chunk timeout, load→generate→unload + mutex
  preserved. 12 provider tests.

### Phase U2 — PageContentExtractor + recognition into the platform ✅
- Moves: `handwriting_recognition_service.dart` → `ai/data/handwriting/`;
  `meaningfulness_gate.dart`, `recognition_result.dart` → `ai/domain/`.
- Recognition gains SceneElement-native APIs: `elementsToInk` /
  `recognizeElements` (records-based shared core with the legacy stroke path).
- `ai/domain/page_content.dart` + `page_content_extractor.dart`: THE read
  path for all AI features — ink → recognized text, typed text in reading
  order, images (incl. rasterized PDFs) flagged `needsOcr`, source bounds for
  later "AI is looking at this" UI. Loader-injected (wired to
  `SceneElementStore.loadForPage`), so no persistence coupling.
- `ai/presentation/ai_providers.dart`: platform Riverpod wiring
  (recognition, downloads, `localAiProvider`, `pageContentExtractorProvider`);
  summarize_providers now consumes it.
- 289/289 tests, analyze clean.

### Editor fix — true pixel erase on 2.0 ✅ (`5d9e5a2`)
Port of main's `916e730`: `ScenePixelEraserService` (lib/domain/services/)
cuts real geometry instead of committing BlendMode.clear overlay elements —
freehand splits into surviving sub-elements, cut shapes convert to freehand
outlines, one undoable `PixelEraseCommand`. Matters for AI correctness too:
visually erased ink no longer reaches recognition. The eraser hole Path is
built by the caller with `FreehandPath` (same builder as the preview) so the
domain service stays out of the render layer.

### Phase U3–U4 — capability router + Summarize on the platform ✅
- `ai/domain/ai_router.dart`: the general router — same decision table
  (offline→local; cloud only when online + opt-in + over budget), but the
  local word budget now derives from `AiCapabilities.contextWindowTokens`
  (− 512 response reserve − 200 scaffolding, ÷1.35 tokens/word), so swapping
  the local model re-budgets everything. `Reachability` moved along.
- `SummarizationService` rewritten on the platform: pages read via
  `PageContentExtractor` (**typed text now contributes to summaries**, new
  test), gate owned by the service, local generation via `AiProvider`
  (system prompt through the contract; temp 0.2 / topP 0.95 / 512 max
  output), cloud seam unchanged. `SummarizeRequest.loadPages` →
  `loadPageIds`; editor passes page ids from `PageRepository`.
- **Deleted** (duplication gone): summarize's private `ai_router.dart`,
  `SceneNotebookInkLoader` (+test), `LocalLlmService` (+its test group,
  provider). The runtime is reached ONLY through `LocalGemmaProvider` now.
- `flutter analyze` clean, **284/284 tests pass**.

## Phase 1 — Live Context Engine + core features

### Loop 1.1 — Live Context Engine core ✅
The first feature on the unified platform: a debounced background read that
turns `PageContent` into structured understanding, cached per page.
- `ai/domain/context_engine/page_context.dart`: `PageContext` value object
  (currentTopic, subtopics, keyConcepts, namedEntities, definitions,
  knowledgeGaps, `estimatedLevel` enum, `confidence`). `fromJson` is
  deliberately **tolerant** — missing/mistyped fields fall back to defaults,
  confidence clamped 0..1, level case-insensitive — because a small on-device
  model's JSON is never trusted to be well-shaped. `PageContext.empty` is the
  never-null "nothing to say" value.
- `ai/domain/context_engine/context_engine.dart`: `analyze(PageContent,
  {previousContext})` → one structured-output call to the local `AiProvider`
  (greedy temp 0.0, 512 max out) with a strict JSON schema system prompt.
  Robustness ladder: balanced-brace extraction (`tryExtractJsonObject` — strips
  markdown fences/prose, honours string literals + escapes) → one stricter
  retry → `PageContext.empty` fallback. **Malformed output never throws;
  provider failures (model-not-ready) DO propagate** for the caller to surface.
  Gate-guarded (reuses `MeaningfulnessGate`) and budget-truncated via the new
  shared `text_budget.dart`.
- `ai/presentation/context_engine_notifier.dart`: `ContextEngineNotifier`
  (`StateNotifier<AsyncValue<PageContext>>`). Debounced ~2.5s after the last
  scene change (NOT per stroke); `sceneContentSignature` skips re-analysis
  when the readable content is unchanged (pure geometry moves of ink don't
  invalidate — recognition is translation-invariant — but text edits/moves and
  stroke add/remove do). `PageContextCache` holds the last good context per
  page (session-lifetime; durable persistence is Phase 2 Learning Memory).
  Failed runs aren't retried until content changes or `refresh()` is called,
  so a missing model isn't hammered. Empty pages short-circuit without
  touching recognition or the model.
- Wiring (`ai_providers.dart`): `pageContextProvider` is
  `StateNotifierProvider.autoDispose.family<…, ScenePageKey>` — it observes
  the editor's `sceneControllerProvider(key)` through a **read-only**
  `ref.listen` (the editor never knows the engine exists) and only runs while
  something watches it (the sidebar). `contextEngineProvider`,
  `pageContextCacheProvider` alongside.
- Refactor: extracted `ai/domain/text_budget.dart` (`countWords`,
  `truncateToWords`) shared by the engine and `SummarizationService`;
  `AiRouter.inputWordBudgetFor(capabilities)` is now static so any feature
  budgets with the identical words↔tokens math.
- Tests (+30 → **314/314**, analyze clean): `page_context_test` (tolerant
  parse, clamping, dropped junk), `context_engine_test` (clean/fenced/retry/
  double-malformed/gate/budget/continuity paths + brace-scanner edge cases),
  `context_engine_notifier_test` (debounce coalescing, unchanged-skip, cache
  seed/serve, empty short-circuit, failure-no-retry, `refresh` force,
  signature semantics).

### Loop 1.2 — AI Sidebar shell ✅
The in-editor home for the Context Engine and the launch surface for the rest
of Phase 1. Coexists with the canvas (not a route, not a modal-over-canvas).
- `ai/presentation/sidebar/ai_context_view.dart`: the reusable body that
  watches `pageContextProvider(key)` and renders every state — *reading*
  (spinner), *empty* ("start writing"), *ready* (topic + subtopics, a 3-segment
  Beginner/Intermediate/Advanced level bar, key-concept chips, knowledge-gap
  **honey-toned** flags — a study aid, deliberately NOT red linter errors —
  and page definitions), *model-not-ready* (inline one-time model download with
  progress → `refresh()` on completion), and *generic failure* (gentle "Try
  again"). Keeps the last good context on screen while a re-analysis runs
  underneath (`AsyncLoading` carrying a previous value → no spinner flicker).
- `ai/presentation/sidebar/ai_sidebar.dart`: form-factor chrome — `AiSidebar`
  is a 340px docked right-hand panel for tablet width; `showAiSidebarSheet` is
  the phone-width bottom sheet. Both wrap the same `AiContextView`.
  `kAiSidebarBreakpoint = 720`.
- `notebook_editor_screen.dart`: an app-bar toggle (`Icons.psychology_outlined`,
  selected-state filled) — wide screens dock the panel in a `Row` beside the
  canvas (canvas `Expanded`, panel fixed-width); phone width opens the sheet.
  The editor's `body` Stack moved inside the Row's `Expanded`; toolbar overlay
  unchanged.
- The panel observes the editor **read-only**: `pageContextProvider` is
  `autoDispose.family`, so the engine runs only while the panel is open, and
  it `ref.listen`s `sceneControllerProvider(key)` (the same provider the canvas
  mutates through — confirmed in scene_canvas.dart; scene_controller's "not
  wired" comment is stale) without the editor knowing the engine exists.
- Tests (+5 → **319/319**, analyze clean): `ai_context_view_test` widget tests
  for rich/empty/reading/model-not-ready/generic-error rendering, via a
  fixed-state notifier override of the family provider.

### Loop 1.3 — Summarization levels ✅
Summarize now works at **selection / current-page / whole-notebook** scope, and
over-budget content is **chunk-and-reduced** instead of truncated. Extended the
existing `SummarizationService` (no duplicate gate/cache/routing); did NOT add a
parallel `domain/features/summarizer.dart`.
- `ai/domain/page_content_extractor.dart`: `extractPage` refactored to delegate
  to a private `_extractFrom(elements)`; new `extractSelection(pageId, ids)`
  filters loaded elements to the selected ids and runs the SAME ink-recognition
  + reading-order path — so selection/page reads produce identical `PageContent`
  for the same content.
- `ai/domain/text_budget.dart`: new shared `chunkByWords(text, maxWords)` —
  packs blank-line paragraphs greedily up to the budget, hard-splits any single
  paragraph that alone exceeds it, blank → `[]`, fits → one chunk. Centralized
  so budgeting stays in one place.
- `summarize/domain/services/summarization_service.dart`: sealed
  `SummarizeScope` (`SelectionScope`/`PageScope`/`NotebookScope`) + new
  `summarizeScope(...)`; `summarize(...)` kept as a thin `NotebookScope`
  wrapper (app-bar entry + old tests unchanged). `_gather(scope)` resolves scope
  → (text, ink scores). Local generation replaced truncation with
  `_chunkAndReduce`: summarize each section (`_sectionInstruction`), then
  summarize the joined section summaries (`_reduceInstruction`), recursing while
  the summaries still overflow, with a `_maxReducePasses = 4` safety net that
  falls back to a single truncated reduce for pathologically small windows.
  `SummarizationResult.truncated` → **`chunked`** (whole note read, not cut).
  **Cache stays notebook-only** — page/selection scopes never read or write the
  notebook `SummaryCache` (no Isar schema change; avoids scope collisions).
- `summarize/presentation/summarize_notifier.dart`: `SummarizeRequest.loadPageIds`
  → `resolveScope()` (returns a `SummarizeScope`, resolved fresh per attempt so
  notebook retries see the latest pages; selection is captured at launch).
  `SummarizeSuccess.truncated` → `chunked`. Re-exports the scope types (they're
  part of the request API). Sheet badge: "Long note — partial" → "condensed".
- `ai/presentation/sidebar/ai_sidebar.dart`: a **Summarize** launcher pinned
  below `AiContextView` (both docked panel and phone sheet). It offers *This
  page* / *Whole notebook* always and *Selected items* only when
  `selectionProvider` is non-empty (read-only). To keep `features/ai` free of a
  dependency on the consumer `features/summarize`, the sidebar only emits a
  `SummarizeScopeChoice` via an `onSummarize` callback; the **editor** (which
  owns both) turns it into a `SummarizeRequest` in `_summarizeScope(key, choice)`
  and shows the existing summary sheet. App-bar Summarize button kept (now a
  one-tap `NotebookScope` path through the same method).
- Tests (+19 → **338/338**, analyze clean): `text_budget_test` (chunkByWords
  packing/hard-split/word-conservation), `page_content_extractor_test`
  (extractSelection subset/empty/absent-id), `summarization_service_test`
  (chunk-and-reduce on cloud-fallback AND local route — every section prompt ≤
  budget, nothing truncated; page/selection scope; page & selection never touch
  the cache; empty selection fails the gate before any model call), updated
  `summarize_notifier_test` (scripts `summarizeScope`, `resolveScope` request),
  `ai_sidebar_test` (scope menu options gated on selection; `onSummarize` fires).
- NOTE: the spec's "context menu action on text/lasso selection" is served by
  the sidebar's selection-aware launcher (read-only consumer of
  `selectionProvider`); a dedicated on-canvas floating action was deliberately
  deferred (it's a larger editor-UI change and the sidebar already covers the
  requirement + acceptance criteria).

### Loop 1.4 — Explain ✅
Streamed, per-mode explanations rendered **in the sidebar**, triggered from a
selection or a knowledge-gap flag, with "insert as note" back into the editor.
Everything except insertion lives in `features/ai`.
- `ai/domain/features/explainer.dart`: `ExplainMode` (beginner / intermediate /
  advanced / child / visual / mathematical / real-world — the DoD's
  Beginner/Intermediate/Advanced/Real-world plus the plan-doc extras), a shared
  faithfulness preamble + per-mode instruction (`systemPromptFor`), and
  `explain(ExplainInput) → Stream<String>` straight off the local `AiProvider`
  (temp 0.4 / topP 0.95 / 512), content truncated to the shared input budget.
- `ai/presentation/explain_notifier.dart`: streaming state machine
  idle → preparing → streaming(partial) → ready(full), plus downloadingModel and
  error (offer-download on `AiModelNotReadyException`, like Summarize).
  `ExplainRequest.resolveContent` is a fresh-each-attempt `Future<String>`
  resolver (a selection extraction OR a gap term), so retry/mode-change re-read
  it; `changeMode` re-runs the same passage at a new depth. Session-scoped
  provider (download survives a sidebar close).
- `ai/presentation/sidebar/ai_explain_view.dart`: renders the stream live with a
  mode selector, Copy, **Insert as note**, and a close that returns to the
  Context view. Overflow-hardened for the 340px panel (Expanded/ellipsis title,
  icon-only Copy, Flexible Insert).
- `ai/presentation/sidebar/ai_sidebar.dart`: body now switches to
  `AiExplainView` while an explanation is active (the Summarize/Explain footer
  hides). New **Explain** launcher (mode menu, enabled only with a selection);
  selection resolution + streaming run entirely in `features/ai` (reads the
  extractor/recognition/settings via providers), so only insertion crosses into
  the editor.
- `ai/presentation/sidebar/ai_context_view.dart`: knowledge-gap flags are now
  tappable (second Explain trigger) — tapping one explains that undefined term
  grounded in the page topic. `onExplainGap` is optional so existing tests and
  callers are unaffected.
- `editor/ui/notebook_editor_screen.dart`: `onInsertNote` drops the text on the
  current page as a `TextElement` through the **undoable history path**
  (`historyProvider(key).push(AddElementsCommand([...]))`, `nextZOrder`, height
  measured with a `TextPainter`, placed in the visible viewport) — the spec's
  `text_box_overlay.dart` is the legacy editor, so this is the Canvas-2.0
  equivalent of "don't bypass the text-insertion path".
- Tests (+14 → **352/352**, analyze clean): `explainer_test` (chunk pass-through,
  per-mode system prompt, preset, budget truncation, distinct prompts),
  `explain_notifier_test` (streaming → ready, empty-content error, model-not-ready
  → offer-download, changeMode, reset), `ai_sidebar_test` extended (Explain gated
  on selection; mode choice runs a request; gap tap triggers explain; insert-as-
  note fires `onInsertNote`).
- NOTE: not device-run this session (no Android device; device validation is
  Nabil-owned per R5). Streaming/insert logic and render states are covered by
  widget/unit tests.

### Loop 1.5 — Writing Assistant ✅
Continuous, non-intrusive suggestions on **typed text** (grammar / clarity /
repetition / unsupported claim / structure), collected as a dismissible list in
the sidebar.
- **STOP CONDITION resolved:** the spec said stop and ask if no non-intrusive UI
  fits. Asked Nabil; he chose the **sidebar list** (over on-canvas underline
  markers). No intrusive inline markers were shipped.
- **Shares the Context Engine debounce — no second polling loop.** Added
  `ContextEngineNotifier.onContent(PageContent)`, fired after its own debounced,
  successful extraction (and with `PageContent.empty` when nothing readable). A
  sibling `WritingAssistantNotifier` reviews the typed text off that one timer +
  extraction. The hook is guarded (`_notifyContent` try/catch) so an advisory
  failure can never break analysis; it doesn't fire when analysis fails.
- `ai/domain/features/writing_assistant.dart`: `WritingSuggestion`
  (kind / message / excerpt / replacement / confidence) + `WritingSuggestionKind`
  (grammar/clarity/repetition/weakClaim/structure/other). `review(typedText)`
  reuses the **Loop 1.1 robustness ladder** — strict `{"suggestions":[…]}` schema,
  greedy decode, `ContextEngine.tryExtractJsonObject`, one stricter retry,
  tolerant parse (blank-message dropped, unknown type → other, cap 6). Gated
  below `minWords = 12`; budget-truncated. Malformed → `[]`; only real
  `AiException`s propagate. **Typed text only** (ink recognition is noisier —
  deferred).
- `ai/presentation/writing_assistant_notifier.dart`: `StateNotifier<List<
  WritingSuggestion>>`, no timer; typed text IS the change signature (skip when
  unchanged); per-page `PageWritingCache` (session) mirrors `PageContextCache`;
  `dismiss(s)` removes one; **failures degrade quietly to `[]`** (deliberate — an
  advisory feature must never throw a red error).
- `ai/presentation/sidebar/ai_context_view.dart`: a **Writing suggestions**
  section under the context body — soft cards (kind label, message, optional
  excerpt + "Try:" rewrite, dismiss ✕); renders nothing when empty.
- Wiring: `writingAssistantProvider`, `pageWritingCacheProvider`,
  `writingSuggestionsProvider` (autoDispose.family); `pageContextProvider` passes
  `onContent → writingSuggestionsProvider(key).notifier.review`.
- Tests (+17 → **369/369**, analyze clean): `writing_assistant_test` (parse,
  short-circuit, retry recover/fail, cap, drop-blank, kind map, budget),
  `writing_assistant_notifier_test` (publish, skip-unchanged, dismiss, quiet
  failure, cache restore), `context_engine_notifier_test` onContent group (fires
  on success/empty, not on failure, throwing hook can't break analysis),
  `ai_context_view_test` (suggestions render + dismiss).
- NOTE: not device-run (no device; R5 is Nabil-owned). Worth an on-device eyeball
  of suggestion quality + the 2-LLM-calls-per-pause cadence (context + writing).

## Deferred / Open Questions
- Phase U: wrap runtime as `LocalGemmaProvider implements AiProvider`
  (streaming via `getResponseAsync`), `PageContentExtractor`, general router;
  then repoint Summarize.
- Embeddings: Phase 2 via `flutter_gemma_embeddings`.
- Not ported (deliberately): Afnan's pixel-eraser fix `916e730` (legacy-editor
  files that don't exist on 2.0), his legacy `note_editor_screen.dart` wiring.

## Next Loop
**Loop 1.6 — Quiz Generator.** Types: MCQ + True/False minimum (also
fill-in-the-blank; coding challenges ONLY when the detected topic/entities are
programming — don't generate them for a history notebook). Difficulty
easy/medium/hard informed by `PageContext.estimatedLevel`. New
`ai/domain/features/quiz_generator.dart` producing structured `QuizQuestion`
(question, options, correctAnswer, explanation) — **reuse the Loop 1.1 robustness
ladder** for the JSON (same schema-with-fallback as the Context Engine /
Writing Assistant). Simple quiz-taking UI (sheet/screen) that scores the attempt;
store the raw result in a lightweight in-memory structure only — durable "quiz
score history" is Phase 2 Learning Memory, don't build persistence twice. Then
1.7 Flashcards (⚠️ STOP: CSV vs `.apkg` export decision; Isar-persistent).
