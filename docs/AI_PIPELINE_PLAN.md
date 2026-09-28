# DistillEd — Getting more out of ML Kit and LiteRT on an 8 GB phone

A prioritized list of changes to the on-device AI stack, grounded in the current codebase (pubspec `5.0.0+30`, 28 Sep 2026). Each item says what to change, where, why, and roughly what it costs.

- **Target:** 8 GB Android
- **Reference device:** Xiaomi Pad 7 (Snapdragon 7+ Gen 3)
- **Main LLM:** Gemma 4 E2B (kept)
- **Embedder:** EmbeddingGemma 300M (kept)

> **Principle:** Load the 2.6 GB model only when it pays for itself. Everything cheaper (PDF text, ML Kit, caches) goes first, and the heavy model refines instead of starting from scratch.

Effort sizes are rough estimates: **S** ≈ a day, **M** ≈ a few days, **L** ≈ a week or more.

---

## Where time goes today

Found by reading the AI code paths. The numbers in the first two items come from the codebase's own comments, measured on the Pad 7.

| Finding | Detail | Where |
|---|---|---|
| Every Gemma load costs 3.6–17.2 s | The 30-second idle residency helped, but the first call after opening the sidebar still pays the full load while the user waits. | `local_gemma_provider.dart` |
| A deep page read made ~19 vision passes at ~2,300 patches each | The merged OCR+figure call cut some of this, but ink, every image and the drawn layer each still get their own vision call, at full resolution. | `page_content_extractor.dart` |
| Imported PDFs are always rasterized and OCR'd | Most lecture slides and papers already contain real text. The app throws it away, then spends a model call trying to read it back. | `features/import/pdf_service.dart` |
| Vision results are only cached for the session | `_visionReadDone` and `PageContextCache` reset on restart, so reopening a notebook repeats the heavy reads for pages that haven't changed. | `context_engine_notifier.dart` |
| The embedder loads and unloads on every call, including every question | Each "Ask your notes" query pays a model load before it can search. | `local_text_embedder.dart` |
| Available speed features are switched off | `enableSpeculativeDecoding` (multi-token prediction) and `activeBackend` have been in `flutter_gemma` since 0.15 and 0.16.2, and neither is used. The app can't tell when the GPU quietly falls back to CPU. | `gemma_adapter.dart` |
| Model downloads can't resume | The plugin turns resume off for Hugging Face URLs (weak ETags), so an interrupted 2.6 GB download starts over. EmbeddingGemma also needs a personal HF token, which is a lot of onboarding friction. | `gemma_adapter.dart`, `model_download_manager.dart` |
| Bangla images can't be OCR'd by ML Kit | Text Recognition v2 covers only Latin, Chinese, Devanagari, Japanese and Korean. Digital Ink does have `bn` and `bn-Latn` models. | `image_text_recognition_service.dart` |

---

## Target pipeline

**Today: deep read of a page**

1. Load Gemma (3.6–17 s cold)
2. Gemma vision reads all the ink as one image
3. Gemma vision reads each image or PDF page, then does a figure pass
4. Figure pass on the drawn layer
5. ML Kit only if Gemma's read fails the gate
6. Context engine call, then embed (embedder loaded and unloaded again)
7. Repeated in the next session

**Proposed: cheapest source first**

1. PDF text layer: instant and exact
2. ML Kit Digital Ink per line: milliseconds, shown right away
3. Persistent cache by content hash: skip anything already read
4. Gemma vision only for lines that fail the gate, maths or diagrams, at a sized token budget
5. Batch by model: all vision work, then all embedding
6. Prewarmed model, MTP decoding, resident embedder

---

## Now — quick wins, no new models (days)

Low risk. Most are a few lines behind existing seams.

### 1. Turn on multi-token prediction when running on GPU

Pass `enableSpeculativeDecoding: true` to `getActiveModel()`, but only when `activeBackend` reports GPU. Google reports about 1.6× faster decoding for Gemma 4 E2B. Articles on this advise against it on CPU, where running the drafter adds overhead. Answer quality stays the same; only speed changes.

