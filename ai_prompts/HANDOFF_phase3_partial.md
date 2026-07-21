# HANDOFF — Phase 3 partial (2026-07-18)

Entry point for the next session. Read this top-to-bottom before writing code.
Everything here is current as of commit `e870349`, version **`2.0.0+19`**,
branch **`v2.0.0`**.

---

## 1. TL;DR — where we are

**Inkflow / Notepad-** (Flutter, package `inkflow`, repo `github.com/Nishmam12/Notepad-`)
is a note-taking app being turned into an on-device AI learning workspace,
now growing an optional cloud tier.

- **Phase 0** (handwriting → text, AiProvider seam) — done.
- **Phase 1** (Context Engine, Summarize, Explain, Writing Assistant, Quiz,
  Flashcards, Anki export) — done, shipped as **2.0.0**.
- **Phase 2** (Learning Memory, RAG, Ask-your-notes, Knowledge Graph, Study
  Planner) — code-complete. **On-device validation PARTIAL this session**:
  "Ask your notes" confirmed working end-to-end on a real device. Knowledge
  Graph and Study Planner screens were never opened. The RAG `kMinRelevance`
  stop condition is still open (only tested at 2 indexed chunks).
- **Phase 3** (Cloud Gateway / Router) — **Loops 3.1, 3.2, 3.3, 3.5 DONE this
  session. Loop 3.4 (Tool Calling) deliberately NOT started** — it has its own
  stop condition (paid search-API pricing) that hasn't been discussed.

**State:** `flutter analyze` clean; **605/605 Flutter tests pass**; gateway's
own `pytest` suite **15/15 passes**, its analyzer/lint clean too. Branch
`v2.0.0` pushed to origin.

**The most important thing to internalize:** this session did TWO very
different kinds of work back to back — (a) on-device debugging on a real
Xiaomi Pad 7 over ADB, which found and fixed two real bugs, and (b) a large,
planned, from-scratch build of a new Python backend + Flutter routing layer.
Don't conflate the two when deciding what to do next — see §6 for exactly
what's left in each.

---

## 2. How to work here — LOAD-BEARING CONSTRAINTS

Several changed THIS session. Read carefully even if you remember the old
rules — some are now wrong.

1. **The GitHub repo is PRIVATE as of this session** (flipped from PUBLIC on
   2026-07-17 → PRIVATE on 2026-07-18 — it has changed at least twice now).
   **Always re-verify current visibility before acting on secrets** —
   unauthenticated `curl https://api.github.com/repos/Nishmam12/Notepad-` →
   404 means private, 200 means public. Don't trust this file's snapshot.
2. **Because the repo is private, `lib/dev/dev_secrets.dart` is now COMMITTED**
   (un-gitignored) with a real shared dev-only HuggingFace token, so the whole
   team gets it on clone without pasting their own into Settings. If the repo
   is ever public again: immediately re-gitignore that file, blank the token
   back to `''`, and rotate the real token (git history keeps it regardless).
   `lib/dev/dev_secrets.example.dart` is kept only as a template for that
   scenario. (Memory: `feedback-notepad-public-repo-secrets`.)
3. **Do NOT add a `Co-Authored-By: Claude` trailer to commits in this repo.**
   Nabil explicitly asked for this to be dropped this session — overrides the
   tool's usual default. (Memory: `feedback-notepad-no-coauthor-trailer`.)
4. **Bump `pubspec.yaml` version before EVERY push** (manual — the auto-bump
   workflow only runs on frozen `main`). We're at `2.0.0+19`; next push is
   `+20`. (Memory: `feedback-notepad-bump-version-every-push`.)
5. **NEVER `git add -A` / `git add .`.** Stage files explicitly by name.
   Untracked noise to never stage: `.claude/`, `.vscode/`, `ios/`,
   `logcat_dump.txt`, `ai_prompts/HANDOFF_*.md` (including THIS file).
