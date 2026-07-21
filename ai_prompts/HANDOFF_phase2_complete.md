# HANDOFF — Phase 2 complete (2026-07-18)

Entry point for the next session. Read this top-to-bottom before writing code.
Everything here is current as of commit `d5eb1de`, version **`2.0.0+16`**, branch
**`v2.0.0`**.

---

## 1. TL;DR — where we are

**Inkflow / Notepad-** (Flutter, package `inkflow`, repo `github.com/Nishmam12/Notepad-`)
is a note-taking app being turned into an on-device AI learning workspace.

- **Phase 0** (handwriting → text, AiProvider seam) — done, earlier.
- **Phase 1** (Context Engine, Summarize, Explain, Writing Assistant, Quiz,
  Flashcards, Anki export) — done, shipped as **2.0.0**.
- **Phase 2** (Learning Memory, RAG, Ask-your-notes, Knowledge Graph, Study
  Planner) — **COMPLETE this session.** Loops 2.1–2.5 all built, tested,
  analyze-clean.
- **Phase 3** (Cloud Gateway / Router) — **NOT STARTED. This is next.**

**State:** `flutter analyze` clean; **579/579 tests pass**; branch `v2.0.0`
pushed to origin. `main` is FROZEN and must never be touched.

**The one thing not done:** on-device validation. All Phase 2 is code-complete
and fake-tested but never run on a real device — Nabil deferred all device
testing to "after Phase 3" (his words). See §6.

---

## 2. How to work here — LOAD-BEARING CONSTRAINTS

These are non-negotiable. Several are security-relevant.

1. **The GitHub repo is PUBLIC.** Verified via the API. Never commit a secret.
   Before every push run `git diff --cached | grep hf_` and confirm empty.
   (Memory: `feedback-notepad-public-repo-secrets`.)
2. **The dev HuggingFace token lives ONLY in `lib/dev/dev_secrets.dart`, which
   is gitignored.** Only `lib/dev/dev_secrets.example.dart` (token `''`) is
   committed. A fresh clone must `cp lib/dev/dev_secrets.example.dart
   lib/dev/dev_secrets.dart` or the app won't compile. The real token is a
   DEV-ONLY credential Nabil supplied ("should not be used in final app build");
   it must be rotated when development wraps. The app reads it only in
   `kDebugMode`, via `huggingFaceTokenProvider`.
3. **Bump `pubspec.yaml` version before EVERY push.** The `+build` auto-bump
   workflow only runs on `main` (frozen), so on `v2.0.0` it is manual. We're at
   `2.0.0+16`; next push is `+17`. (Memory: `feedback-notepad-bump-version-every-push`.)
4. **NEVER `git add -A` / `git add .`.** Stage files explicitly by name every
   time. Untracked noise to never stage: `.claude/`, `.vscode/`, `ios/`,
   `logcat_dump.txt`, `ai_prompts/HANDOFF_*.md` (including THIS file).
5. **Never touch `main`.** All work is on `v2.0.0`.
6. **On a bare "continue", summarize + confirm before coding** — don't start a
   new phase unprompted. (Memory: `feedback-notepad-no-unprompted-phase-start`.)
7. Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## 3. Codebase invariants (preserve these)

- **Layering:** rules live in the pure `domain/`; `data/` is rule-free (records
  only convert to/from domain). `features/ai` NEVER imports a consumer feature
  (summarize/editor). Consumer features may import `features/ai`.
- **Riverpod is the DI mechanism** (get_it is unused). Providers in
  `lib/features/ai/presentation/ai_providers.dart`.
- **Stores are seams over Isar** (`FlashcardStore`, `NoteChunkStore`,
  `StudyPlanStore`, `LearningMemoryRepository`) so tests fake them without Isar.
- **Hand-written fakes in tests**, not a mocking library, though `mocktail` is a
  dep. Fakes `implements` the seam.
- **AiProvider contract:** streaming `generate()`, typed `AiException`s (never
  throw raw), `embed()` delegates to the embedder. Robustness ladder for
  structured LLM output (balanced-brace JSON extract → one retry → graceful
  empty; never throw to the user).
- **Isar gotcha:** a collection with 2+ `@Index()` fields loses
  `findAll()`/`deleteAll()` off `.where()` — use `.filter()`. Schemas registered
  in `main.dart`'s `IsarService.openDatabase([...])`. Regenerate with
  `dart run build_runner build --delete-conflicting-outputs`.
- **`@embedded` classes** need a no-arg constructor + nullable/defaulted fields.
- **Isar `float` typedef** = 32-bit `double` — used for embedding vectors
  (`NoteChunkRecord.embedding`) to halve storage; still `List<double>` in domain.
- **Model memory discipline:** every model call is load→generate→unload, held by
  a per-model mutex. The LLM and the embedder have SEPARATE mutexes (a background
  re-index must not park a user-waiting Summarize).
- **Match surrounding code style / comment density.** Comments explain WHY
  (constraints), never narrate the next line.

---

## 4. What was built this session (Phase 2)

