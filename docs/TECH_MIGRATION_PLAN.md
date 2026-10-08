# DistillEd — Getting off discontinued packages

A phased plan to move every dependency that is discontinued or abandoned onto its maintained successor, refresh the rest of the stack, make the RAG pipeline swap-ready, and switch to EmbeddingGemma 2 once the runtime supports it. Grounded in the current codebase (pubspec `5.0.0+30`, `pubspec.lock` resolved on 3 Oct 2026) and in pub.dev / Hugging Face as of 8 Oct 2026.

- **Goal:** no discontinued or unmaintained package in `pubspec.lock`, latest stable majors where the upgrade is cheap, and a RAG pipeline where changing the embedding model is a one-line spec change with no search downtime
- **Reference device:** Pixel 7 Pro (Google Tensor G2, 11.7 GB RAM as the kernel reports it)
- **Order:** each phase ships on its own and passes its checks before the next one starts

Effort sizes are rough: **S** ≈ a day, **M** ≈ a few days, **L** ≈ a week or more.

| Phase | What | Can start | Effort |
|---|---|---|---|
| 1 | `flutter_gemma*` → `flutter_edge_ai*` | Now | S–M |
| 2 | `isar` → `isar_community` | After 1 | S |
| 3 | Riverpod 3, go_router 18, audio, tooling | After 2 | M |
| 4 | Make the embedding pipeline swap-ready | After 1 (best after 3) | M–L |
| 5 | Swap to EmbeddingGemma 2 | **Only when the support condition in 5.0 is met** | M |
| 6 | Retire the Hugging Face token machinery | After 5 | S |

---

## Instructions for the implementing agent

This file is written to be executed by Claude Code, one phase at a time. Follow these rules throughout.

1. **One phase per session. Never run `git commit`, `git push` or any other git command that changes history or the remote; the user commits and pushes manually.** Leave all changes in the working tree. At the end of each numbered step, print a short summary of the files changed and a suggested commit message naming the step (e.g. `Phase 2.1: switch to isar_community`), so the user can commit at that point if they want. Do not start the next phase in the same session unless the user says so.
2. **Never guess a package API.** After `flutter pub get`, read the package's own source under `~/.pub-cache/hosted/pub.dev/<package>-<version>/` (and its `CHANGELOG.md`) before writing calls against it. Where this plan says "confirm", that is the check.
3. **Green before moving on.** Run `dart format .`, `flutter analyze` and `flutter test` after every step. Do not continue past a failing step; fix it or stop and report.
4. **Device checks belong to the user.** Every phase ends with a *Device checks* list. You cannot run these. When a phase's code is done and green, stop, print that list, and ask the user to run it and report back.
5. **Preserve behaviour unless the step says otherwise.** In particular, Phases 1–4 must not change a single embedding vector for the current model. Phase 4 includes a golden-vector check for exactly this.
6. **Keep the codebase's comment style.** This codebase documents *why* in long comments. When code changes, update the comments that describe it (many mention `flutter_gemma` by name). Don't strip existing rationale.
7. **Never delete user data without a backup step first.** Phase 2 and Phase 4.5 touch stored data; follow their order exactly.
8. **Phase 5 is gated.** Check the condition in 5.0 first. If it is not met, do nothing in Phase 5 and report what you checked.
9. **At the end of each phase:** update `CHANGELOG.md`, the tech-stack table in `PROJECT_CONTEXT_PROMPT.md`, and any affected lines in `docs/AI_PIPELINE_PLAN.md` and `docs/ARCHITECTURE.md`; run `graphify update .` if `graphify-out/` exists; tick the phase in the **Progress log** at the bottom of this file with the date and a one-line summary of what changed.

---

## Audit: what is discontinued today

| Package (resolved) | Status | Successor | Phase |
|---|---|---|---|
| `flutter_gemma` 1.11.3 | **Discontinued** 5 Oct 2026; 1.11.4 is the last release under this name | `flutter_edge_ai` 2.1.0 | 1 |
| `flutter_gemma_litertlm` 1.8.5 | **Discontinued** (renamed) | `flutter_edge_ai_litertlm` 1.9.0 | 1 |
| `flutter_gemma_embeddings` 2.2.1 | **Discontinued** 5 Oct 2026 | `flutter_edge_ai_embeddings` 2.2.2 | 1 |
| `flutter_gemma_speech` 0.5.2 | **Final release** 0.5.3 says it moved | `flutter_edge_ai_speech` 0.5.4 | 1 |
| `isar` / `isar_flutter_libs` / `isar_generator` 3.1.0+1 | **Abandoned**: last release 25 Apr 2023; 4.0 never left `-dev` | `isar_community` 3.3.2 (+ `_flutter_libs`, `_generator`) | 2 |
| EmbeddingGemma 300M (`litert-community/embeddinggemma-300m`) | Superseded by EmbeddingGemma 2 (6 Oct 2026); still works | `litert-community/embeddinggemma-2-740m-litert-lm` | 4–5 |

Not discontinued but several majors behind (Phase 3):

| Package | In use | Latest |
|---|---|---|
| `flutter_riverpod` | 2.6.1 | 3.4.3 |
| `go_router` | 14.8.1 | 18.0.2 |
| `record` | 5.2.1 | 7.1.1 |
| `just_audio` | 0.9.46 | 0.10.6 |
| `pdfx` | 2.9.2 | 2.11.0 |
| `flutter_lints` | 4.0.0 | 6.x |
| `build_runner` | 2.4.13 | held back by `isar_generator` (analyzer 5.13) |