Check first that the `.litertlm` file you download includes the MTP drafter. If it doesn't, this is a no-op until you switch to a file that does. The drafter also costs memory (LiteRT-LM maintainers suggest skipping its signature when you aren't using it), so measure peak memory with it on and off before keeping it.

- **Where:** `gemma_adapter.dart` → `FlutterGemmaRuntime.open`
- **Impact:** faster streamed answers
- **Effort:** S

### 2. Detect which backend actually loaded

After loading, read `InferenceModel.activeBackend`. Log it, and store it so the router and UI can react. On CPU fallback, shorten output budgets, skip the optional figure passes, and offer the cloud route if the user opted in, rather than silently being several times slower.

- **Where:** `gemma_adapter.dart`, `ai_router.dart`, settings screen
- **Impact:** predictable speed on every device
- **Effort:** S

### 3. Prewarm Gemma when the user shows intent

Start loading the model in the background when the AI sidebar opens, or when the Ask box gets focus. The mutex and idle-unload timer already exist, so this is a single `warmUp()` call that loads and arms the timer. It hides most of the 3.6–17 s cold start behind the user's own reading and typing time.

Make repeat loads cheaper too. LiteRT-LM writes a load cache to a `cacheDir` ("can improve 2nd load time"), including an XNNPACK weight cache of hundreds of MB that's keyed to the model file's modification time and size. Check that `flutter_gemma` points it at a persistent app directory. Never touch the model file after download, since changing it forces a rebuild. Add the cache to the free-space check, which today only counts the download.

- **Where:** `local_gemma_provider.dart`, `ai_sidebar.dart`, `ai_ask_view.dart`, `model_download_manager.dart`
- **Impact:** the largest perceived-latency win
- **Effort:** S

### 4. Keep the embedder loaded during a burst of work

Give `LocalTextEmbedder` the same idle-unload pattern as the LLM (for example 60 s). At about 200 MB it's cheap to hold, and it removes a model load from every question and from each page in a bulk index. Also measure CPU against GPU for the embedder: loading GPU kernels can cost more than a 300M model saves.

- **Where:** `local_text_embedder.dart`, `embedder_adapter.dart`
- **Impact:** faster Ask and bulk indexing
- **Effort:** S

### 5. Add keyword search alongside the vector search

You already store plain page text in `PageTextRecord` for search. Combine its keyword matches with the vector hits using reciprocal rank fusion. This catches exact terms, formula names and course codes that embeddings blur, keeps working before EmbeddingGemma is downloaded, and holds up better when handwriting misreads a word.

- **Where:** `rag_retriever.dart`, `note_search.dart`, `notes_qa.dart`
- **Impact:** better retrieval, no model cost
- **Effort:** S–M

### 6. Give chunks a title before embedding

EmbeddingGemma's document prompt is `title: {title} | text: …`, and the app always sends `none`. Put the notebook or imported PDF name at the start of each chunk's text (or in the title slot, if the plugin lets you set it). Changing `modelId` already triggers a clean re-index.

- **Where:** `page_chunker.dart`, `embedder_spec.dart` (bump `modelId`)
- **Impact:** better ranking across notebooks
- **Effort:** S

### 7. Tighten output budgets for structured calls

The context engine and figure analyzer return JSON. Set `maxOutputTokens` per call to what the schema needs (usually a few hundred), not a generic ceiling. Decoding is the slow part on a phone, and a runaway reply holds the model lock for everything queued behind it.

- **Where:** `context_engine.dart`, `figure_analyzer.dart`, quiz and flashcard generators
- **Impact:** shorter worst cases
- **Effort:** S

---

## Next — restructure the pipeline (1–3 weeks)

These change the order of work in the pipeline. Ship each behind a flag and compare with the measurements below.

### 8. Read the PDF's own text before any OCR