Commits, newest first: `d5eb1de` (2.5) · `f480244` (2.4) · `aac02d2` (2.3
jump) · `bf69f36` (2.3) · `815cc98` (dev token) · `2043376` (2.2) · `b88ab78`
(HF token setting) · `48a5946` (2.2 core) · `9972868` (2.1).

### Loop 2.1 — Learning Memory  (`9972868`)
Durable concept mastery + quiz history. `domain/memory/` (pure): `ConceptMastery`
(`MasteryLevel {unseen,learning,practiced,mastered}`, `normalizeConceptKey`),
`QuizAttempt`, `LearningPreferences`, `StudySession`. `data/memory/` records +
`IsarLearningMemoryRepository`. Fed automatically by the Context Engine
(`observePageContext`) and quiz results (`recordQuizAttempt`).
**Sync boundary:** identity is `(notebookId, conceptKey)`; `notebookId` isn't
cross-device-stable yet (documented, left as-is — local-only for now).

### Loop 2.2 — On-device RAG  (`48a5946`, `2043376`, + token `b88ab78`/`815cc98`)
- `domain/rag/`: `page_chunker` (overlapping ~250-word chunks), `vector_math`
  (cosine + `topKSimilar`, undefined→0.0 not NaN), `text_embedder`
  (`TextEmbedder` seam + `EmbedTaskType {document,query}` — EmbeddingGemma is
  ASYMMETRIC, so taskType is REQUIRED everywhere), `note_chunk`
  (`NoteChunk`+`PageIndexState`+`pageTextSignature`), `rag_retriever`,
  `rag_indexer` (incremental by signature+modelId).
- `data/embeddings/`: `EmbedderSpec.active` (EmbeddingGemma 300M seq512),
  `embedder_adapter` (install/inference seams — **token guard gates DOWNLOADS
  not activations**), `local_text_embedder` (own mutex, shape-verifies output),
  `embedder_download_manager` (reads token via callback at download time).
- `data/rag/`: `NoteChunkRecord` + `NoteChunkStore`.
- Wiring: `rag_index_scheduler` (rides Context Engine `onContent`, 20s idle NOT
  the 2.5s debounce), providers, `main.dart` schema, `LocalGemmaProvider.embed()`
  now real (query semantics).
- **Token:** per-user Settings field (`settings_provider.huggingFaceToken`) +
  Settings→AI dialog; `EmbeddingModelSpec` is a flutter_gemma type so ours is
  `EmbedderSpec`. Gated repo `litert-community/embeddinggemma-300m` (401 without
  token; `gated: auto`). Model+tokenizer URLs verified real (TFL3 magic /
  sentencepiece protobuf). Settings → AI Models has a token-aware Download row.

### Loop 2.3 — Ask your notes  (`bf69f36`, `aac02d2`)
Grounded QA over a notebook. `domain/features/notes_qa.dart` — retrieve/answer
split; refuses (no LLM call) when nothing retrieved; passages numbered `[n]`,
budgeted; temperature 0.2. `presentation/ask_notes_notifier.dart` — state machine
with per-model download offers (embedder to retrieve, LLM to answer).
`presentation/sidebar/ai_ask_view.dart` — query box + streamed answer + numbered
source cards. Sidebar "Ask notes" chip. **Source cards jump to their page**
(`onJumpToSource` wired in `notebook_editor_screen.dart`, `aac02d2`).
**Summarize half needed nothing** — notebook-summarize already map-reduces
(chunk-and-reduce); RAG would regress a comprehensive summary. Documented, not
skipped.

### Loop 2.4 — Knowledge Graph  (`f480244`)
`domain/knowledge_graph/`: `concept_relation` (edge value type, tolerant JSON
parse), `knowledge_graph` (pure builder — edge endpoints with no mastery record
become `referencedOnly` "gap" nodes), `graph_layout` (dependency-free
deterministic force-directed layout, chosen over a package). **Relations are
extracted in the Context Engine's EXISTING pass** — the schema now also asks for
`relatedConcepts`; `PageContext` parses them; `observePageContext` persists them
(`ConceptRelationRecord`, upsert by natural key). Screen at `/note2/:id/graph`
(editor `hub` icon): `CustomPainter`, mastery-coloured nodes, pan/zoom, legend.

### Loop 2.5 — Study Planner  (`d5eb1de`)
`domain/study_planner/`: `study_plan` (model — `StudyHorizon`, `StudyTaskKind`,
`StudyTask`, `StudyDay`, `StudyPlan`), `study_scheduler` (**pure, deterministic
— NO model call**; priority weak→due→gap, deduped, capped, evenly spread).
`data/study_planner/`: `StudyPlanRecord` (embedded day/task) + `StudyPlanStore`
(one plan per notebook). `presentation/study_planner_notifier.dart` orchestrates
signals→scheduler→save (optimistic day toggle, rolls back on failed write).
Screen at `/note2/:id/plan` (editor `event_note` icon): horizon picker + dated
day list with checkboxes + progress. **Gaps reuse the graph's `referencedOnly`
nodes.** `StudyPlan.strategyNote` (optional model framing) left as a
non-breaking future add — deliberately NOT built (a plan shouldn't need a 2.4 GB
download).

