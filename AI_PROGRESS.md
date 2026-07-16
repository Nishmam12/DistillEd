# AI Integration Progress Log

Durable memory for the AI integration work. Every loop reads this first and
updates it last. The plan of record is `ai_prompts/INTEGRATION_ROADMAP.md`
(which supersedes the phase-0 prompt's build-from-scratch assumptions); the
product vision remains `ai_prompts/AI_Notebook_Master_Plan.md`.

## Current Phase
**Phase R — Reconciliation** (port Afnan's AI from `origin/main` onto the
`Inkdot-2.0` SceneElement editor). R1–R2 complete; next is R3.

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

## Deferred / Open Questions
- Phase U: wrap runtime as `LocalGemmaProvider implements AiProvider`
  (streaming via `getResponseAsync`), `PageContentExtractor`, general router;
  then repoint Summarize.
- Embeddings: Phase 2 via `flutter_gemma_embeddings`.
- Not ported (deliberately): Afnan's pixel-eraser fix `916e730` (legacy-editor
  files that don't exist on 2.0), his legacy `note_editor_screen.dart` wiring.

## Next Loop
**R3** — SceneElement input path. Then R4 (wiring), R5 (device proof + push).