6. **Never touch `main`.** All work is on `v2.0.0`.
7. **On a bare "continue", summarize + confirm before coding** — don't assume
   which of the several open threads (§6) to pick up.
   (Memory: `feedback-notepad-no-unprompted-phase-start`.)

---

## 3. Codebase invariants (preserve these)

Everything from the Phase 2 handoff still holds (layering: `domain/` pure,
`data/` rule-free, `features/ai` never imports a consumer feature; Riverpod as
the DI mechanism; hand-written fakes not a mocking library; the
load→generate→unload model lifecycle with per-model mutexes). New this
session:

- **Two parallel routing systems now coexist on purpose.** The old,
  word-count-only `AiRouter` + `CloudLlmClient`/`StubCloudLlmClient`
  (`domain/ai_router.dart`, `data/llm/cloud_llm_client.dart`) still drives
  Summarize's cloud path, completely unchanged. The new, task-type-aware
  `IntelligentRouter` + `RoutedAiProvider` (`domain/routing/intelligent_router.dart`)
  drives **only Explain**. Don't merge these or assume one replaces the
  other — that unification is an explicit future decision, not done.
- **`CloudPrivacy` enum lives in `core/providers/settings_provider.dart`, NOT
  `features/ai`** — `core/` never imports `features/` in this codebase, so a
  setting type consumed by an AI feature has to be defined in core and
  imported (re-exported) by the feature, not the other way round.
- **Debug-only instrumentation was left in on purpose**: `rag_retriever.dart`,
  `rag_index_scheduler.dart`, and `context_engine_notifier.dart` all gained
  `kDebugMode`-gated `debugPrint` logging this session (RAG search timing,
  schedule/index outcomes, Context Engine analyze failures). These exist
  because the RAG `kMinRelevance` stop condition is still unresolved — don't
  strip them without checking whether that investigation is done.
- **`google_mlkit_digital_ink_recognition` is pinned to `0.14.2`**, one
  version below latest. `0.15.0`'s Kotlin migration broke the Dart↔native
  channel name — confirmed via source inspection, not yet fixed upstream as
  of 2026-07-18. Re-check before ever bumping this dependency.
- **A `Future<T>` method that unconditionally throws must be declared
  `async =>`, not plain `=>`.** Without `async`, the throw happens
  *synchronously at call time* instead of becoming a rejected Future — this
  broke a test this session (`CloudGatewayProvider.embed`) until fixed. Check
  any new "unsupported operation" style method against this.
