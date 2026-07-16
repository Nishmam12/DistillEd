# InkFlow AI Integration — Phase 0: Foundation

You are the Lead AI Systems Architect and implementer for **InkFlow**, an existing Flutter handwritten-note app. Read this entire prompt before writing any code.

## 1. Project identity (read this first)

InkFlow is **not** a plain-text notepad. It is a freehand ink-canvas notebook:

- Handwritten content is stored as `Stroke` objects (`lib/features/editor/domain/models/stroke.dart`), each a list of `StrokePoint { x, y, pressure, simulatePressure }`. Rendered with `perfect_freehand`.
- There is also **typed text**: `TextElement` (`lib/domain/model/scene_element.dart`) with a plain `String text` field, placed via text boxes (`text_box_overlay.dart`, `text_element_overlay.dart`).
- Pages can have **imported PDFs and images** as backgrounds (`ImportedContent`, `pdfx`, `image_picker`).
- Shapes (`ShapeElement`) are vector shapes recognized from strokes (rectangles, circles, lines, arrows) — mostly diagram content, not text-bearing, but can carry attached text labels.
- Storage: **Isar** (`lib/shared/isar/isar_service.dart`, `lib/data/persistence/`). Note metadata in `NotePage` (Isar `@collection`). Ink/scene data is persisted through `ink_file_storage.dart` / `scene_element_codec.dart`.
- State: **flutter_riverpod** (`Notifier`/`AsyncNotifier` pattern — see `page_notifier.dart`, `canvas_notifier.dart`, `home_notifier.dart`).
- DI: **get_it**.
- Routing: **go_router** (`lib/app/router.dart`).
- Architecture: feature-based, `lib/features/<feature>/{domain,data,presentation}`. There is also a legacy `lib/editor`, `lib/domain`, `lib/data/migration` structure being migrated into the newer `features/` layout (see `scene_migrator.dart`, `migration_gate.dart`) — **do not** touch migration code; treat it as a black box that produces `NotePage` + scene elements.
- Platform: **Android only** right now — there is no `ios/` directory. Don't add iOS tooling in this phase.
- Package name: `com.inkflow.inkflow`. App name in code: `InkFlowApp` (`lib/app/app.dart`).

## 2. What this phase is actually for

Nothing in the app currently reads or understands note content. The Context Engine, tutor, and every AI feature in later phases depend on one thing existing first: **a reliable way to turn a page's content (strokes + typed text + imported PDF text) into plain text**, plus **a way to run a local LLM against that text**. That's the whole scope of Phase 0. No tutoring, no summarization, no UI beyond a debug screen. If it isn't a building block for later phases, it doesn't belong in Phase 0.

## 3. Hard constraints

- **Local-first, no exceptions in this phase.** No network calls. No backend. Everything runs on-device.
- **Don't modify** `features/editor/presentation/canvas/**`, `features/editor/domain/undo_redo/**`, or anything in `data/migration/**`. Add read-only accessors if you need new data out of them.
- **New feature folder**: `lib/features/ai/` with the standard `domain/`, `data/`, `presentation/` split. All AI code lives here except where a thin adapter is genuinely needed inside `features/editor` to expose stroke/text data (keep those adapters minimal and clearly named, e.g. `page_content_extractor.dart`).
- **Every new pubspec dependency must be justified** in `AI_PROGRESS.md` before adding it — package name, why it's needed, why alternatives were rejected, license.
- **Ask before locking in the on-device model runtime.** This is the one truly consequential decision in this phase (see 4.3) — don't silently pick one and build everything on top of it without flagging the tradeoffs to the user first.

## 4. Loop plan

Work through these as separate loops. After each loop: run `flutter analyze`, run `flutter test`, update `AI_PROGRESS.md`, commit, then stop and report before starting the next loop unless the user has told you to run all loops autonomously.

### Loop 0.1 — AI provider abstraction

Design a provider-agnostic interface so every later phase (local Gemma, cloud Gemma, Gemini/Claude/GPT) plugs into the same contract. In `lib/features/ai/domain/`:

- `ai_provider.dart` — abstract class `AiProvider` with at minimum:
  - `Stream<String> generate({required String prompt, String? systemPrompt, List<AiMessage>? history, AiGenerationOptions? options})` — streaming by default, since the plan requires streaming responses everywhere.
  - `Future<List<double>> embed(String text)` — for Phase 2 RAG (stub/throw `UnimplementedError` in Phase 0 if the chosen local runtime doesn't support embeddings yet; note this in `AI_PROGRESS.md`).
  - `AiCapabilities get capabilities` (context window size, supports streaming, supports vision, is local, approximate cost per call).
- `ai_generation_options.dart` — temperature, max tokens, stop sequences.
- `ai_message.dart` — role (user/assistant/system) + content, for multi-turn context.
- This interface is what the Phase 3 Intelligent Router will dispatch across. Design it now so Phase 3 doesn't require breaking changes.

### Loop 0.2 — On-device Gemma runtime

Get **one** local model actually generating text on an Android device/emulator, end to end. Recommended path (validate current availability before committing — SDKs move fast):

- **MediaPipe LLM Inference API** (`flutter_gemma` package, or a direct platform channel to MediaPipe's Android LLM Inference API) is the most maintained path for running Gemma `.task`-format models on Android from Flutter as of early 2026. Confirm current package status/version before adding it.
- Alternative if MediaPipe integration is too rough: `llama.cpp` via a Flutter FFI wrapper (e.g. `llama_cpp_dart`), running a GGUF-quantized Gemma checkpoint.
- **Present both options with real tradeoffs (binary size, tokens/sec on a mid-range Android device, setup complexity, maintenance activity) to the user before picking one.** This is the "ask before irreversible decision" gate from section 3.
- Implement `LocalGemmaProvider implements AiProvider` in `lib/features/ai/data/providers/local_gemma_provider.dart`.
- Model files are large (E2B is ~2GB+ quantized). Do not commit model weights to git. Implement an on-first-run download-and-cache flow (`path_provider` for storage location) with a clear progress UI stub and a way to verify checksum. Store the model in app-private storage, not shared storage.
- Add a debug-only screen (`lib/features/ai/presentation/debug/ai_debug_screen.dart`, reachable via a hidden route or a button in the existing Settings/About screen) that lets you type a prompt and see streamed output. This is your Loop 0.2 acceptance test — it must work before moving on.

### Loop 0.3 — Handwriting-to-text pipeline

This is the piece the original plan doc doesn't address at all, and it's load-bearing for every later phase: the Context Engine cannot read ink strokes as text without this.

- Add `google_mlkit_digital_ink_recognition` (on-device, free, Android-supported, no network required — matches local-first constraint). Confirm current version and that the `en-US` (and any other needed) model download flow works offline-after-first-download.
- `lib/features/ai/domain/handwriting_recognizer.dart` — interface `Future<String> recognize(List<Stroke> strokes)`.
- `lib/features/ai/data/handwriting/mlkit_handwriting_recognizer.dart` — implementation. Convert `Stroke.points` (`x, y`) into ML Kit's `Ink`/`StrokePoint` format (note: ML Kit's `StrokePoint` and InkFlow's `StrokePoint` are different types with the same name — don't let that collide; alias the import).
- Ink recognition needs points *in drawing order with stroke boundaries* — InkFlow already has this per-stroke, so grouping is trivial; just verify recognition quality on a real page of cursive/print notes before calling this loop done.
- `lib/features/ai/domain/page_content_extractor.dart` — the unified entry point later phases will call: given a `NotePage`, produce a `PageContent` value object containing:
  - `recognizedInkText` (from handwriting recognizer, run on non-eraser strokes)
  - `typedText` (concatenated `TextElement.text` values, in reading order — top-to-bottom, left-to-right by position)
  - `importedPdfText` (extract text layer from any `ImportedContent` that references a PDF, via `pdfx`'s text extraction if available, or flag as "needs OCR" if the PDF is scanned/image-only — don't build OCR for scanned PDFs in this phase, just detect and flag)
  - `sourceBreakdown` (which parts of the page came from which source, with rough bounding boxes, so later UI can highlight "the AI is looking at this")
- Add unit tests with a handful of synthetic `Stroke` fixtures (straight lines forming known letter shapes aren't realistic — instead test the *pipeline plumbing* with mocked `HandwritingRecognizer`, and do one manual/documented real-device check for actual recognition quality, logged in `AI_PROGRESS.md`).

### Loop 0.4 — Wire it together, minimal proof

- On the debug screen from Loop 0.2, add a "Recognize current page" button that runs `page_content_extractor.dart` against whatever page is currently open in the editor and displays the resulting `PageContent`, then feeds `recognizedInkText + typedText` into `LocalGemmaProvider.generate` with a trivial prompt ("Summarize this in one sentence") and streams the result.
- This is the Phase 0 Definition of Done: real ink on a real page → recognized text → local LLM output, fully on-device, no network calls, in under ~10s on a mid-range device for a single page.

## 5. Definition of Done for Phase 0

- [ ] `AiProvider` interface exists and is implemented by `LocalGemmaProvider`.
- [ ] A local Gemma model runs on-device and streams tokens back through the debug screen.
- [ ] Handwriting recognition converts real ink strokes to text with acceptable quality (document the actual accuracy observed — don't just claim it works).
- [ ] `PageContentExtractor` merges ink text + typed text + PDF text (where available) into one `PageContent`.
- [ ] End-to-end proof (Loop 0.4) works on a real or emulated Android device.
- [ ] No network calls anywhere in this phase's code (verify by checking there's no `http`/`dio` usage introduced).
- [ ] `AI_PROGRESS.md` documents: which on-device runtime was chosen and why, actual model size/latency numbers observed, handwriting recognition accuracy observations, and anything deferred.
- [ ] `flutter analyze` is clean and new code has test coverage consistent with the existing `test/features/editor/...` style.

## 6. Stop conditions — ask the user before proceeding

- Before finalizing the on-device runtime choice (Loop 0.2).
- If model download size/UX tradeoffs seem like they'd hurt first-run experience (e.g., >1.5GB download) — surface this, don't just silently ship it.
- If handwriting recognition quality is poor enough that later phases would be built on bad data — say so explicitly rather than proceeding into Phase 1.

Once Definition of Done is met and checked off, stop and report a summary. Do not start Phase 1 work in this session — that's a separate prompt (`02_phase1_context_engine_core_features.md`).