Checked 2026-10-09 against pub.dev. `dio` (5.10.0, one minor behind) and `printing` (5.15.0, one patch behind) are within a minor and need no plan item. `archive` (4.0.9; 4.3.0 published 13 September) and `sqlite3` (3.5.0; 3.7.0 published 30 September) are further behind than a minor, and no phase covers them yet. `share_plus` was a major release behind (12.0.2 pinned; 13.3.1 published 1 October). It was upgraded in the working tree on 9 October, not committed; see the Phase 3 progress entry. The earlier line called all of these current; that was wrong for `archive`, `sqlite3` and `share_plus`, which were all published before the migration started on 8 October. The ML Kit plugins, `pdfrx_engine`, `pdfium_flutter` and `flutter_math_fork` were not rechecked.

---

## Phase 1 — Flutter Gemma → Flutter Edge AI (the rename)

The four `flutter_gemma*` packages are discontinued as a set and must move as a set: the migration guide warns that mixing old and new packages duplicates the native libraries and Android classes, and the build fails. Installed models and the model directory stay where they are, so users download nothing again and the RAG index stays valid.

### 1.1 Swap the dependencies together

```yaml
  flutter_edge_ai: 2.1.0
  flutter_edge_ai_litertlm: 1.9.0
  flutter_edge_ai_speech: 0.5.4
  flutter_edge_ai_embeddings: 2.2.2
```

These four resolve together: `litertlm` 1.9.0 and `speech` 0.5.4 need `flutter_edge_ai ^2.1.0`, `embeddings` 2.2.2 needs `^2.0.0`. All need Dart ≥ 3.12 and Flutter ≥ 3.44; you are already on Flutter ≥ 3.47 for `pdfium_flutter`. Keep the exact pins, as today, because the API is still moving. If pub reports newer patch releases, take them and note the versions in the step summary.

- **Where:** `pubspec.yaml` (the AI block and its comments)
- **Effort:** S

### 1.2 Rewrite imports and class names

1. Find and replace `package:flutter_gemma` → `package:flutter_edge_ai` (this also catches `_litertlm`, `_embeddings` and `_speech`).
2. Run `dart fix --apply`. It renames `FlutterGemma` → `FlutterEdgeAi`, `FlutterGemmaPlugin`, `GemmaLogLevel` and the diagnostics names; the 2.0.0 changelog says it still migrates code even though the deprecated aliases are gone. If it misses anything, step through `flutter_edge_ai` 1.11.4 first (it compiles the old names as deprecated aliases), fix the warnings there, then bump to 2.1.0.
3. `LiteRtEmbeddingBackend` is now exported from `flutter_edge_ai_litertlm`, not the embeddings package. Fix the import in `gemma_adapter.dart`.
4. Rename the app's own wrappers so the code reads honestly: `FlutterGemmaRuntime`, `FlutterGemmaInstaller`, `FlutterGemmaEmbedderInstaller`, `FlutterGemmaEmbeddingRuntime`, `FlutterGemmaStorageCleaner`, `FlutterGemmaSpeechInstaller`, `FlutterGemmaSpeechToText`, and the file `features/audio/data/flutter_gemma_speech.dart` (plus its test). Suggested names: `EdgeAi…` (e.g. `EdgeAiRuntime`, `EdgeAiEmbeddingRuntime`). `GemmaBootstrap` can stay; it still bootstraps Gemma.

Files that import the plugin today: `gemma_adapter.dart`, `llm_model_spec.dart`, `model_download_manager.dart`, `model_storage_cleaner.dart`, `embedder_adapter.dart`, `embedder_spec.dart`, `embedder_download_manager.dart`, `flutter_gemma_speech.dart`, `ai_providers.dart`, plus the matching tests under `test/features/ai/data/` and `test/features/audio/`.

- **Effort:** S

### 1.3 Absorb the 2.0 / 2.1 breaking changes

| Break | Affects DistillEd? |
|---|---|
| RAG moved to `flutter_edge_ai_rag`; `initialize()` drops `vectorStore:` / `filterSchema:` | **No.** The app keeps its own Isar chunk store and never used plugin RAG. Do not add `flutter_edge_ai_rag`. |
| `ModelFileManager.setActiveModel` removed | **No** call sites. |
| `isThinking` → `enableThinking` (2.1.0) | **No** call sites today; use the new name if thinking is ever enabled. |
| `initialize()` takes `inferenceEngines`, `embeddingBackends`, `embeddingTokenizers`, `huggingFaceToken` | Same shape as `GemmaBootstrap.registrations` plus `sttBackends`. Confirm `sttBackends` is still the parameter name for speech in 2.1. |
| Embedder profiles (`EmbeddingProfile`, `activeEmbedderProfileId`) | Documented for plugin-owned RAG stores. Confirm `getActiveEmbedder()` doesn't now demand one for raw `generateEmbeddings`. |
| `EmbeddingModel` gained `activeBackend` and `isClosed` | Only matters to fakes that implement the interface; the app wraps it behind `EmbeddingSession`, so fakes should be unaffected. |

- **Where:** `gemma_adapter.dart` (`GemmaBootstrap`), `embedder_adapter.dart`, `flutter_gemma_speech.dart`
- **Effort:** S

### 1.4 Clean build

