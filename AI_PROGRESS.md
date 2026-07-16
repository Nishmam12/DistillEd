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

## Deferred / Open Questions
- **R3 (next):** the summarize feature still *reads legacy `Stroke` lists* —
  nothing on Inkdot-2.0 calls it yet. Need: `FreehandElement` → ML Kit Ink
  conversion, a notebook page collector via `SceneElementStore.loadForPage`,
  and `t` capture in the 2.0 input pipeline
  (`lib/editor/input/scene_pointer_listener.dart`). Also verify the 2.0
  persistence codec (`scene_element_codec.dart` / record mapper) round-trips
  `StrokePoint.t` — if it packs points positionally, `t` is silently dropped.
- **R4:** Summarize entry point in `lib/editor/ui/notebook_editor_screen.dart`
  + settings rows (cloud toggle default OFF, recognition language, model
  management) — Afnan's settings_screen/settings_provider changes were NOT
  ported yet (his settings file differs from 2.0's).
- **R5:** device proof (model download, recognition quality on real 2.0 ink,
  end-to-end latency) — log actual numbers here when run.
- Phase U: wrap runtime as `LocalGemmaProvider implements AiProvider`
  (streaming via `getResponseAsync`), `PageContentExtractor`, general router;
  then repoint Summarize.
- Embeddings: Phase 2 via `flutter_gemma_embeddings`.
- Not ported (deliberately): Afnan's pixel-eraser fix `916e730` (legacy-editor
  files that don't exist on 2.0), his legacy `note_editor_screen.dart` wiring.

## Next Loop
**R3** — SceneElement input path. Then R4 (wiring), R5 (device proof + push).