---

## 5. Gotchas hit this session (save yourself the time)

- **Stray NUL byte in a source file.** `flutter analyze` tolerated it; the Isar
  generator's parser reported a bogus "syntax error" on a fine-looking line.
  Find with `od -c <file> | grep '\0'`; strip with `perl -i -pe 's/\x00/ /g'`.
  When a generator errors on syntactically-valid Dart, suspect a NUL.
- **`valueOrNull` on `AsyncValue` is an extension** — a TEST using it must
  `import 'package:flutter_riverpod/flutter_riverpod.dart'` directly (not
  transitive through the notifier).
- **`clamp()` returns `num`** — add `.toInt()`/`.toDouble()`.
- **Adding a param to a seam method breaks every fake** — e.g. `observePageContext`
  gained `relations`; the fake in `quiz_sheet_test.dart` needed updating. There's
  also a `_FakeMemory` in `study_planner_notifier_test.dart`. Any new
  `LearningMemoryRepository` method must be added to BOTH.
- **Native SQLite** compiles from source via `sqlite3` native assets (default-on
  this Flutter) — the `.apkg` writer round-trips in host tests. `sqlite3_flutter_libs`
  is EOL, deliberately dropped.
- **flutter_gemma exports `EmbeddingModelSpec`** — don't name anything that.
- **`gh` CLI is not installed** — use `curl` + the GitHub API, or `git` directly.

---

## 6. What's LEFT — start here next session

### 6a. On-device validation (owed, batched with the Phase 3 device pass)
Nabil runs a Xiaomi Pad 7 (Snapdragon 7+ Gen 3 / SM7675) + Android Studio
emulator. Nothing in Phase 2 has touched a device. When he's ready:
- Accept the licence at `huggingface.co/litert-community/embeddinggemma-300m`,
  create a read token, paste into **Settings → AI → HuggingFace Token** (or it's
  already picked up in debug from `dev_secrets.dart`). Download EmbeddingGemma
  from **Settings → AI Models** (~185 MB).
- Verify: gated download works; a RESTART re-activates the model WITHOUT
  re-downloading (this exercises the token-guard fix — guard gates downloads not
  activations); "Ask your notes" end-to-end on a real multi-page indexed
  notebook; the graph and plan populate.
- **Open STOP CONDITION:** measure brute-force vector-sweep latency on the Pad
  and tune `kMinRelevance` (currently a provisional 0.45 in `rag_retriever.dart`)
  from real numbers BEFORE reaching for a heavier vector store. The spec wants
  the numbers reported first.

### 6b. Phase 3 — Cloud Gateway / Router (the next BUILD phase)
Spec: `ai_prompts/04_phase3_cloud_gateway_router.md`. Scope (from the master
plan's locked-in decisions): a **minimal, stateless FastAPI AI Gateway** whose
only job is routing to cloud-tier models (Gemma 26B/31B, optional
Gemini/Claude/GPT). Local-first stays local-first — NO cloud note storage, auth,
or sync. Designed so Supabase can be added later without a rewrite, but that is
NOT built. Key existing seams it plugs into:
- `AiProvider` contract + `AiCapabilities` (already routable by cost/capability).
- `AiRouter` (`domain/ai_router.dart`) — already decides local vs cloud vs
  download-then-local; the cloud route is currently a `StubCloudLlmClient`.
- `cloud_llm_client.dart` — the stub to replace with a real gateway client
  (`cloud_gateway_provider.dart implements AiProvider`, per the spec).
- Privacy invariant: cloud requires BOTH the user's explicit opt-in
  (`settings.cloudAiEnabled`, default OFF) AND the note not fitting locally.

### 6c. Optional non-blocking polish
- Study-plan `strategyNote`: one grounded LLM call to add encouraging framing to
  a generated plan (field exists, defaulted ''). Graceful/optional.

---

## 7. Key file index

- **Progress log (detailed):** `AI_PROGRESS.md` — per-loop notes, decisions,
  tradeoffs. The source of truth for "why".
- **Vision + execution findings:** `ai_prompts/AI_Notebook_Master_Plan.md`
  (kept in check with an "execution findings" section).
- **Phase specs:** `ai_prompts/0X_phase*.md` (Phase 3 = `04_...`).
- **User changelog:** `CHANGELOG.md` (`[Unreleased]` holds the Phase 2 additions).
- **AI providers / wiring:** `lib/features/ai/presentation/ai_providers.dart`.
- **Isar schemas:** registered in `lib/main.dart`.
- **Routes:** `lib/app/router.dart` (`/note2/:id` + `book`/`graph`/`plan`).
- **Editor entry points:** `lib/editor/ui/notebook_editor_screen.dart` app-bar.
- **Memories** (auto-loaded): phase-2 status, RAG decisions, public-repo/secrets,
  version-bump, no-unprompted-start.

### Commands
```
dart run build_runner build --delete-conflicting-outputs   # after any Isar change
flutter analyze                                            # must be clean (baseline: no issues)
flutter test                                               # 579/579 as of this handoff
```