Use PDFium text extraction (`pdfrx_engine`: `PdfPage.loadStructuredText()` returns text with character boxes) at import time. Save it as page text with positions, and keep the rendered image for display. Only pages with little or no extractable text (scans) go to OCR. This also handles Bangla PDFs that have a text layer, which ML Kit can't read.

Your architecture rules need a STOP-and-ASK before adding a dependency. Consider moving rendering from `pdfx` to `pdfrx` as well, so you don't ship two copies of PDFium.

- **Where:** `pdf_service.dart`, `scene_import_service.dart`, `page_content_extractor.dart` (new source kind)
- **Impact:** instant, exact text for most imports
- **Effort:** M

### 9. Flip the handwriting order: ML Kit first, Gemma to refine

Run ML Kit Digital Ink on the grouped lines first and show that text straight away. Send to Gemma vision only the lines that fail `MeaningfulnessGate`, regions with maths or diagrams, or a page where the user taps Re-read. Crop to those regions instead of rendering the whole page. Most handwritten pages would then never load the big model.

This reverses `_readInk`. The gate, line grouping and pre-context you already built make ML Kit a trustworthy first pass.

- **Where:** `page_content_extractor.dart` (`_readInk`), `ink_lines.dart`, `gemma_vision_ocr_service.dart`
- **Impact:** most page reads with no model load
- **Effort:** M

### 10. Persist every read by content hash

Add a `ReadCacheRecord` keyed by content hash plus recognizer and model id. Imported images already have a content hash; ink can hash its stroke signature. It stores OCR text and the figure JSON. Reopening a notebook, re-indexing, or switching pages then costs nothing for content already read. Re-read deliberately skips the cache.

- **Where:** new Isar collection, `page_content_extractor.dart`, `context_engine_notifier.dart`
- **Impact:** no repeated vision work across sessions
- **Effort:** M

### 11. Size each vision call's image to its task

Gemma 4 supports image budgets of 70, 140, 280, 560 or 1,120 tokens. Use a low budget to decide whether an image is a figure worth analysing, and a high one only for dense OCR. If `flutter_gemma` doesn't expose the budget, get the same effect by downscaling the image before sending it. Image prefill is the cost behind those 2,300-patch passes.

- **Where:** `figure_analyzer.dart`, `gemma_vision_ocr_service.dart`, ink render seam
- **Impact:** much shorter vision prefill
- **Effort:** S–M

### 12. One job queue for background AI work, batched by model

Route imports, bulk indexing and deep reads through a single prioritized queue: user-facing requests first, background work after. Group by model so a 40-page import runs every vision read, unloads Gemma, then runs every embedding, instead of alternating loads. Run long jobs as a foreground service with a progress notification, the same way the model download already does.

- **Where:** `bulk_indexer.dart`, `notebook_index_notifier.dart`, `rag_index_scheduler.dart`
- **Impact:** big imports finish, and the UI never waits behind them
- **Effort:** M–L

### 13. Respect heat, battery and device class

Read Android's thermal status and headroom (`PowerManager`) over a small platform channel, and pause background jobs when the device is hot or low on battery. At first launch, read total RAM and whether the GPU backend loads, and pick a profile: full local, local-lite (CPU, shorter outputs, no figure pass), or cloud-assisted. A reasonable starting rule: about 7 GB or more reported and GPU loads → full; 5–7 GB → lite with a smaller context; under 5 GB → cloud. An "8 GB" phone usually reports a little under 8 GB of total RAM, so don't set the full-profile bar at 8. Sustained inference on a tablet throttles, and a page read that takes 2 s cold can take much longer after ten minutes of indexing.

- **Where:** new platform channel, `ai_router.dart`, `settings_provider.dart`
- **Impact:** steady performance and fewer crashes on weaker phones
- **Effort:** M

---

## New capabilities (mostly small models)

What lifts the app beyond an AI sidebar.

### 14. Searchable lecture transcripts, synced to the ink

