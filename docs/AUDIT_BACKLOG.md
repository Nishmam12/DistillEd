# Audit backlog

From the 2026-10-09 audit of the app and its AI pipeline. Nearly everything the
audit found has since been fixed; this file now records **what is still open** and,
below that, **what was done and where**, so nothing is re-audited by accident.

Nothing from the fix rounds after `cbf4c50` is committed yet: it is all in the
working tree.

## Still open

### Needs something I cannot do from the repo
- **Real device identity for the gateway.** The device key is still client-chosen.
  The global caps, the per-address throttle and the body/stream limits bound the
  damage; they are not attestation. Needs Firebase App Check / Play Integrity (an
  account and SDK) or a server-issued signed per-install token.
- **Durable rate-limit counters.** On Render's free plan the disk is wiped on every
  deploy and spin-down, resetting the daily caps and the global kill switch. Needs
  a paid plan with a disk at `/data` (`RATE_LIMIT_DB_PATH=/data/rate_limit.sqlite3`)
  or a database.
- **Real-device checks.** Nothing here has been run on a phone: the embedder
  rollout and its mobile-data dialog, the recording foreground service on Android
  14+, the new startup-failure screen, the export progress bar, and the legacy →
  2.0 migration walkthrough in `MIGRATION_TEST_PLAN.md` §4.
- **R8 / minify.** Off on purpose (see `android/app/build.gradle.kts`). Turning it
  on needs keep rules for flutter_edge_ai / LiteRT-LM / ML Kit and a release run.
- **A release keystore.** Without `android/key.properties` a release build is
  signed with the debug key. CI can now refuse that with `-PrequireReleaseSigning=true`.

### Your call
- **Git history** still carries the removed dump files and `logcat_dump.txt`
  (~42 MB pack). `git filter-repo` rewrites history; only if clone size matters.
- **Summarize's cloud route** (`cloudLlmClientProvider`) is still a stub that falls
  back to the on-device model. It is not wired to the gateway because Summarize
  checks only the cloud switch, not the per-call `cloudPrivacy` confirmation, so
  wiring it would send whole notebooks off the device without asking.
- **Whisper download** (`edge_ai_speech.dart`) is still on `main`, unpinned and
  unverified; Gemma and EmbeddingGemma are pinned and checksummed.
