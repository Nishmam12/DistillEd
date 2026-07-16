# AI Integration Roadmap — Reconciling Afnan's AI with Inkdot-2.0

**Owner:** Nabil · **Created:** 2026-07-16 · **Status:** Planning → ready to execute

This supersedes the original phase-0 assumptions in `01_phase0_foundation.md` for
execution purposes: **Phase 0's runtime already exists** (Afnan built it), so the
work is now *reconcile + unify + build up*, not *build from scratch*. The master
plan (`AI_Notebook_Master_Plan.md`) remains the product vision.

---

## 0. Decisions locked in (2026-07-16)

1. **`Inkdot-2.0` is canonical.** The unified `SceneElement` editor 2.0 is the
   project's future. Afnan's AI (built on `origin/main`'s legacy editor) is
   **ported onto Inkdot-2.0**, not the other way around.
2. **One shared AI platform.** Afnan's runtime is refactored to sit behind the
   `AiProvider` abstraction (Loop 0.1, already on Inkdot-2.0). His `AiRouter` /
   `CloudLlmClient` grow into the general intelligent router. Summarize becomes
   the *first consumer* of a platform every later feature reuses.
3. **Port, don't branch-merge** (see §3 for why).
4. Stack is settled and validated (both devs converged independently):
   `flutter_gemma 1.3.0` + `flutter_gemma_litertlm 1.1.0` +
   `google_mlkit_digital_ink_recognition 0.15.0` + Gemma 4 E2B `.litertlm`.
   Local-first; cloud is an opt-in stub until Phase 3.
5. **Division of labour & main's fate:** Nabil (this line of work) does the
   reconciliation (Phase R) **and** the platform unification (Phase U). Afnan is
   redirected to build future AI features on `Inkdot-2.0`. `origin/main`'s legacy
   editor is **frozen now, retired after Phase R lands** (kept only as a fallback
   reference until Summarize is proven on 2.0).
6. **Unify before features:** Phase U (one platform) completes **before** any new
   master-plan feature is built, so no feature is built twice. Order is strictly
   **R → U → features**.
7. **First feature after the platform: the Live Context Engine.** The invisible
   foundation every later feature reads from — built before Sidebar/Explain/
   Quiz/etc.

---

## 1. Current state of the world

| | `origin/main` (Afnan, v1.0.2+10, default branch) | `Inkdot-2.0` (Nabil, v1.1.0+6, local — unpushed) |
|---|---|---|
| Editor | **Legacy** (`features/editor/presentation/screens/note_editor_screen.dart`, `Stroke` model) | **SceneElement 2.0** (`lib/editor/ui/`, `lib/domain/model/scene_element.dart`); legacy editor screen **deleted** |
| AI | **Complete `features/summarize/`** (4.7k lines, tested) | **`features/ai/domain/`** provider abstraction only (Loop 0.1) |
| Diverged at | `6826e35` (Jun 20) — the "Inkdot 2.0 updates and refactors" rewrite is **only** on Inkdot-2.0 | |

**Consequence:** Afnan's AI reads legacy `Stroke` lists and mounts its Summarize
button in a screen that does not exist on Inkdot-2.0. His **runtime is portable
(~80%)**; his **editor integration + stroke→text input path must be redone**
against `SceneElement`.

### What's reusable as-is (editor-agnostic)
`data/llm/*` (GemmaBootstrap, FlutterGemmaRuntime/Installer, LocalLlmService
load→generate→unload+mutex, ModelDownloadManager StatFs+progress+cancel,
DeviceStorage), `MeaningfulnessGate`, `SummaryCache`+store (SHA-256),
`CloudLlmClient` stub, `summarize_notifier`, `summary_bottom_sheet`,
`MainActivity.kt` StatFs channel, AndroidManifest AI entries, the AI deps.

### What must be redone for the 2.0 editor
- `strokesToInk` (timestamp-synthesis logic) → read `FreehandElement`, not `Stroke`.
- "collect all pages" → read `SceneElementStore.loadForPage(pageId)`, not `InkFileStorage`.
- Summarize entry point → wire into `lib/editor/ui/notebook_editor_screen.dart`.
- `StrokePoint.t` (pen-capture timestamp) → add to Inkdot-2.0's `StrokePoint` and
  capture it in the 2.0 input pipeline (`lib/editor/input/scene_pointer_listener.dart`)
  for best recognition quality (synthesis is the fallback for legacy ink).

### Local WIP to discard
My uncommitted Loop 0.2 files (`gemma_model_manager.dart`,
`local_gemma_provider.dart`, `ai_bootstrap.dart`) + pubspec/lock edits overlap
Afnan's runtime — **discard them**; they're superseded by the port. Keep the
committed Loop 0.1 abstraction (`8defafb`).

---

## 2. Target architecture (the unified AI platform)

```
        SceneElement editor 2.0  (unchanged — AI only observes it)
                     │  read-only
                     ▼
   ┌─────────────────────────────────────────────────────────┐
   │  features/ai/  — shared AI platform                      │
   │                                                         │
   │  domain/  AiProvider · AiMessage · AiGenerationOptions   │
   │           AiCapabilities · AiException     (Loop 0.1 ✅) │
   │           PageContentExtractor  (reads SceneElement)     │
   │           HandwritingRecognizer · MeaningfulnessGate     │
   │           AiRouter (general: capabilities + policy)      │
   │                                                         │
   │  data/    LocalGemmaProvider  implements AiProvider ─────┼─► flutter_gemma
   │           (streaming + load→unload lifecycle, from        │   _litertlm
   │            Afnan's runtime seams)                         │
   │           MlkitHandwritingRecognizer   ─────────────────┼─► ML Kit
   │           CloudProvider (stub → Phase 3)                 │
   │           embeddings (Phase 2)                           │
   └─────────────────────────────────────────────────────────┘
                     ▲            ▲            ▲
        ┌────────────┘     ┌──────┘      ┌─────┘
   Summarize        Context Engine    Explain / Quiz / …
   (port of Afnan)  (Phase 1)         (Phase 1+)
```

**Principle unchanged from the master plan:** the AI *observes* the editor; it
never owns it. All AI reads go through `PageContentExtractor` +
`SceneElementStore` (read-only).

---

## 3. Phase R — Reconciliation (bring Afnan's AI onto Inkdot-2.0)

**Why port, not `git merge origin/main`:** the branches diverged on the editor
rewrite. A full merge drags in legacy-editor commits (e.g. the pixel-eraser fix
on files that no longer exist on 2.0) and produces modify/delete conflicts on the
whole `features/editor` tree. A curated port keeps the change surface to the
summarize feature + shared infra.

Land as one reviewable PR onto `Inkdot-2.0`:

**R1 — Infra (shared, editor-independent)**
- Add AI deps to `pubspec.yaml`: `flutter_gemma 1.3.0`, `flutter_gemma_litertlm 1.1.0`,
  `google_mlkit_digital_ink_recognition 0.15.0`, `crypto ^3.0.7`,
  `shared_preferences ^2.5.5`. `flutter pub get`.
- Port `MainActivity.kt` StatFs MethodChannel (`com.inkflow.inkflow/storage`) and the
  `AndroidManifest.xml` AI block (foreground-service + OpenCL `uses-native-library`).
  Verify `minSdk` ≥ 24 (litertlm) — currently `flutter.minSdkVersion`; pin if the build fails.
- `main.dart`: add `SummaryCacheSchema` to the Isar `openDatabase` list (which on 2.0
  already has Notebook/NotePage/SceneElementRecord/AppMeta). Keep engine init **lazy**
  (Afnan's `GemmaBootstrap.ensureInitialized`) — nothing AI loads at boot.

**R2 — Copy the portable feature layer** into `lib/features/summarize/` verbatim,
then fix imports: `data/llm/*`, `data/cache/*`, `domain/services/{ai_router,
meaningfulness_gate}.dart`, `domain/models/recognition_result.dart`,
`presentation/{summarize_notifier, summarize_providers, widgets/summary_bottom_sheet}.dart`,
plus all their tests. These compile unchanged (they don't touch the editor).

**R3 — Re-point the input path to SceneElement** (the real work):
- Add `t` (nullable capture ms) to Inkdot-2.0 `StrokePoint`
  (`features/editor/domain/models/stroke_point.dart`) with the same
  omit-when-null serialization Afnan used; capture it in
  `lib/editor/input/scene_pointer_listener.dart`.
- New `freehandToInk(List<FreehandElement>)` (reuse Afnan's timeline-rebasing /
  synthesis logic) in the ported `HandwritingRecognitionService`, replacing the
  `Stroke`-based `strokesToInk`. Skip eraser/empty.
- New "collect pages" that enumerates a notebook's pages
  (`page_repository.dart`) and loads each via `SceneElementStore.loadForPage`,
  filters `FreehandElement`, in page order.

**R4 — Wire the entry point** into `lib/editor/ui/notebook_editor_screen.dart`
(or `editor_controls.dart`): a Summarize action that calls the notifier with the
new page-collector, then shows the existing bottom sheet. Port the settings rows
(cloud toggle default OFF, recognition language, model management) into
`settings_screen.dart` / `settings_provider.dart`.

**R5 — Green checkpoint:** `flutter analyze` clean, all ported tests + existing
suite pass, Summarize works end-to-end on the 2.0 editor (device check: model
download → recognize → summary). Commit. Push `Inkdot-2.0`.

> After R, Inkdot-2.0 = 2.0 editor + working Summarize. This is a shippable
> milestone and the baseline for everything below.

---

## 4. Phase U — Unify behind the shared platform

Refactor *in place* so Summarize keeps working while the platform emerges:

**U1 — `LocalGemmaProvider implements AiProvider`** (`features/ai/data/`): wraps
Afnan's `LlmRuntime`/`LlmSession` seams. Adds the **streaming** path
(`session.getResponseAsync()`) my abstraction promises, *and* preserves the
load→generate→unload+mutex lifecycle. `embed()` throws
`AiUnsupportedOperationException` until Phase 2. Map `LlmException` → `AiException`.
`LocalLlmService.generateOnce` becomes a thin non-streaming convenience over it.

**U2 — `PageContentExtractor`** (`features/ai/domain/`): the single read-only
entry point every feature uses. Produces `PageContent { recognizedInkText,
typedText (from `TextElement`), sourceBreakdown (image/PDF flagged `needsOcr`) }`.
Reuses the R3 recognizer + gate. This is the master plan's Context-Engine feed.

**U3 — General `AiRouter`**: generalize Afnan's router to dispatch across a list
of `AiProvider`s using `AiCapabilities` (isLocal, contextWindow, cost) +
policy (offline→local, privacy, task complexity). His summarize decision table
becomes one policy input. `CloudLlmClient` stub stays the cloud seam.

**U4 — Point Summarize at the platform**: `SummarizationService` consumes
`AiProvider` + `PageContentExtractor` instead of its private runtime. Delete the
now-duplicated private paths. Green checkpoint + commit.

> After U, there is exactly one AI runtime, one router, one content extractor —
> and Summarize is just its first client.

---

## 5. Master-plan feature roadmap (on the shared platform)

Each maps to `AI_Notebook_Master_Plan.md`; each is a vertical slice reusing
`AiProvider` + `PageContentExtractor` + `AiRouter`.

**Phase 1 — Context Engine + core features** (`02_phase1_*.md`)
- **Live Context Engine**: debounced background pass over `PageContentExtractor`
  output → structured understanding (topic, subtopics, concepts, entities,
  definitions, gaps, level). Cached; the substrate for everything else.
- **AI Sidebar**: streaming chat surface over the current page's context.
- **Explain** (selection → styles), **Writing Assistant** (grammar/clarity/gaps,
  non-intrusive), **Flashcards**, **Quiz Generator**. All local-first, streaming.

**Phase 2 — Memory / RAG / Knowledge Graph / Study Planner** (`03_phase2_*.md`)
- Embeddings via `flutter_gemma_embeddings` → `AiProvider.embed`.
- On-device vector store (chunk `PageContent` → embed → store → semantic search)
  so large notebooks never blow the local context budget.
- Learning Memory (mastered/weak concepts, quiz history), Knowledge Graph
  (concept map over extracted concepts), Study Planner.

**Phase 3 — Cloud gateway + intelligent router + tool calling** (`04_phase3_*.md`)
- Replace `StubCloudLlmClient` with a real `CloudProvider` behind a minimal
  stateless FastAPI gateway (Gemma 26B/31B; optional Gemini/Claude/GPT). Router
  gains the cloud tier. Tool calling (flutter_gemma function-calling is already
  in the stack).

**Phase 4 — Voice / vision / multi-agent** (`05_phase4_*.md`) — exploratory.

---

## 6. Execution sequence & checkpoints

Loop discipline (from `00_README_HOW_TO_USE.md`): each loop → `flutter analyze` +
`flutter test` + update `AI_PROGRESS.md` + commit, then report.

1. **R1–R2** (infra + portable copy) — one loop.
2. **R3–R5** (SceneElement input + wiring + device proof) — one loop. *Milestone: Summarize on 2.0.*
3. **U1–U2** (provider + extractor) — one loop.
4. **U3–U4** (router + repoint Summarize) — one loop. *Milestone: unified platform.*
5. Phase 1 features — one loop each, **Live Context Engine first** (decision #7).
6. Phase 2+ as separate sessions.

**Afnan handoff (decision #5):** notify Afnan that `main` is frozen and all future
AI work targets `Inkdot-2.0`; retire main's legacy editor once R lands. Nabil owns
R + U; Afnan picks up feature loops on the unified platform afterward.

---

## 7. Verification
- Per loop: analyze clean; full `flutter test`; new services get mocktail unit
  tests mirroring `test/features/...` (Afnan's ported tests are the template).
- Device proofs (need an attached device/emulator, reported with exact repro):
  model download+progress, ink→text recognition quality (log accuracy in
  `AI_PROGRESS.md`), end-to-end latency vs ~10s target, memory (load→unload holds).
- Privacy invariant test: note text reaches cloud **only** on explicit opt-in.
- "No unexpected network in local path" grep gate.

## 8. Risks / open items
- **Recognition quality on 2.0 ink** depends on capturing `StrokePoint.t` in the
  new input pipeline; validate on real handwriting before building Phase 1 on it.
- **Afnan handoff** — resolved (decision #5): main frozen→retired, Afnan → Inkdot-2.0.
  Residual risk is only timing: freeze main *before* he adds more AI there.
- **Context budget** (4096 tokens local) forces RAG earlier for big notebooks.
- **Model download UX** (~2.4 GB) — fine for a dev/opt-in flow; needs product
  thought before it's on a mainstream user path.
- flutter_gemma API drift — pin versions; adapt the wrapper, never the domain contract.

## 9. Immediate next actions
1. **Freeze `main`** and notify Afnan: future AI work → `Inkdot-2.0` (decision #5).
2. Discard local Loop 0.2 WIP; keep committed Loop 0.1.
3. Start **R1–R2** (work off `Inkdot-2.0`).