After a recording stops, transcribe it on-device with `flutter_gemma_speech`: Whisper for Bangla or mixed-language lectures, Moonshine for faster English. It takes 16 kHz mono PCM, which the `record` package can capture directly. Index the transcript segments into RAG with their timestamps. Since recordings already line up with the ink timeline, an answer can then cite "minute 23 of Tuesday's lecture" and jump there.

Run it as a queued background job after recording ends, never alongside a Gemma call. Needs the `flutter_gemma` upgrade (item 19).

- **Where:** `features/audio` (`recording_session.dart`, `lecture_recording.dart`), RAG chunk source kinds
- **Impact:** a headline feature
- **Effort:** M–L

### 15. ML Kit Document Scanner for photo import

Replace the raw camera photo with `google_mlkit_document_scanner`. It detects edges, corrects perspective, removes shadows and stains, and outputs JPEG or PDF. It's delivered through Google Play services, adds almost nothing to app size, and needs no camera permission. Clean input makes every later OCR step cheaper and more accurate. It's Android-only and in beta.

- **Where:** editor import flow (image picker path)
- **Impact:** better photo imports
- **Effort:** S

### 16. Dates in notes feed the Study Planner

Run ML Kit Entity Extraction over page text as it's indexed. When notes say "Quiz 2 on Oct 14" or "final next Thursday", offer it as an exam countdown in the Study Planner. It's small, on-device and runs in milliseconds, with no LLM involved.

- **Where:** `study_scheduler.dart`, `study_planner_notifier.dart`, indexing hook
- **Impact:** the planner fills itself in
- **Effort:** S–M

### 17. Draw-to-shape and scribble-to-erase with ML Kit ink models

Digital Ink ships non-text models. `zxx-Zsym-x-shapes` returns RECTANGLE, TRIANGLE, ARROW or ELLIPSE, and each language has an `-x-gesture` classifier (scribble, strike, caret, circle and more). Hold-to-snap shapes and scribble-to-delete fit your Excalidraw-style editor, and each model is a small download.

- **Where:** `editor/input`, `editor/tools`, `handwriting_recognition_service.dart`
- **Impact:** a faster editor that feels native
- **Effort:** M

### 18. Bangla, end to end

Use ML Kit Language ID on recognized text to pick the Digital Ink model (`en`, `bn` or `bn-Latn`) and the Whisper language. Send Bangla images to Gemma vision, since ML Kit Text Recognition can't read Bengali script. For scanned documents, test PaddleOCR-VL-1.6 (0.9B, 109 languages including Bengali, with tables and formulas) as the document reader. It has a LiteRT-LM build, but `flutter_gemma` doesn't list it yet, so start with a short spike.

- **Where:** `handwriting_recognition_service.dart`, `page_content_extractor.dart`, settings language
- **Impact:** works for your actual users
- **Effort:** M; PaddleOCR spike S

---

## Platform upgrades (prerequisites)

Do these first if you take on items 14 or 18. Each needs an on-device regression pass.

### 19. Upgrade `flutter_gemma` 1.3.0 → 1.10.x

This brings speech-to-text (`flutter_gemma_speech`), per-encoder backend choice, and `activationDataType`. In 1.10.0, float32 activations fix wrong digits on some GPUs, which matters for a maths tutor. Breaking change: since 1.9.0, `FlutterGemma.initialize` needs `embeddingTokenizers: [GemmaEmbeddingTokenizers()]`. Upgrade `flutter_gemma_litertlm` and `flutter_gemma_embeddings` in lockstep.

- **Where:** `pubspec.yaml`, `gemma_adapter.dart` (`GemmaBootstrap`), `embedder_adapter.dart`
- **Effort:** M

### 20. Remove the ML Kit pins

`google_mlkit_digital_ink_recognition` 0.16.0 fixed the method-channel name, the bug behind your 0.14.2 pin, and 0.16.1 moves to `google_mlkit_commons ^0.13.0`. Bump Text Recognition to the matching release at the same time. That also opens up every newer ML Kit plugin used above. Requires Dart ^3.12 and Flutter ≥ 3.44. Your pubspec notes about Phosphor icons suggest you're already on 3.44+.

