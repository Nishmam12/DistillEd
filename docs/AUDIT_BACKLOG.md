# Audit backlog

Left over from the 2026-10-09 audit of the app and its AI pipeline. The first pass (gateway cost caps, scene-write atomicity, delete cascades, migration safety, release signing/CI/backup, repo hygiene, image cache, mastery fixes) is done and uncommitted at the time of writing. Everything below is **not done**.

Paths are relative to the repo root. Severity is the auditor's call; items were read from code, not all reproduced.

## Suggested next

1. ~~Embedder rollout trigger + startup resume (AI index, High)~~ — done
2. ~~Cloud opt-in enforced at the transport (gateway client, Medium)~~ — done
3. Token-based chunking (Bangla/Devanagari truncation, Medium)

## AI pipeline

### High
- ~~**Embedder upgrade has no trigger.**~~ **Done.** `EmbedderRolloutRunner.resume` (called from `embedderRolloutResumeProvider` at launch) pins the serving id, starts a rollout when `EmbedderSpec.active` changes, and resumes an interrupted one; `EmbedderRollout.answeringModelId` points questions at the target during a cut-over. The download needs the HuggingFace token, and on a metered network waits for the user's answer (dialog, then a Settings toggle); it re-checks every 2 minutes while the app is open (a connectivity listener would react at once).

### Medium
- **Rollout embeds different text than the live/bulk paths.** `_rolloutPages` (`ai_providers.dart`) reads `PageTextRecord.text`; live path writes `combinedText` (no figures, with transcript), bulk writes `combinedTextWithFigures`. After cutover, target chunks lack figure descriptions or mismatch signatures. Store one canonical indexable text.
- **Rollout robustness.** `notebook_rollout_index.dart` `indexPending` has no per-page try/catch or cancel check; one throwing page aborts every pass. `_pageTitle` loads the notebook and all its pages per page (O(pages²)). No heat/battery pause.
- **Chunk size counted in words, not tokens.** `page_chunker.dart` (250 words), `ai_router.dart` `tokensPerWord = 1.35`, `embedder_spec.dart` `maxInputTokens: 512`. English-only ratio; Bangla/Devanagari/CJK chunks truncate at 512 tokens so the tail is never retrievable. Same ratio sets 4096-context prompt budgets. Budget by script or use the real tokenizer.
- **Model-load race when `localAiProvider` rebuilds.** It watches `textEmbedderProvider` → `servingEmbedderSpecProvider` (async). A switch rebuilds `LocalGemmaProvider` with a new lock while the old one may still be generating; two lock domains can overlap a 2.6 GB load. Give the provider the embedder lazily (`ref.read` in a callback).
- **Model downloads unpinned and unverified.** `llm_model_spec.dart`, `embedder_spec.dart` use `huggingface.co/.../resolve/main/...` with no revision or sha256; no resume. Upstream re-upload under the same filename silently mixes vector spaces. Pin a commit hash, verify sha256, put the revision in `modelId`.
- **HuggingFace token in plain SharedPreferences** (`settings_provider.dart`). Backup is now off, but consider `flutter_secure_storage`.
- **Prompt injection.** `notes_qa.dart`, `summarization_service.dart`, quiz/flashcard/context prompts concatenate note/PDF text unfenced. `page_content_extractor.dart` trusts the PDF text layer, which can contain invisible text. Delimit untrusted text with a nonce marker and tell the model it is data; drop zero-size/off-page glyphs.
- **Audio/transcript consent is undisclosed.** Transcripts flow into page text and so into context/summary/Ask prompts, which can reach the cloud under `auto` (now gated by `cloudPrivacy` only for images). Disclose in settings or gate.

### Medium-low
- **PDF import can yield blank pages and unbounded storage** (`import/pdf_service.dart` ~125-135). A render failure still adds an `ImportedContent` pointing at a file that was never written. Pages render at 2× MediaBox with no cap (poster page ≈ 96 MB); the whole PDF is read into memory for the hash; cached PNGs are never evicted.
- **Transcript finishing during a bulk run is not indexed** (`transcription_providers.dart` ~400): `notebookIndexProvider.run` returns null while another run is in flight and the result is dropped. Also re-does a vision read just to add the transcript; call `indexer.indexPage` with the new text instead.
- **Transcription gaps and orphan rows.** `lecture_transcriber.dart` skips failed windows; the notifier saves what succeeded as "done" with no coverage marker. `recording_notifier.dart` inserts the DB row before `begin`; a denied permission leaves an orphan row. A WAV left by a killed app may have no finalised header (unverified).
- **Anki `.apkg` fields are not HTML-escaped** (`anki_collection.dart` ~144) while CSV is. `x<5`/`List<int>` lose text; a PDF-derived `<img src=...>` would fetch remotely. Use `HtmlEscape` on front/back.
- **Retrieval scans the whole notebook per query** (`note_chunk_store.dart` ~290, `rag_retriever.dart` 206-234): `findAll()`, converts every `List<float>`, re-chunks and re-tokenises every page. Cache decoded vectors per notebook or move to an isolate.
- **GPU-unavailable flag never expires** (`gemma_adapter.dart` ~330) after any GPU load failure incl. transient OOM; no `AppLifecycleState` handling to release models when backgrounded; `transcribeTimeout` cannot cancel the native decode.