- **`sqlite3.Connection` used as a Python context manager only commits/rolls
  back — it does NOT close the connection.** Leaks a file handle, which
  breaks cleanup on Windows (can't delete an open file). Always wrap with
  `contextlib.closing()` too (see `server/ai-gateway/app/rate_limit.py`).

---

## 4. What was built this session

Commits, newest first: `e870349` (Phase 3 loops) · `125e9a8` (Phase 2
on-device fixes) · `d16a57c` (private-repo secrets).

### On-device validation pass (Xiaomi Pad 7, via ADB)

Confirmed working end-to-end: handwriting recognition → Context Engine
analysis → RAG indexing → Ask-your-notes retrieval → grounded LLM answer with
source citations.

Two real bugs found and fixed:
1. **ML Kit channel-name regression** (see §3) — pinned to `0.14.2`.
2. **Explain meta-commentary bug** — `Explainer`'s system prompt
   (`domain/features/explainer.dart`) let the small on-device Gemma 4 E2B
   describe the *prompt itself* ("this passage points out a gap...") instead
   of teaching the flagged term, when explaining a short knowledge-gap term
   rather than a real passage. Fixed with an explicit anti-meta-commentary
   instruction in the shared system prompt.

Confirmed **by design, not a bug**: Explain's "Visual" mode is text-only —
no current LLM (any vendor, any size) generates actual images; that needs a
diffusion-model architecture, out of scope. The real rendered-diagram feature
is the Knowledge Graph screen, which was never opened this session.

Also discovered mid-session: RAG indexing rides the Context Engine's
analysis pass, which needs the **main on-device LLM (Gemma 4 E2B, ~2.4 GB)**
downloaded — not just the embedder (EmbeddingGemma, ~185 MB). Both are
prerequisites for RAG to work at all. And: opening "Ask notes" in the sidebar
replaces the "AI insights" body, which stops that page's Context Engine
provider from running (`autoDispose`) — so a page won't get (re-)indexed
while Ask notes sits open on top of it. Neither is a bug, both are easy to
get confused by when testing.

### Phase 3 — Cloud Gateway + Intelligent Router (Loops 3.1–3.3, 3.5)

Full detail in `AI_PROGRESS.md`'s "Phase 3" section. Built via an
approved plan at `C:\Users\nabil\.claude\plans\reactive-marinating-neumann.md`
(worth reading if you need the original reasoning/alternatives considered).

- **`server/ai-gateway/`** — new Python 3.11+/FastAPI service (first Python
  in this repo). `POST /v1/generate` streams SSE
  (`data: {"text": "..."}` / `data: {"error": "..."}` on mid-stream failure —
  partial output already sent is never discarded). `GET /health`. No
  `/v1/embed` (Phase 2's on-device embeddings already cover that).
  - Gemma 26B/31B via **OpenRouter** (`google/gemma-4-26b-a4b-it` /
    `-31b-it`) — Google hasn't put Gemma 4 on managed Vertex AI yet (checked
    live 2026-07-18; re-check, this could change).
  - Gemini/Claude/GPT adapters exist (`app/providers/`) but are **unconfigured**
    — feature-flagged by env-var key presence, gateway runs fine with zero
    frontier keys.
  - Per-device-key daily rate limit (SQLite), content-free structured
    logging, Dockerfile + README with deployment options — **not deployed**.
  - `cd server/ai-gateway && python -m venv .venv`, then
    `./.venv/Scripts/pip install -r requirements.txt` (Windows), `cp
    .env.example .env` and fill in `OPENROUTER_API_KEY` to actually run it.
- **`lib/features/ai/domain/routing/intelligent_router.dart`** — `TaskType`,
  `IntelligentRouter.decide()` (grammar/rewrite/explain/summarize/research
  stay local unless over the local word budget, matching `AiRouter`'s exact
  budget math; thesisWriting/complexReasoning/largeCodebase always go
  cloud-frontier when privacy allows, regardless of length), and
  `RoutedAiProvider implements AiProvider` (wraps the decision as one
  provider; `peekRoute()` lets a caller check the decision *before* calling
  `generate()`, since `AiProvider`'s sealed `AiException` hierarchy can't be
  extended from another file to signal "pause for confirmation").
- **`lib/features/ai/data/providers/cloud_gateway_provider.dart`** —
  `CloudGatewayProvider implements AiProvider`, `dio`-based (new dependency —
  chosen for native streamed-response + `CancelToken` support). Maps
  gateway-unreachable/429 → `AiUnavailableException`, mid-stream failure →
  `AiGenerationException`. Device key is session-lifetime only (regenerated
  per launch, not persisted) — fine for now since the gateway isn't deployed;
  revisit once it is.
- **Only Explain is wired to the new router** (`ai_providers.dart`'s
  `explainerProvider`/`explainAiProviderProvider`) — Summarize, Ask your
  notes, Context Engine, Quiz, Flashcards are untouched on purpose. A new
  `ExplainConfirmCloud` state (`explain_notifier.dart`) pauses before any
  cloud call when privacy is `askEachTime` (the default) — "never silently
  send to cloud." First-ever cloud call gets a longer explanatory message
  (persisted `hasSeenFirstCloudCall` flag); later ones are terser. A small
  persistent "Cloud" badge (`ai_explain_view.dart`) shows whenever an answer
  used the cloud tier.
- **No Settings UI exists yet to change `cloudPrivacy` away from its default**
  (`askEachTime`) — it's a real, persisted, working setting, just nothing in
  the Settings screen lets a user pick a different value yet.

---

## 5. What's LEFT — pick one, don't assume

There are three genuinely separate threads open. Ask which one before
starting, especially since Nabil said the remaining Phase 2 device work
happens "after Phase 3" — and Phase 3 is now *partially* done (3.1-3.3+3.5,
not 3.4). Don't assume that unblocks §5a unprompted.

### 5a. Remaining Phase 2 on-device validation (Xiaomi Pad 7)
- Open the Knowledge Graph and Study Planner screens for the first time on a
  real device — never done.
- The RAG `kMinRelevance` STOP CONDITION: only tested at 2 indexed chunks (one
  real hit scored 0.488, just above the 0.45 floor). A real stress test at
  "thousands of chunks" scale is still owed before tuning that threshold or
  reaching for a heavier vector store — the spec wants real numbers first.
- Remember: the main LLM (Gemma 4 E2B, ~2.4 GB) must be downloaded in
  addition to the embedder for RAG indexing to run at all (see §4).

### 5b. Phase 3 Loop 3.4 — Tool Calling
- Its own stop condition: confirm pricing/expected usage for a paid search
  API with Nabil *before* building anything that costs money per call.
  Calculator (pure Dart, free) has no such blocker and could go first.
- Spec: `ai_prompts/04_phase3_cloud_gateway_router.md` §2, Loop 3.4.

### 5c. Phase 3 polish / follow-ups (not blocked on anything)
- Manual end-to-end verification of a real cloud round-trip through Explain
  (badge, confirm dialog, live streaming, mid-stream cancellation) — needs a
  real `OPENROUTER_API_KEY` and the gateway running on `localhost`. Doesn't
  need the tablet, can happen on the dev host right now.
- A Settings UI screen/picker for `cloudPrivacy` (currently no way for a user
  to change it from the default).
- Wiring the router into more features (Summarize, Ask your notes, etc.) —
  each needs its own task-type classification decision first.
- Actually deploying the gateway (Fly.io/Railway/Cloud Run/VPS — see
  `server/ai-gateway/README.md` for the tradeoffs, none chosen).

---

## 6. Key file index

- **Progress log (detailed):** `AI_PROGRESS.md` — read the "Phase 3" and
  "On-device validation pass" sections first; full per-loop history below that.
- **This session's approved plan:** `C:\Users\nabil\.claude\plans\reactive-marinating-neumann.md`
- **Phase specs:** `ai_prompts/0X_phase*.md` (Phase 3 = `04_...`).
- **User changelog:** `CHANGELOG.md` (`[Unreleased]`).
- **Gateway:** `server/ai-gateway/` — see its own `README.md`.
- **New Flutter routing:** `lib/features/ai/domain/routing/intelligent_router.dart`,
  `lib/features/ai/data/providers/cloud_gateway_provider.dart`.
- **AI providers / wiring:** `lib/features/ai/presentation/ai_providers.dart`
  (`cloudGatewayMidProvider`, `cloudGatewayFrontierProvider`,
  `intelligentRouterProvider`, `explainAiProviderProvider`).
- **Settings:** `lib/core/providers/settings_provider.dart` (`CloudPrivacy`,
  `hasSeenFirstCloudCall`).
- **Memories** (auto-loaded): phase-2 validation status, phase-3 status,
  repo-secrets policy (now private), no-co-author-trailer, version-bump,
  no-unprompted-phase-start.

### Commands
```
# Flutter
dart run build_runner build --delete-conflicting-outputs   # after any Isar change
flutter analyze                                            # must be clean
flutter test                                                # 605/605 as of this handoff

# Gateway (from server/ai-gateway/)
./.venv/Scripts/pip install -r requirements.txt             # first time / after requirements.txt changes
./.venv/Scripts/python -m pytest                            # 15/15 as of this handoff
./.venv/Scripts/python -m uvicorn app.main:app --reload      # run locally on :8000
```