- **Where:** `pubspec.yaml`; re-run the handwriting device checks
- **Effort:** S

### 21. Host the model files yourselves

Gemma 4 is Apache 2.0. EmbeddingGemma's Gemma Terms allow redistribution if you pass on the agreement and use restrictions and include a NOTICE file. Serving both from your own storage (for example a CDN bucket with strong ETags) removes the Hugging Face token step and lets the 2.6 GB download resume after an interruption.

- **Where:** `llm_model_spec.dart`, `embedder_spec.dart`, `hf_token_check.dart` (can be retired)
- **Impact:** the biggest onboarding fix
- **Effort:** S

### 22. Raise the context window only after measuring

Gemma 4 E2B supports up to 32K tokens and you load 4,096. Going to 6K or 8K lets the router summarize more on-device before truncating, but the memory for past tokens grows with it. Measure peak memory on the Pad 7 at each size, and keep the largest that stays within budget with the embedder also loaded.

- **Where:** `llm_model_spec.dart` (`maxTokens`)
- **Effort:** S plus measurement

---

## Memory budget on 8 GB

Android and the app itself typically use 3–4 GB, leaving about 2–3 GB for models. The rule that holds it together: one large model at a time, with small models allowed alongside.

| Model | Role | Runtime memory | Can run alongside |
|---|---|---|---|
| Gemma 4 E2B | LLM, vision, audio | 0.7–2.6 GB GPU† · ~1.7 GB CPU\* | Embedder, ML Kit |
| PaddleOCR-VL-1.6 | Scanned documents (spike) | ~1.8 GB peak\* | Embedder, ML Kit. Never with Gemma. |
| Whisper / Moonshine | Lecture audio | measure | Queued, never with Gemma |
| EmbeddingGemma 300M | RAG vectors | ~0.2 GB | Anything |
| ML Kit Digital Ink | Handwriting, shapes, gestures | ~20 MB per language | Anything |
| ML Kit Text Rec. · Entity · Language ID · Doc Scanner | Utility | small | Anything |

\* Figures published for a Galaxy S26 Ultra (Gemma) and a Galaxy S26 GPU (PaddleOCR-VL). Measure on the Pad 7 before relying on them.

† Google's benchmark reports 676 MB. A LiteRT-LM bug report (issue #3507) measured 2.6 GB resident for Gemma 4 E2B on an Android GPU (8K context), because Android copies weights into GPU memory where iOS memory-maps them. Plan for the high end until you've measured.

---

## How to measure

Every change above should move a number. Add a debug-only performance panel and a small fixed evaluation set, and record results before and after each change.

| Metric | How | Watch it for |
|---|---|---|
| Cold load time, active backend | Stopwatch around `getActiveModel`; log `activeBackend` | Items 1–3, 19 |
| Time to first token, decode tokens/s | Timestamps on the stream | Items 1, 7, 11, 22 |
| Peak memory | `VmRSS` from `/proc/self/status` during a load | Items 4, 18, 22 |
| Time to page text | Sidebar open → first text shown, and → refined text | Items 8–11 |
| Handwriting accuracy (CER) | 20 handwritten pages with typed ground truth | Items 9, 18, 20 |
| Retrieval hit@5, answer faithfulness | 30 questions with a known source page | Items 5, 6, 14 |
| Memory after 5 load/unload cycles | Peak memory after each idle unload and reload | Idle-unload design; a GPU engine leak is reported in another LiteRT-LM wrapper |
| Thermal status over 10 minutes | `PowerManager` thermal status during bulk indexing | Items 12, 13 |

**Suggested order:** 20 → 1–7 → 8–11 → 19 → 12–13 → 14–18 → 21–22. Items 20 and 21 are small but unblock later work, and 19 must come before 14.

