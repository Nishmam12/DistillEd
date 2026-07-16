# AI Integration Progress Log

This is the durable memory for the loop-engineered AI integration (see
`ai_prompts/00_README_HOW_TO_USE.md`). Every loop reads this first and updates it
last. Keep it accurate; it is the only state that survives a context reset.

## Current Phase
Phase 0 — Foundation. **In progress.**

## Decisions Locked In
- **Local-first, no exceptions in Phase 0.** No network calls, no backend, no
  cloud provider. Everything runs on-device.
- **Isar remains the only on-device store.** No cloud sync/auth yet.
- **Platform: Android-first** (confirmed with user 2026-07-16). An `ios/`
  directory now exists in the repo, but AI runtime + handwriting recognition
  target Android for now; the provider abstraction stays iOS-friendly but iOS is
  not a blocker this phase.
- **On-device model runtime: NOT chosen yet.** This is the one hard "ask the
  user before deciding" gate (Loop 0.2). Options to weigh: MediaPipe LLM
  Inference via `flutter_gemma` vs. `llama.cpp` via FFI (`llama_cpp_dart`).
- **Cloud tier:** deferred to Phase 3 (minimal stateless FastAPI gateway). Not
  touched now.
- **App package/name:** pubspec `name: inkflow`, version `1.1.0+6`, branch
  `Inkdot-2.0`. Dart import prefix is `package:inkflow/`.

## Repo reality vs. the phase-0 prompt (drift notes)
- Phase-0 prompt assumes "Android only, no `ios/` directory" — stale; `ios/`
  now exists. Scope decision above resolves it (Android-first).
- Editor now uses a unified `SceneElement` sealed hierarchy
  (`lib/domain/model/scene_element.dart`): `FreehandElement`, `SceneShapeElement`,
  `TextElement`, `ImageElement`, `FrameElement`. The legacy `Stroke` /
  `ShapeElement` / `ImportedContent` models still exist and are bridged by
  `lib/data/migration/legacy_adapters.dart`. **The Loop 0.3 page-content
  extractor should read from `SceneElement`s (the current model), not the legacy
  `Stroke` list the prompt describes.** Recognized-ink text comes from
  `FreehandElement`; typed text from `TextElement.text`; PDF/image from
  `ImageElement`.
- No `lib/features/ai/` folder existed before this phase; created in Loop 0.1.

## Dependencies added (with justification)
(none yet — Loop 0.1 is pure Dart, no new pubspec entries)

## Completed Slices

### Loop 0.1 — AI provider abstraction ✅
Provider-agnostic contract every later phase plugs into. Pure Dart, no new
dependencies, no runtime decision. Files under `lib/features/ai/domain/`:
- `ai_provider.dart` — abstract `AiProvider`: `Stream<String> generate(...)`
  (streaming by default), `Future<List<double>> embed(String)`,
  `AiCapabilities get capabilities`. Re-exports the value types below.
- `ai_message.dart` — `AiRole { system, user, assistant }` + `AiMessage`
  (role/content, convenience factories, map round-trip for Phase 2 memory).
- `ai_generation_options.dart` — `AiGenerationOptions` (temperature, maxTokens,
  stopSequences, topP, topK, seed) + `precise` preset.
- `ai_capabilities.dart` — `AiCapabilities` (modelId, displayName,
  contextWindowTokens, supportsStreaming/Vision/Embeddings, isLocal,
  approxCostPerCallUsd) — the metadata the Phase 3 router dispatches on.
- `ai_exception.dart` — sealed `AiException` hierarchy
  (`AiModelNotReadyException`, `AiUnavailableException`,
  `AiGenerationException`, `AiUnsupportedOperationException`). Providers throw
  these (not raw `UnimplementedError`) so the router/UI get a consistent contract.

Tests under `test/features/ai/domain/` (mocktail-free; a small in-file fake
implements the interface to prove it's implementable and the streaming contract
holds).

**Design intent for Phase 3:** the router will hold a list of `AiProvider`s and
pick per request using `AiCapabilities`. Adding a provider = implement
`AiProvider`; no interface change required. New generation knobs go on
`AiGenerationOptions` (providers ignore what they don't support) — also
non-breaking.

## Deferred / Open Questions
- **On-device runtime choice** (Loop 0.2) — needs user decision + a real
  device tokens/sec + binary-size check before committing.
- **Embeddings** — `AiProvider.embed` is declared but the local runtime may not
  support embeddings; concrete provider will throw
  `AiUnsupportedOperationException` until Phase 2 RAG picks an embedding path.
- Tool-calling message payloads (Phase 3) — `AiMessage` stays role+content for
  now; a `tool` role / structured payload is an additive change later.

## Next Loop
Loop 0.2 — On-device Gemma runtime. **STOP before starting:** present
MediaPipe/`flutter_gemma` vs. `llama.cpp`/FFI tradeoffs (binary size, tokens/sec
on mid-range Android, setup, maintenance) and get the user's pick before adding
any dependency or model-download code.