- **Embedder `modelId`.** Left unchanged when the URLs were pinned (changing it
  forces every user's index to be rebuilt). Change it together with the weights.
- **Two PDF engines** (`pdfx` + `pdfrx_engine`) double native size, and the
  exact-pinned `flutter_edge_ai*` packages are a renamed fork of the discontinued
  `flutter_gemma`. Watch maintainer and release cadence.
- **AGP 9 opt-outs** (`android.newDsl=false`, `android.builtInKotlin=false`) are
  temporary; `pdfx` applies the Kotlin plugin.

### Small known gaps
- Indic-script chunking uses estimated token ratios, not the model's tokenizer;
  CJK (no spaces) is not handled; pages indexed before the change keep old chunks.
- Ask returns keyword-only hits even when no passage clears the vector threshold
  (a keyword hit needs 60% of the query's terms, so it is real evidence; the
  grounded prompt still lets the model say "not found").
- Rollout indexing has no cancel check inside a pass (the UI only offers Cancel
  while no pass runs). The mobile-data retry polls every 2 minutes while the app is
  open instead of listening for connectivity.
- PDF page images in the cache are never evicted. White-on-white text in a PDF is
  not detected. `transcribeTimeout` cannot cancel the native decode. A WAV left by
  a killed app may have no finalised header (unverified).
- Web search results are bounded and fenced by the app, but the gateway does not
  fence them itself.
- `version-bump.yml` still pushes straight to `main`; it breaks under branch
  protection (documented in the file; use `--build-number=${{ github.run_number }}`
  instead if that is turned on).
- `dart format --set-exit-if-changed` is not in CI: the repo is not format-clean.

## Done

### AI pipeline
- Embedder rollout: launch trigger and resume (`EmbedderRolloutRunner.resume`),
  serving the target during a half-done switch (`answeringModelId`); the download
  waits for the HuggingFace token and, on a metered network, asks (dialog + Settings
  toggle, `embedder_mobile_data_choice.dart`).
- Rollout embeds what the live/bulk paths embed (`PageTextRecord.indexText`); a
  failing page no longer aborts a pass; it waits while hot or low on battery; titles
  are read once per notebook.
- Budget words are script-aware (`text_budget.dart`): chunking, truncation and
  prompt budgets no longer overrun for Bangla/Devanagari.
- `LocalGemmaProvider` takes `embedderOf` (a lookup), so a model switch no longer
  rebuilds it or its load lock.
- Models pinned to a repo commit and checked against SHA-256 after download
  (Gemma, EmbeddingGemma).
- HuggingFace token in the platform keystore (`flutter_secure_storage`), migrated
  from SharedPreferences.
- Prompt injection: untrusted text is fenced with per-prompt random markers
  (`untrusted_text.dart`) in every feature prompt and web-search results; PDF text
  with zero-size glyphs or off the page is dropped at import.
- Transcript consent is disclosed in Settings.
- PDF import fails on a page that did not render (no blank pages), caps render size
  at 4096 px, hashes the file as a stream.
- A transcript finishing during a bulk run is indexed afterwards (`runWhenFree`).
- Transcripts record skipped stretches; a denied microphone leaves no orphan row.
- Anki `.apkg` fields are HTML-escaped.
- Retrieval caches decoded chunks per notebook, validated by (count, highest id).
- The GPU-unavailable flag expires after 30 minutes; the model is released when the
  app is backgrounded.
- One image failing in the vision model no longer fails the whole page read.
- Ask shows only the sources the prompt held (`fitToBudget`).
- Match offsets survive lowercasing that changes length; quiz "programming" hints
  match whole words; study-plan days are calendar days across DST;
  `EmbedderSpec.registry` excludes unrunnable specs.

### Gateway
- Cloud opt-in enforced at the transport (`isCloudAllowed`); base URL is
  `--dart-define=GATEWAY_URL`; optional leaf-certificate pin
  `--dart-define=GATEWAY_CERT_SHA256` (off by default; leaf certs rotate).
- Server: tool allowlist and size caps, no client `system` turns, tool-call
  argument cap, concurrent-stream caps and a 120 s stream deadline, per-address
  throttle, body-size middleware, image magic-byte check, no charge for requests
  that fail before output (`refund`), `/health` touches the database, hashed device
  key and error class in logs, a rough `approx_cost_usd`, provider clients cached,
  Exa results validated and bounded.
- Hash-locked `requirements.lock`, base image pinned by digest, `HEALTHCHECK`,
  `pip-audit` in CI. Docs updated (`server/ai-gateway/README.md`, `.env.example`,
  `render.yaml`).

### Editor, data and build
- Startup: a failed database open shows a retry/"send my data" screen; a splash
  shows while opening; errors are written to an on-device `error_log.txt` (no
  remote crash reporting: that would be a new service and a privacy decision).
- Migration: per-page "migrated" marker (an erased page no longer gets its old ink
  back) and a database copy `inkflow_before_v2.isar` before the first migration.
- Export: capped at 4096 px (scaled, not cropped), PDF assembled off the UI
  isolate, page-by-page progress, temp file deleted after sharing, file names
  sanitised, and a notice when only the selection is exported.
- Undo history capped at 200 and a throwing command is rolled back, not recorded;
  `AutosaveController` serialises saves, reports errors and `flush()` waits;
  `FileLibraryRepository.load()` keeps a damaged file as `.bad`; scene upsert reads
  two columns instead of whole rows; enum order is pinned by a test.
- Android: a microphone foreground service keeps lecture recording alive in the
  background (`RecordingService.kt`); 16 KB alignment is checked by
  `tool/check_16kb_alignment.sh` (all 64-bit libraries pass) and in CI.
- Dart SDK bound raised to `>=3.13.0`; `unawaited_futures` and `strict-casts` are
  on and clean. README documents that the app is Android-only.

### Docs
- `ARCHITECTURE.md`, `AI_PIPELINE_PLAN.md`, `TECH_MIGRATION_PLAN.md`,
  `MIGRATION_TEST_PLAN.md`, the gateway README and the stale file headers now match
  the code (or say plainly that a section is historical / unrecorded).