---

## What we took from the earlier research summary

The team's Executive Summary on lightweight Android models targets about 3 GB of RAM and covers vision CNNs and 2023–24-era LLMs. Its deployment advice holds up. Most of its model picks don't fit DistillEd.

| From the summary | How it's used here |
|---|---|
| Cache GPU delegate binaries to avoid slow startups | Folded into item 3 as LiteRT-LM's `cacheDir` and weight cache |
| Tiered fallback by RAM and GPU (≥7 GB / 5–7 GB / <5 GB) | Adopted as the starting rule in item 13 |
| Cap sequence length to control memory for past tokens | Matches item 22: measure before raising `maxTokens` |
| Benchmark on real mid-range devices; report time to first token and tokens/s | Matches the measurement table |
| NNAPI is deprecated in Android 15 | Confirms staying on LiteRT's GPU path, with NPU only where tested |
| Use already-quantized community models instead of quantizing your own | Already the case: the `litert-community` builds are pre-quantized |

**Set aside:** MobileNet and EfficientNet-Lite (the app has no camera classification or detection task), DistilBERT and MobileBERT (EmbeddingGemma covers that role), and Gemma 2B, Falcon-1B, StableLM-3B and GPT-2 (superseded by Gemma 4 E2B). The summary's MediaPipe LLM Inference API is now in maintenance-only mode, and Google points to LiteRT-LM, which `flutter_gemma` already uses. Its Gemma licence note no longer applies to Gemma 4, which is Apache 2.0. Its citation markers (for example 【3†L242-L250】) don't point to retrievable sources, so check the figures against primary sources before reusing them in a report.

---

## Sources

- [flutter_gemma changelog](https://pub.dev/packages/flutter_gemma/changelog) (MTP flag, activeBackend, activationDataType, speech)
- [flutter_gemma README](https://pub.dev/packages/flutter_gemma)
- [InfoQ: LiteRT-LM Gemma 4 multi-token prediction](https://www.infoq.com/news/2026/06/google-litertlm-gemma4/)
- [LiteRT-LM on GitHub](https://github.com/google-ai-edge/LiteRT-LM)
- [Gemma vision token budgets](https://ai.google.dev/gemma/docs/capabilities/vision)
- [Gemma 4 E2B LiteRT benchmarks](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm)
- [EmbeddingGemma model card](https://huggingface.co/google/embeddinggemma-300m)
- [ML Kit Text Recognition v2](https://developers.google.com/ml-kit/vision/text-recognition/v2)
- [ML Kit Digital Ink models](https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models)
- [Digital Ink plugin changelog](https://pub.dev/packages/google_mlkit_digital_ink_recognition/changelog)
- [google_ml_kit plugin index](https://pub.dev/packages/google_ml_kit)
- [ML Kit Document Scanner plugin](https://pub.dev/packages/google_mlkit_document_scanner)
- [pdfrx_engine PdfPage API](https://pub.dev/documentation/pdfrx_engine/latest/pdfrx_engine/PdfPage-class.html)
- [PaddleOCR-VL-1.6 LiteRT](https://huggingface.co/litert-community/PaddleOCR-VL-1.6)
- [Gemma 4 under Apache 2.0](https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html)
- [Gemma Terms of Use](https://ai.google.dev/gemma/terms)
- [Android Thermal API](https://developer.android.com/games/optimize/adpf/thermal)
- [LiteRT-LM on Android (`cacheDir`)](https://developers.google.com/edge/litert-lm/android)
- [LiteRT-LM #3507: Android GPU weight memory](https://github.com/google-ai-edge/LiteRT-LM/issues/3507)
- [LiteRT-LM #3772: weight cache rebuilds](https://github.com/google-ai-edge/LiteRT-LM/issues/3772)
- [litert-lm-native #59: GPU engine memory not released](https://github.com/leehack/litert-lm-native/issues/59)
- [MediaPipe LLM Inference (maintenance-only notice)](https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference/android)