Run `flutter clean`, delete the plugin's cached native library directory (`flutter_gemma/native` under the OS cache, per the migration guide's troubleshooting note), `flutter pub get`, `flutter analyze`, `flutter test`, and an Android release build (`flutter build apk --release`) to catch duplicate-class or native-library errors.

Unit tests to watch: `gemma_bootstrap_test.dart`, `flutter_gemma_runtime_test.dart`, `local_text_embedder_test.dart`, `embedder_spec_identity_test.dart`, `flutter_gemma_speech_test.dart`, `model_storage_cleaner_test.dart`.

### Device checks — Phase 1

- [ ] Gemma 4 E2B loads, answers a text question, reads an image; the GPU is actually active (`activeBackend`)
- [ ] "Ask your notes" works over an index built **before** the upgrade (proves vectors and `modelId` are unchanged, so no re-index happened)
- [ ] Lecture transcript with Whisper
- [ ] Settings → storage cleanup still lists orphans correctly and deletes nothing that is installed

---

## Phase 2 — Isar → Isar Community

`isar` 3.1.0+1 has had no release since April 2023 and 4.0 never shipped a stable build. Staying on it has two concrete costs:

- **Android 16 KB pages.** Google Play requires 16 KB page-size support for apps targeting Android 15+. `isar_community` added it in 3.2.0-dev.1; the original 3.1.0 native library predates it.
- **It pins the whole codegen chain.** `isar_generator` 3.1.0 holds `analyzer` at 5.13, `source_gen` at 1.5 and `build_runner` at 2.4.13. An analyzer that old won't parse newer Dart syntax, so it blocks Phase 3. `isar_community_generator` 3.3.2 supports analyzer 8–10 and `source_gen` 4.

`isar_community` is the maintained fork of the same 3.x line, so the API is the one you already use (`Isar.open` with a required `directory`, `CollectionSchema`, `@collection`).

### 2.1 Swap packages and regenerate

```yaml
dependencies:
  isar_community: ^3.3.2
  isar_community_flutter_libs: ^3.3.2
dev_dependencies:
  isar_community_generator: ^3.3.2
  build_runner: <newest that resolves with source_gen 4>
```

Replace `package:isar/isar.dart` → `package:isar_community/isar.dart` everywhere (`isar_service.dart`, every `*_record.dart`, the stores, the legacy migration models, `main.dart` if it imports Isar types), then `dart run build_runner build --delete-conflicting-outputs` to regenerate all `*.g.dart`. Diff the regenerated schemas against the old ones: collection names, property names and index names must not change, or existing data won't be found.

- **Effort:** S

### 2.2 Add a collection-count debug readout

Add a debug-only (`kDebugMode`) section to the Settings screen, or a debug log at startup, that prints `count()` for every Isar collection registered in `main.dart`. This is what the user compares before and after the upgrade in the device check. Keep it; Phase 4.5 reuses it.

- **Effort:** S

### Device checks — Phase 2

This is the step that can lose user notes, so do it in this order:

1. [ ] On the **old** build, record the debug counts (or, before 2.2 exists, the number of notebooks/pages/flashcards visible in the UI).
2. [ ] Back up the app's data (`adb backup`, or copy the Isar file out of app storage).
3. [ ] Install the Phase 2 build **over** the old one (don't uninstall).
4. [ ] Counts match. Open library, notebooks, pages, search, flashcards, study planner, summaries, lecture recordings, Ask your notes.
5. [ ] Open a legacy `.ink` notebook so `launch_migration` runs under the new generator.

`isar_community` updated its storage engine (libmdbx 0.13.x). The changelog doesn't state on-disk compatibility in so many words, which is why this is a device check, not an assumption.

---

## Phase 3 — Refresh the rest of the stack

None of these are discontinued, but each is a breaking major. One step at a time, in this order, with the full test suite after each.

### 3.1 Tooling: `flutter_lints` 4 → 6, `build_runner` latest

Unblocked by Phase 2. Fix the new lint findings in the same step, or suppress with a one-line reason, so later diffs stay clean.

- **Effort:** S

### 3.2 Riverpod 2.6 → 3.x

`ai_providers.dart` alone has 10 `StateNotifierProvider`s and a `StateProvider`. Breaking changes that touch this codebase:

- `StateNotifierProvider` / `StateProvider` / `ChangeNotifierProvider` move to `package:flutter_riverpod/legacy.dart`. Change the imports now; don't port them to `Notifier` in this step.
- `Ref` loses its type parameter, and `AutoDispose*` types merge into the plain ones.
- **Failing providers now retry automatically.** For model loads and downloads that is wrong: a missing model would be retried in a loop. Set `retry: (_, __) => null` on the root `ProviderScope` and on every `ProviderContainer` in tests. Opt in per provider only where a retry is clearly safe.
- **Providers pause when their widget is off-screen.** Check that background indexing (`rag_index_scheduler.dart`, `notebook_index_notifier.dart`) and the download notifiers keep running when the user leaves the screen; if they don't, move the work out of a widget-scoped listener.
- Using `ref` after an `await` once the provider is disposed now throws `UnmountedRefException`; guard with `ref.mounted`. Check the long async notifiers: `ask_notes_notifier.dart`, `explain_notifier.dart`, `summarize_notifier.dart`, `lecture_transcription_notifier.dart`, `recording_notifier.dart`, `model_download_notifier.dart`, `speech_model_notifier.dart`.
- Errors arrive wrapped in `ProviderException`; anything that catches `AiModelNotReadyException` (or another typed exception) from a provider read must unwrap `.exception`.

- **Effort:** M

### 3.3 `go_router` 14 → 18

- 15.0: paths are case-sensitive by default. Check `app/router.dart` and any link built from a notebook title.
- 17.0: `ShellRoute` navigation now notifies the root observers; only matters if observers are added.
- 18.0: needs Flutter ≥ 3.44 (already met) and moves to `material_ui` / `cupertino_ui`.

- **Effort:** S

### 3.4 Audio: `record` 5 → 7, `just_audio` 0.9 → 0.10

Both sit behind `AudioCapturePort` / `AudioPlaybackPort`, so the change stays in `record_audio_capture.dart` and `just_audio_playback.dart`. Remove the `record_platform_interface: 1.1.0` override and keep it removed if pub resolves without it.

- **Effort:** S

### 3.5 Small bumps

`pdfx` 2.11, `file_picker`, `image_picker`, `package_info_plus`: take the latest that resolve, run tests. Do **not** replace `pdfx` with `pdfrx` in this plan.

- **Effort:** S

### Device checks — Phase 3

- [ ] Navigate every route, including deep links into a notebook and back
- [ ] Start a bulk index, leave the screen, come back: progress continued
- [ ] Download a model, leave the screen mid-download: it continued
- [ ] Record a lecture, play it back, transcribe it
- [ ] Ask a question with the model **not** downloaded: one clear "not downloaded" message, no retry loop

---

## Phase 4 — Make the embedding pipeline swap-ready

The goal: when EmbeddingGemma 2 becomes usable, switching is a spec change plus a background re-index, with search working the whole time. Nothing in this phase changes which model runs or any vector it produces.

What already exists and must be kept: `EmbedderSpec.active` is the single switch; every chunk stores `embeddingModelId`; `RagRetriever` refuses to compare vectors across models; `RagIndexer` re-embeds a page when its stored model id differs; RAG depends only on `TextEmbedder`.

What is missing is below, in implementation order.

### 4.1 Golden-vector guard (do this first)

Every later step must leave the current model's vectors byte-for-byte identical, and nothing checks that today.

- Add `integration_test/embedding_golden_test.dart`: embeds three fixed inputs (one English, one Bangla, one with a notebook title, as both `document` and `query`) with the active spec, and compares to vectors stored in `integration_test/golden/<modelId>.json` with a tolerance of 1e-5 per component.
- Add a `--update-golden` mode (via `--dart-define=UPDATE_GOLDEN=true`) that writes the file instead of comparing. The user generates the file once on the Pixel 7 Pro **before** any Phase 4 code change lands, and adds it to the repository.
- This runs on a device only. List it in the device checks; don't try to run it.

- **Effort:** S

### 4.2 Spec carries everything that defines the vector space

Refactor `EmbedderSpec` so that a model is fully described by data:

| Field | Purpose | Value for the current 300M spec |
|---|---|---|
| `format` | `EmbedderFormat.tfliteWithTokenizer` or `EmbedderFormat.litertlmBundle` | `tfliteWithTokenizer` |
| `tokenizerUrl` | Now **nullable**; required only for `tfliteWithTokenizer` (assert in the constructor) | unchanged |
| `files` | All on-disk filenames this spec installs (model, plus tokenizer if any). Replaces direct uses of `modelFilename` + `tokenizerFilename` in install, uninstall, `isInstalled`, `isPartiallyInstalled` and the storage cleaner | `[modelFilename, tokenizerFilename]` |
| `maxInputTokens` | The model's input window as used by this build | `512` |
| `chunkWords` | Words per chunk for this model (see 4.4) | `250` (today's `kChunkWords`) |
| `chunkOverlapWords` | Overlap for this model | `30` (today's `kChunkOverlapWords`) |
| `promptContract` | Who adds the task prefixes and what they are (see 4.3) | `PromptContract.pluginGemma300m` |
| `runtimeSupported` | False for a spec the app knows about but can't run yet | `true` |

Rules, enforced by `embedder_spec_identity_test.dart`:
- `modelId` must contain `promptContract.id`, and must change whenever `maxInputTokens`, `chunkWords`, `promptContract` or the model file changes. Express it as a test over every spec in the registry: two specs with different values for any of those fields must have different `modelId`s.
- **The 300M spec's `modelId` stays exactly `embeddinggemma-300m-seq512-titled`.** Changing it would trigger a full re-index for every user for no reason. Its `promptContract.id` must therefore be a substring of that string; use `titled` as the id of `PromptContract.pluginGemma300m`.

Add a registry: `EmbedderSpec.all` (every known spec), `EmbedderSpec.active` (unchanged role), `EmbedderSpec.retired` (specs whose files should be removed after a completed swap; empty for now).

- **Where:** `embedder_spec.dart`, `embedder_adapter.dart`, `embedder_download_manager.dart`, `model_storage_cleaner.dart`, tests
- **Effort:** M

### 4.3 Make the prompt contract explicit

Today the plugin prepends the prefixes (`TaskType.retrievalDocument` → `title: none | text: `, `TaskType.retrievalQuery` → `task: search result | query: `), and the app puts the notebook title at the front of the text because the plugin always writes `none`. That behaviour must stay exactly as is for the 300M model.

- Add a `PromptContract` value type: `id`, `appliedBy` (`plugin` or `app`), `documentPrefix(String? title)`, `queryPrefix`, and `titleInText` (bool: whether the title rides at the front of the text, as today).
- `PromptContract.pluginGemma300m`: `appliedBy: plugin`, `titleInText: true`. The prefix strings are recorded for documentation and tests; the app does not apply them.
- Move the "title at the front of the text" logic (`_embeddingInput` in `rag_indexer.dart`) behind the contract, so a future contract can instead put the title in the prefix.
- Add `PromptContract.appOwned(...)` support in the runtime: when `appliedBy == app`, the embedder adds the prefix itself and asks the runtime for **no** prefix. Read the `flutter_edge_ai_embeddings` source to find whether the plugin can embed raw text without a prefix. If it can't, leave `appOwned` unimplemented (throw `UnsupportedError`) and note it in the Progress log; it is only needed in Phase 5.
- Leave a placeholder contract for EmbeddingGemma 2 with both candidate prefix sets recorded as data (see 5.2) and no default chosen.

- **Where:** new `domain/rag/prompt_contract.dart`, `embedder_spec.dart`, `embedder_adapter.dart`, `rag_indexer.dart`, tests
- **Effort:** S

### 4.4 Chunk size comes from the spec

`page_chunker.dart` uses the constants `kChunkWords = 250` and `kChunkOverlapWords = 30`. Make `RagIndexer` (and `bulk_indexer.dart`) pass `spec.chunkWords` / `spec.chunkOverlapWords` into `chunkPage`, keeping the constants only as the 300M spec's values. The comment block about "~330 tokens inside the 512-token variant" moves to the 300M spec.

`TextEmbedder` gains read-only `chunkWords` and `chunkOverlapWords` (or a `spec` getter), so the domain layer doesn't import the data-layer spec.

- **Effort:** S

### 4.5 Shadow re-index: switch models without a search gap

Today, the moment `EmbedderSpec.active` changes, every stored chunk stops being searchable until its page is re-embedded. Replace that with a rollout that indexes in the background under the new model while questions keep using the old one, then cuts over.

**State.** A persisted `EmbedderRollout` (in `shared_preferences`): `servingModelId`, `targetModelId` (nullable), `status` (`idle`, `downloading`, `indexing`, `ready`, `cuttingOver`), `indexedPages`, `totalPages`, `startedAt`. A Riverpod notifier owns it.

**Storage.** `note_chunk_store.dart` currently replaces all chunks of a page on save. Change it so chunks are keyed by `(pageId, embeddingModelId)`: saving target-model chunks for a page must not delete that page's serving-model chunks. Add an Isar composite index on `(pageId, embeddingModelId)` (added indexes are an automatic, non-destructive Isar migration, but confirm this in the `isar_community` source). The per-page index state that `RagIndexer._indexStateOf` reads must likewise become per `(pageId, modelId)`.

**Flow.**
1. *Start:* the target spec's files are downloaded through the existing download manager (`downloading`).
2. *Index:* a background job (the existing bulk indexer, running as the foreground-service job described in `docs/AI_PIPELINE_PLAN.md`) embeds every indexable page with the target model (`indexing`). The two embedders are never resident together: the job holds only the target embedder, and the serving embedder loads only for questions, behind its own mutex as today.
3. *While indexing:* `RagRetriever` searches with the **serving** embedder over serving-model chunks only. A page edited during the rollout is re-embedded with the serving model immediately (so search stays fresh) and queued for the target model.
4. *Cut over* when every indexable page has target-model chunks (`ready` → `cuttingOver`): set `servingModelId = targetModelId`, delete all chunks whose model id is neither, uninstall the retired spec's files (4.6), set `status = idle`. Make cut-over idempotent so a crash mid-way resumes cleanly on next launch.
5. *Cancel / rollback:* delete target-model chunks and the target files; serving is untouched.

**What "active" means now.** `EmbedderSpec.active` becomes "the spec new installs start with". On upgrade, if the persisted `servingModelId` differs from `EmbedderSpec.active.modelId`, the app starts a rollout automatically on Wi-Fi and charging; until then it keeps serving the old model. Fresh installs skip the rollout and serve the active spec directly.

**UI.** Settings → AI shows "Upgrading search model: x of y pages" with Pause / Cancel while a rollout runs. No dialog; search keeps working.

**Tests.** Unit-test the state machine (start, progress, edit during rollout, crash and resume at every status, cancel), the store keying, and that the retriever never mixes model ids. Use two fake specs; no device needed.

- **Where:** new `data/embeddings/embedder_rollout.dart` + notifier, `note_chunk_store.dart`, `note_chunk_record.dart` (index), `rag_indexer.dart`, `rag_retriever.dart`, `bulk_indexer.dart`, `rag_index_scheduler.dart`, `local_text_embedder.dart` (one instance per spec), `ai_providers.dart`, `settings_screen.dart`
- **Effort:** L — the biggest step in the plan

### 4.6 Remove the retired model's files after cut-over

`model_storage_cleaner.dart` protects only the active specs' files (`_knownModelFiles`), and the plugin doesn't treat an installed-but-unused model as an orphan. So a retired model's ~175 MB would stay forever. At cut-over, call the installer's `uninstall(retiredSpec)` for each spec in `EmbedderSpec.retired` that is installed. Extend `_knownModelFiles` to protect the **serving and target** specs during a rollout, not only `EmbedderSpec.active`.

- **Effort:** S

### 4.7 Runtime chosen by format, with a stub for bundles

`LocalTextEmbedder` always builds `FlutterGemmaEmbeddingRuntime` (renamed in Phase 1). Make the runtime and installer come from a small factory keyed on `spec.format`:

- `tfliteWithTokenizer` → the existing runtime and installer, unchanged.
- `litertlmBundle` → `LiteRtLmBundleEmbeddingRuntime` / `…Installer` that throw a typed `EmbedderRuntimeUnsupportedException` (mapped to `AiModelNotReadyException` with a clear message). Phase 5 replaces the bodies; nothing else should need to change.

The UI must never offer a spec with `runtimeSupported == false` for download or rollout.

- **Where:** `embedder_adapter.dart`, `local_text_embedder.dart`, `ai_providers.dart`
- **Effort:** S

### 4.8 Add the EmbeddingGemma 2 spec, disabled

Add `EmbedderSpec.embeddingGemma2` with the values known today and `runtimeSupported: false`:

- `format: litertlmBundle`, `tokenizerUrl: null`
- `modelUrl: https://huggingface.co/litert-community/embeddinggemma-2-740m-litert-lm/resolve/main/embeddinggemma-2-740m.litertlm`
- `approxSizeBytes: 484622336` (as listed by the Hugging Face API on 8 Oct 2026)
- `dimensions: 768`, `needsAuth: false`
- `maxInputTokens`, `chunkWords`, `chunkOverlapWords`, `promptContract`: **left as clearly marked TODO values** decided in Phase 5 from the evaluation. The identity test must still pass (give it a provisional `modelId` such as `embeddinggemma-2-740m-UNSET`).

The generic file is the right one for the Pixel 7 Pro: its Tensor G2 (GS201) matches none of the per-SoC builds (SM8550/8650/8750/8850, Tensor G5/G6, MT6991/6993).

- **Effort:** S

### 4.9 Evaluation harness

Benchmarks don't cover Bangla or OCR'd handwriting, which is most of what DistillEd embeds. Build a harness the user runs on a computer:

- `tool/embedding_eval/eval.py` + `requirements.txt` (`sentence-transformers>=6.1`, `torch`, `numpy`) + `README.md`.
- Input: `eval_set.jsonl`, one line per question: `{"query": "...", "lang": "en|bn", "relevant_ids": ["page-12-c0", ...]}`, plus `corpus.jsonl`: `{"id": "...", "title": "...", "text": "..."}`.
- Add a debug-only "Export RAG corpus" action in Settings that writes `corpus.jsonl` from the current chunk store (chunk id, notebook title, chunk text) to the share sheet. The user writes the questions.
- The script embeds the corpus and queries with `google/embeddinggemma-300m` and `google/embeddinggemma-2` (bf16 or fp32, never fp16), under each candidate prompt contract, at chunk sizes 250 / 500 / 1000 words and at 768 and 512 dimensions, and prints recall@1/5/10 and MRR per language as a table, plus a CSV.
- Note in the README that this measures the full-precision weights; Phase 5 repeats the winning configuration on the device build.

- **Effort:** S

### Device checks — Phase 4

- [ ] **Before** any other Phase 4 code change: run 4.1 in update mode on the Pixel 7 Pro and add the golden file to the repository
- [ ] After all of Phase 4: golden test passes (vectors unchanged)
- [ ] Ask your notes still works on an existing index without a re-index
- [ ] Rollout dry run with a debug-only second spec that is a copy of the 300M spec under a different `modelId`: progress shows, questions keep working throughout, cut-over leaves exactly one model's chunks (check the debug counts from 2.2), the copy's files are removed, killing the app mid-rollout and relaunching resumes it
- [ ] Export RAG corpus produces a valid `corpus.jsonl`

---

## Phase 5 — Swap to EmbeddingGemma 2

### 5.0 The condition (check before doing anything)

The app runs embeddings through `LiteRtEmbeddingBackend`, which loads a `.tflite` graph plus a SentencePiece tokenizer. EmbeddingGemma 2 is published for LiteRT only as a `.litertlm` bundle, which needs LiteRT-LM's `EmbeddingEngine`. As of 8 Oct 2026 nothing in the `flutter_edge_ai*` packages supports that.

Proceed with Phase 5 only if **one** of these is true, and record which in the Progress log:

- **A (preferred).** A released `flutter_edge_ai_litertlm` / `flutter_edge_ai_embeddings` version loads `.litertlm` embedding models. Check their changelogs and source for EmbeddingGemma 2, `.litertlm` embedders, or a LiteRT-LM `EmbeddingEngine` binding.
- **B.** The LiteRT-LM native library that `flutter_edge_ai_litertlm` already ships exports the embedding engine's C API (inspect the library's exported symbols and LiteRT-LM's C headers for that version), so the app can bind it with `dart:ffi` behind `LiteRtLmBundleEmbeddingRuntime`. Spike this for at most two days; if it works, offer it upstream as a PR.
- **C (only with the user's explicit go-ahead).** An Android-only platform channel to `com.google.ai.edge.litertlm:litertlm-android`'s `EmbeddingEngine`. Risk: a second copy of the LiteRT-LM native library next to the plugin's, the duplicate-native-library failure the migration guide warns about. Prove it builds and both runtimes load in one process before writing anything else.
- **D.** Google's announced ML Kit embedding service has shipped and serves EmbeddingGemma 2 (Android-only, model version not under your control).

If none holds, stop and report.

### 5.1 Implement the bundle runtime

Fill in `LiteRtLmBundleEmbeddingRuntime` and its installer using the route from 5.0. Single-file install through the existing download manager (resumable, progress, cancel), text encoder only (`visionBackend` / `audioBackend` unset), CPU backend first. Returned vectors must be L2-normalised 768-float lists so `vector_math.dart` and `_verifyShape` are unchanged; if truncating to 512 dimensions, truncate and then re-normalise.

### 5.2 Decide the open spec values from the evaluation

The Hugging Face card and Google's LiteRT-LM docs give different prefixes:

| Source | Document | Query |
|---|---|---|
| Hugging Face card | `title: {title} \| text: {content}` | `task: search result \| query: {q}` |
| LiteRT-LM docs | `task: search result \| text:` | `task: search query \| text:` |

Run the 4.9 harness, then repeat the best two configurations against the device runtime (a debug-only screen or integration test that runs the eval set through `TextEmbedder`). Set `promptContract`, `chunkWords`, `chunkOverlapWords`, `maxInputTokens` and `dimensions` on `EmbedderSpec.embeddingGemma2` from the results, give it its final `modelId` (e.g. `embeddinggemma-2-text-<promptContract.id>-w<chunkWords>`), and set `runtimeSupported: true`. Generate its golden file on the Pixel 7 Pro.

**Gate:** switch only if EmbeddingGemma 2 is at least as good as the 300M model on the eval set overall and not worse on Bangla. If it is worse, stop and report the table; the token removal in Phase 6 alone is not worth worse search.

### 5.3 Flip and roll out

Set `EmbedderSpec.active = embeddingGemma2` and add `embeddingGemma300m` to `EmbedderSpec.retired`. Existing users get the 4.5 rollout; new installs start on EmbeddingGemma 2. Update the free-space check and download copy for ~485 MB.

### Device checks — Phase 5

- [ ] Peak memory with Gemma 4 E2B resident plus the EmbeddingGemma 2 text encoder stays inside budget on the Pixel 7 Pro (Google measured ~191 MB active for text-only on a Pixel 11 Pro)
- [ ] Per-chunk embedding latency and a full re-index of a large notebook: time and battery
- [ ] Rollout from a real 300M index to EmbeddingGemma 2 with search working throughout, then the 300M files gone
- [ ] Fresh install: no Hugging Face token asked for embeddings
- [ ] Eval set on device matches the desktop ranking within a couple of points

- **Effort:** M once 5.0 is met

---

## Phase 6 — Retire the Hugging Face token machinery

After Phase 5 has shipped and no supported spec has `needsAuth: true`, nothing the app downloads is gated: Gemma 4 E2B and Whisper already come from ungated repos, and EmbeddingGemma 2 is Apache 2.0 and ungated.

Remove `hf_token_check.dart`, `hf_access_check.dart`, `EmbedderTokenRequiredException`, the token field in Settings and its provider, and their tests (`hf_token_check_test.dart`, `hf_access_check_test.dart`, `settings_hugging_face_token_test.dart`). Keep `url_launcher` only if `core/utils/external_links.dart` is still used for something else. Leave the persisted token value cleared on first launch.

Keep `needsAuth` on the spec type itself so a future gated model still works; just no UI for it until one is needed.

- **Effort:** S

---

## Later (not in this plan)

- **Multimodal search.** With the vision and audio encoders loaded (about 567 MB total), EmbeddingGemma 2 puts figures and lecture audio in the same vector space as text, so Ask your notes could find a diagram or a moment in a recording without a Gemma vision pass first.
- **One PDF engine.** `pdfx` renders and `pdfrx_engine` reads text; `pdfrx` could do both.

---

## Progress log

Tick each item with the date and a one-line summary when it's done. Note anything skipped or deferred and why.

- [x] Phase 1 — code (2026-10-08: flutter_gemma* replaced by flutter_edge_ai* 2.1.0 / 1.9.0 / 0.5.4 / 2.2.2; imports, classes, speech file and comments renamed; analyze at baseline (3 infos), 2084 tests pass, release APK builds (285.6 MB). Skipped: repo-wide `dart format .` (274 files were already unformatted at baseline))
- [ ] Phase 1 — device checks (user)
- [x] Phase 2 — code (2026-10-08: isar → isar_community 3.3.2 with flutter_libs and generator; imports rewritten in 34 files; build_runner 2.15.1 is the newest that resolves with source_gen 4; regenerated .g.dart files differ only in the generator version line, so collection, property and index definitions are unchanged; debug-only row counts logged at startup; analyze at baseline (3 infos), 2084 tests pass. Skipped: the plan's --delete-conflicting-outputs, which repo memory forbids)
- [ ] Phase 2 — device checks (user)
- [x] Phase 3 — code (2026-10-08: flutter_lints 6.0.0; flutter_riverpod 3.4.3 with legacy imports, valueOrNull to value, the context panel's last shown value replacing the internal copyWithPrevious, ProviderException unwrapped in the five error mappers, retry disabled in every scope; go_router 18.0.2 with routes checked; record 7.1.1 and just_audio 0.10.6 with the record_platform_interface override dropped; pdfx 2.11.0, image_picker 1.2.4, file_picker 10.3.10 (11.0.3 fails the Android release build; the cause is not isolated) and package_info_plus 9.0.1 (10.x needs win32 6, which share_plus 12.0.2 blocks); analyze clean; 2084 tests pass. Skipped: build_runner 2.16.2, which needs analyzer above what isar_community_generator allows)
- Phase 3, share_plus, file_picker and package_info_plus (2026-10-09, done in the working tree, not committed): share_plus 13.3.1, file_picker 13.1.0 and package_info_plus 10.2.2, which resolve together with win32 6.4.0. Code: the PDF picker in scene_import_service.dart uses `FilePicker.pickFile`, because file_picker 13 has no `platform` accessor and `pickFiles` no longer returns a single file, and `allowMultiple` defaults to true from file_picker 12.0.0. The share call and the About screen's PackageInfo call needed no change. Checks: analyze clean; 2201 host tests pass; About shows Version 5.0.0 (build 30); the PDF export opens the system share sheet with the file. Not checked on the phone: PDF import, because the import button sits in the toolbar part that overflows on this device (the known overflow, deferred). Release: see the release entry below.
- [ ] Phase 3 — device checks (user)
- [ ] Phase 4 — golden file generated on device (user, before 4.2+)
- [ ] Phase 4 — code (4.1 – 4.9): 4.1 harness written 2026-10-08 (integration_test/embedding_golden_test.dart, integration_test dev dependency); not run. 4.2 onward waits for the golden file generated on the Pixel 7 Pro.
- [ ] Phase 4 — device checks (user)
- [ ] Phase 4.5 — dry run (2026-10-09): code and host tests done. The rollout can move between EmbeddingGemma 300M and a debug-only copy of it (`EmbedderSpec.dryRunCopy`, in debug builds only); questions and the bulk index follow the serving model; the Settings debug row drives the dry run. Full host suite: 2201 passed, 3 skipped; analyze clean. Run on the phone with the go-ahead: the copy was installed and rolled out to (the cut-over removed the 300M files and their chunks; 6 chunks remained). Questions were answered with the copy (top score 0.535), and again after the rollback to 300M (same score). The 300M files came back by download with matching sha256, and the copy files were removed. The golden compare matched. Not tested: questions during indexing and a kill mid-run, because the two-page rollout finishes in about 4 s.
- Phase 3 follow-up (2026-10-09): flutter_edge_ai 2.1.1 and flutter_edge_ai_litertlm 1.10.0 (litertlm 1.10.0 requires flutter_edge_ai ^2.1.1; LiteRT-LM v0.18.0). Golden compare on the phone with --no-uninstall: vectors match, and the database checksum is unchanged. Gemma on the phone: Ask answered with sources, Summarize rendered, and the engine initialized. The first Ask after a fresh start took 36.5 s to create the engine, and its retrieval embedding took 17.6 s; a second Ask reused the engine. No same-device timing exists for 1.9.0, so the cold-start change is not established. Not checked: the Settings row's backend text.
- Release build (2026-10-09): the working tree does not build for release. GeneratedPluginRegistrant registers dev.flutter.plugins.integration_test (the golden harness, Phase 4.1), and release builds leave out dev dependencies, so that reference does not compile. The pinned tree before these changes fails the same way, so the failure is not from the package changes. A scratch copy with only that dev dependency removed release-builds with the current pins (flutter_edge_ai 2.1.1, flutter_edge_ai_litertlm 1.10.0, share_plus 13.3.1, file_picker 13.1.0, package_info_plus 10.2.2; APK 214.7 MB). Needs a decision: move the golden harness out of the app's pubspec, or another fix.
- [ ] Phase 5 — condition met: route B looks available (libLiteRtLm exports litert_lm_embedding_engine_create, _compute_embedding and _compute_embedding_batch); route A not met (no flutter_edge_ai release loads .litertlm embedding models); checked 2026-10-08; spike not started
- [ ] Phase 5 — evaluation results recorded
- [ ] Phase 5 — code
- [ ] Phase 5 — device checks (user)
- Phase 5 deferred (2026-10-09, user decision): EmbeddingGemma 2 is still not available, so Phase 5 is not started. The shipped app and the tests keep EmbeddingGemma 300M (`embeddinggemma-300m-seq512-titled`). Phase 6 needs the shipped spec to be ungated, so it waits with Phase 5.
- [ ] Phase 6 — code

---

## Sources

- [Flutter Edge AI migration guide](https://flutteredge.ai/docs/migration)
- [`flutter_edge_ai` changelog](https://pub.dev/packages/flutter_edge_ai/changelog)
- [`flutter_edge_ai_litertlm` changelog](https://pub.dev/packages/flutter_edge_ai_litertlm/changelog)
- [`flutter_edge_ai_embeddings`](https://pub.dev/packages/flutter_edge_ai_embeddings)
- [`flutter_edge_ai_speech`](https://pub.dev/packages/flutter_edge_ai_speech)
- [`flutter_gemma` changelog (final release)](https://pub.dev/packages/flutter_gemma/changelog)
- [`isar` on pub.dev](https://pub.dev/packages/isar)
- [`isar_community` changelog](https://pub.dev/packages/isar_community/changelog)
- [Riverpod 3.0 migration guide](https://riverpod.dev/docs/3.0_migration)
- [`go_router` changelog](https://pub.dev/packages/go_router/changelog)
- [EmbeddingGemma 2 model card](https://huggingface.co/google/embeddinggemma-2)
- [EmbeddingGemma 2 LiteRT-LM build](https://huggingface.co/litert-community/embeddinggemma-2-740m-litert-lm)
- [LiteRT-LM embedding models](https://developers.google.com/edge/litert-lm/embedding_models)
- [Google Developers Blog: EmbeddingGemma 2 on the edge](https://developers.googleblog.com/google-ai-edge-with-embeddinggemma-2/)