### Low
- Ask never returns "not found" when keyword hits exist: RRF-fused results skip `minScore` (`rag_retriever.dart` 184-191); `notes_qa.dart` 172-184 drops over-budget passages but the UI still shows all sources.
- `note_search.dart` ~66: match offsets can be wrong for characters whose lowercase changes length (e.g. "İ").
- `quiz_generator.dart` ~190: `looksLikeProgramming` uses substring hints ("class", "api", "rust") — "classification"/"trust" get coding questions.
- `study_scheduler.dart` ~70: `startDate.add(Duration(days: i))` drifts across DST.
- `EmbedderSpec.all` ships `embeddingGemma2` with `modelId` `'UNSET'`; `_DryRunRow`/`dryRunCopy` use a URL that doesn't exist upstream (debug only).
- Stale comment: `cloudLlmClientProvider` is a stub while the gateway is live. (The "Nothing starts a rollout yet" comment is fixed.)

## Gateway (server/ai-gateway)

- **No attested identity.** Device key is still client-chosen. The global cap only bounds damage. Add Firebase App Check / Play Integrity / DeviceCheck or a server-issued signed per-install token, plus per-IP throttling (`slowapi` or a Render/Cloudflare rule).
- **Rate-limit state is not durable on Render free** (ephemeral disk, wiped on spin-down/deploy; caps and the global kill switch reset). Needs a Render persistent disk or Postgres/Redis, with `RATE_LIMIT_DB_PATH` pointed at it (Dockerfile already creates `/data`).
- **Charges are recorded before the provider call and never refunded** on 502/503.
- **Tools are not allowlisted.** `tools`/`tool_calls` are forwarded unvalidated; roles `system`/`tool` allowed in history; accumulated tool-call `arguments` have no size cap. Validate names (calculator, wikipedia, web_search) and schema shape.
- **No overall stream timeout or concurrent-stream cap.** Per-call SDK timeout exists; add `asyncio.timeout` around the stream.
- **Request-body size limit** is only enforced per field; add a `Content-Length` middleware. Check image magic bytes, not just `mime_type`.
- **Dependencies unpinned** (`requirements.txt` uses `>=`). Pin with `pip-compile --generate-hashes` or `uv lock`; run `pip-audit` in CI; pin base image by digest.
- **Docker/ops:** no `HEALTHCHECK`; `/health` never touches SQLite (add `SELECT 1`); logs omit a hashed device key and error class; `approx_cost_usd` is always 0.0.
- **Provider clients are built per request** (`provider_selection.py`) → new connection pool each time. Cache per settings.
- **Exa search results** are returned verbatim to the model (prompt-injection vector from the web); validate http/https URLs and delimit as untrusted data.
- ~~**Client:** cloud opt-in at the transport, hard-coded base URL, cert pinning.~~ **Done.** `CloudGatewayProvider` and `WebSearchTool` take `isCloudAllowed` (mode allows cloud and privacy is not `localOnly`); the base URL is `--dart-define=GATEWAY_URL`; `--dart-define=GATEWAY_CERT_SHA256=<hex>[,<hex>]` pins the leaf certificate (off by default; leaf certs rotate, so ship current and next digests together).

## Editor, data and build

- **Isar enums stored by ordinal** (`SceneElementRecord`: `FillStyle`, `Arrowhead`, `EdgeStyle`, …) — reordering remaps old rows. Use `@Enumerated(EnumType.name)` for new enums or add a test pinning enum order.
- **No recovery if `Isar.open` fails** in `main()`; no try/catch, app dies at splash. `runLaunchMigration` runs before first frame on the UI isolate (ANR risk on big libraries). Add an error page with export, and run migration behind a progress screen. `FlutterError.onError`/`PlatformDispatcher.onError` only `debugPrint` in release (no crash reporting).
- **Migration extras:** back up `inkflow.isar` before migrating; record a per-page "migrated" marker rather than inferring from existing rows.
- **Export runs on the UI isolate** (`scene_exporter.dart`, `editor_app_bar_actions.dart`): lower the 16384 px cap (≈4096 on mobile), run PDF assembly via `Isolate.run`, show progress, delete the temp file after share. Export silently narrows to the selection if anything is selected.
- **Undo history is uncapped** (`history_controller.dart`); `push()` applies before recording, so a throwing `apply` leaves half-applied state. Cap at ~100–200 commands.
- **`AutosaveController`:** unawaited, unguarded `onSave()` in the Timer callback; `flush()` does nothing while a save is in flight.
- **`FileLibraryRepository.load()`** has no try/catch; corrupt JSON breaks the library. Fall back to empty and keep the broken file as `.bad`.
- **`IsarSceneElementStore.upsertForPage`** loads every row of the page just to map ids (O(N) per pen-up); add an index on `(pageId, elementId)`.
- **Android:** R8/minify off and no `proguard-rules.pro`; 16 KB page-size support unverified for `flutter_edge_ai*`, pdfium, sqlite3 (run `check_elf_alignment.sh` in CI); `targetSdk` follows Flutter; AGP 9 opt-outs (`android.newDsl=false`, `android.builtInKotlin=false`) are temporary; verify the microphone foreground service for recording while backgrounded on Android 14+.
- **iOS has no buildable project** (no Info.plist/xcodeproj/Podfile). Regenerate or remove `ios/` and say so in docs.
- **Two PDF engines** (`pdfx` + `pdfrx_engine`/`pdfium_flutter`) double native size; the exact-pinned `flutter_edge_ai*` packages are a renamed fork of discontinued `flutter_gemma` — watch maintainer/release cadence.
- **Dart SDK bound** in `pubspec.yaml` is still `>=3.0.0`; the lockfile needs ≥3.13. Raising it turned on newer lints (246 infos). Do it together with a lint cleanup.
- **Signing:** add a real release keystore and `android/key.properties`. Without one the release build still falls back to the debug key (with a warning). Consider failing release builds on CI when it is absent.
- **CI:** `version-bump.yml` pushes directly to `main` (breaks under branch protection) and hard-codes a personal identity. Consider `dart format --set-exit-if-changed` and `pip-audit` in `ci.yml`.
- **Repo:** the removed dump files and `logcat_dump.txt` are still in git history (~42 MB pack); `git filter-repo` if clone size matters. Also untracked-but-present root clutter: `README_v4.md`, `check.py`, `dump_code.py`, `AI_TUTOR_RAG_FIX_REPORT.md`, `PROJECT_CONTEXT_PROMPT.md`. `lib/dev/dev_secrets.dart` is still tracked on purpose (empty now).
- **Lints:** enable `unawaited_futures`, `strict-casts`, `avoid_print` (would have flagged the unawaited scene writes).

## Docs that disagree with code

- `docs/AI_PIPELINE_PLAN.md` "Where time goes today" / "Next" describe pre-implementation behaviour; prewarm, shared vision engine, resident embedder, keyword+RRF, title chunks, PDF text layer, ML-Kit-first ink, read cache and batch-by-model are done.
- `docs/ARCHITECTURE.md` still describes 1.0.2 (`/note/:id`, `/import/pdf`; real router has `/note2/:id`), "6 RepaintBoundary layers", Isar registering only `NotebookSchema`/`NotePageSchema` (now 17 schemas), and "get_it should be dropped" (already gone).
- Stale file headers: `isar_scene_element_store.dart` ("not yet wired"), `scene_element_record.dart` (conversion lives in `scene_element_record_mapper.dart`, not `legacy_adapters.dart`).
- `docs/TECH_MIGRATION_PLAN.md` "never run git commit/push" conflicts with the repo's commit-per-phase history.
- `docs/MIGRATION_TEST_PLAN.md` device checks are unchecked — no record the legacy→2.0 path was tested on a real device.
- `server/ai-gateway/README.md` and the rate-limit docs: the "gateway isn't deployed yet" caveats are stale; document the new global caps and `GLOBAL_*` env vars.

## Test gaps to close alongside the above

Partial vision failure during a live read; rollout per-page failure, interrupted cutover, and rollout-vs-live text; hidden PDF text; Bangla token budgets; `LocalGemmaProvider` rebuild during an in-flight generation; Anki `.apkg` escaping; gateway concurrency, auth and oversize body; `_mayUploadImages` gating (currently private and untested).
