// Riverpod wiring for the AI platform (this codebase uses Riverpod as its DI
// mechanism throughout). Features consume these providers; nothing in
// features/ai depends on a consumer feature.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/constants/storage_paths.dart';
import '../../../core/providers/search_providers.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../dev/dev_secrets.dart';
import '../../../editor/render/scene_exporter.dart';
import '../../../editor/render/scene_image_cache.dart';
import '../../../editor/state/page_notifier.dart' show pageRepositoryProvider;
import '../../../editor/state/scene_controller.dart';
import '../../home/presentation/home_notifier.dart' show noteRepositoryProvider;
import '../data/embeddings/embedder_download_manager.dart';
import '../data/device/device_health.dart';
import '../data/embeddings/local_text_embedder.dart';
import '../data/flashcards/flashcard_store.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/cloud_llm_client.dart';
import '../data/llm/gemma_adapter.dart' show EdgeAiRuntime, LlmRuntime;
import '../data/llm/hf_token_check.dart';
import '../data/llm/llm_model_spec.dart' show LlmModelSpec;
import '../data/llm/model_download_manager.dart';
import '../data/llm/model_storage_cleaner.dart';
import '../data/memory/learning_memory_repository.dart';
import '../data/ocr/gemma_vision_ocr_service.dart';
import '../data/ocr/image_text_recognition_service.dart';
import '../data/ocr/isar_read_cache.dart';
import '../data/providers/cloud_gateway_provider.dart';
import '../data/providers/local_gemma_provider.dart';
import '../data/rag/note_chunk_store.dart';
import '../../audio/data/transcript_store.dart' show lectureTextOf;
import '../../audio/presentation/audio_providers.dart';
import '../data/language/ml_kit_language_detector.dart';
import '../data/study_planner/ml_kit_date_finder.dart';
import '../data/study_planner/study_plan_store.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_scope.dart';
import '../domain/compute_backend.dart';
import '../domain/context_engine/context_engine.dart';
import '../domain/context_engine/page_context.dart';
import '../domain/device_state.dart';
import '../domain/features/explainer.dart';
import '../domain/features/flashcard_generator.dart';
import '../domain/features/quiz_generator.dart';
import '../domain/features/notes_qa.dart';
import '../domain/features/researcher.dart';
import '../domain/features/writing_assistant.dart';
import '../domain/figure_analyzer.dart';
import '../domain/image_transcriber.dart';
import '../domain/knowledge_graph/knowledge_graph.dart';
import '../domain/ai_router.dart' show Reachability;
import '../domain/page_content_extractor.dart';
import '../domain/quality/ai_quality_guard.dart';
import '../domain/rag/bulk_indexer.dart';
import '../domain/rag/page_chunker.dart' show chunkTitle;
import '../domain/rag/rag_indexer.dart';
import '../domain/rag/rag_retriever.dart';
import '../domain/rag/text_embedder.dart';
import '../domain/read_cache.dart';
import '../domain/routing/cloud_first_transcriber.dart';
import '../domain/routing/intelligent_router.dart';
import '../domain/language/language_detector.dart';
import '../domain/study_planner/note_deadlines.dart';
import '../domain/study_planner/study_plan.dart';
import '../domain/tools/calculator_tool.dart';
import '../domain/tools/tool.dart';
import '../domain/tools/web_search_tool.dart';
import '../domain/tools/wikipedia_tool.dart';
import 'ask_notes_notifier.dart';
import 'study_planner_notifier.dart';
import 'context_engine_notifier.dart';
import 'explain_notifier.dart';
import 'flashcard_notifier.dart';
import 'model_download_notifier.dart';
import 'notebook_index_notifier.dart';
import 'quiz_notifier.dart';
import 'rag_index_scheduler.dart';
import 'research_notifier.dart';
import 'writing_assistant_notifier.dart';

final handwritingRecognitionServiceProvider =
    Provider<HandwritingRecognitionService>((ref) {
  final service = HandwritingRecognitionService();
  ref.onDispose(service.dispose);
  return service;
});

/// Manages the on-device LLM download. The token is optional here (this model's
/// repo is ungated) but is passed when present — see [ModelDownloadManager]'s
/// `_authToken` for why an anonymous 2.4 GB download is the fragile one.
final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  final manager = ModelDownloadManager(
    authToken: () => ref.read(huggingFaceTokenProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// The LLM download's state, for any surface that needs to show or start it.
///
/// App-lifetime (NOT autoDispose), and more strictly so than the per-feature
/// notifiers below: closing the AI sidebar, leaving the note for the home
/// screen, or backgrounding the app must never abort the 2.4 GB download OR
/// lose sight of it. Reopening the sidebar reads this same instance and lands
/// straight back on live progress.
final llmDownloadProvider =
    StateNotifierProvider<LlmDownloadNotifier, LlmDownloadState>((ref) =>
        LlmDownloadNotifier(ref.watch(modelDownloadManagerProvider)));

/// Finds and reclaims model files left on disk that no installed model claims
/// — see [ModelStorageCleaner] for how these arise and why the delete is
/// guarded.
final modelStorageCleanerProvider =
    Provider<ModelStorageCleaner>((ref) => EdgeAiStorageCleaner());

/// The inference runtime behind [localAiProvider]. A provider only so the
/// wiring around it can be tested with a fake — nothing else needs to swap it.
final llmRuntimeProvider = Provider<LlmRuntime>((ref) => EdgeAiRuntime());

/// Where the on-device model last loaded actually ran — null until it has
/// loaded once.
///
/// [LocalGemmaProvider] publishes it after each load, because the plugin asks
/// for the GPU and falls back to the CPU without saying so. Routing, the
/// optional figure passes and Settings read it from here rather than assuming
/// the fast case.
final localBackendProvider = StateProvider<ComputeBackend?>((ref) => null);

/// Reads the device's RAM, thermal state and battery.
final deviceHealthProvider = Provider<DeviceHealth>((ref) => DeviceHealth());

/// How much of the on-device pipeline this device is given.
///
/// Resolved once at startup (see `main.dart`), from the device's total RAM, and
/// overridden there; the default here is [AiProfile.full], which is also what
/// every test gets. Read, not watched, by [localAiProvider]: changing it would
/// rebuild the provider and drop the resident model.
final deviceProfileProvider = Provider<AiProfile>((ref) => AiProfile.full);

/// Whether the on-device model cannot be relied on to be fast — it fell back to
/// the CPU, or the device is too short of RAM to lean on it — which is what
/// makes routing prefer the cloud for a user who has opted in. Read per
/// decision: the backend is only learned when the model first loads.
final localDegradedProvider = Provider<bool Function()>((ref) => () =>
    (ref.read(localBackendProvider)?.isSlow ?? false) ||
    ref.read(deviceProfileProvider) == AiProfile.cloudAssisted);

/// The on-device model behind the platform-wide [AiProvider] contract —
/// streaming, typed failures, load→generate→unload memory invariant.
final localAiProvider = Provider<AiProvider>((ref) => LocalGemmaProvider(
      // A device short on RAM loads a smaller context window.
      spec: LlmModelSpec.active.forProfile(ref.read(deviceProfileProvider)),
      runtime: ref.watch(llmRuntimeProvider),
      embedder: ref.watch(textEmbedderProvider),
      onBackendChanged: (backend) =>
          ref.read(localBackendProvider.notifier).state = backend,
    ));

/// Starts loading the on-device model in the background, so the cold start
/// (3.6–17 s on the reference tablet) happens behind the user's own reading and
/// typing time instead of in front of the first answer.
///
/// Call it when the user shows intent: the AI panel opens, the Ask box gets
/// focus. Does nothing in cloud-first mode, where the local model is never used;
/// nothing on a device too short of RAM to hold the model warm on a guess; and
/// nothing when the local provider is not the real one (tests).
final localModelWarmerProvider = Provider<void Function()>((ref) => () {
      if (ref.read(settingsProvider).aiMode.prefersCloud) return;
      if (ref.read(deviceProfileProvider) == AiProfile.cloudAssisted) return;
      final local = ref.read(localAiProvider);
      if (local is LocalGemmaProvider) unawaited(local.warmUp());
    });

/// The on-device EMBEDDING model (EmbeddingGemma) — a different model from the
/// LLM above, with its own download and its own mutex.
///
/// Exposed separately rather than only through [AiProvider.embed] because
/// embeddings are model-locked and must never be routed: see the header of
/// `domain/rag/text_embedder.dart`.
final textEmbedderProvider =
    Provider<TextEmbedder>((ref) => LocalTextEmbedder());

/// The effective HuggingFace token for gated downloads.
///
/// The user's Settings token is authoritative. In DEBUG builds only, a local
/// gitignored dev token ([kDevHuggingFaceToken]) fills in when Settings is
/// empty, so a developer needn't re-paste after every reinstall. Release builds
/// never consult it — the [kDebugMode] guard means it can't leak into a shipped
/// app even if a token-bearing `dev_secrets.dart` were somehow bundled.
final huggingFaceTokenProvider = Provider<String>((ref) {
  final fromSettings = ref.watch(settingsProvider).huggingFaceToken.trim();
  if (fromSettings.isNotEmpty) return fromSettings;
  if (kDebugMode) return kDevHuggingFaceToken.trim();
  return '';
});

/// Validates a HuggingFace token against `/api/whoami-v2`, independently of any
/// model repo.
///
/// Exposed as a provider (rather than staying private to the download manager)
/// so Settings can check a token the moment it is pasted. Catching a bad paste
/// there, instead of 185 MB into a download, is most of what makes the gated
/// setup bearable.
final huggingFaceIdentityProvider =
    Provider<HuggingFaceIdentity>((ref) => DioHuggingFaceIdentity());

/// Manages the gated, user-triggered download of the embedding model, reading
/// the effective token at download time (see the manager's [authToken] doc for
/// why it's read late, not captured here).
final embedderDownloadManagerProvider =
    Provider<EmbedderDownloadManager>((ref) {
  final manager = EmbedderDownloadManager(
    authToken: () => ref.read(huggingFaceTokenProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// Durable store of embedded note chunks (Isar).
final noteChunkStoreProvider =
    Provider<NoteChunkStore>((ref) => IsarNoteChunkStore());

/// Keeps a page's chunks in step with its text.
final ragIndexerProvider = Provider<RagIndexer>((ref) {
  final store = ref.watch(noteChunkStoreProvider);
  return RagIndexer(
    embedder: ref.watch(textEmbedderProvider),
    saveChunks: store.replaceForPage,
    deleteChunks: store.deleteForPage,
    indexStateOf: store.indexStateForPage,
    // Which notebook (and, for an import, which document) a chunk belongs to
    // is embedded with it, so two notebooks that both mention "enthalpy" rank
    // apart. See [chunkTitle].
    titleOf: (notebookId, pageId) async {
      final notebook =
          await ref.read(noteRepositoryProvider).getNotebook(notebookId);
      final pages =
          await ref.read(pageRepositoryProvider).getPagesForNotebook(notebookId);
      String? source;
      for (final page in pages) {
        if (page.id == pageId) source = page.importSourceName;
      }
      return chunkTitle(notebookTitle: notebook?.title, sourceName: source);
    },
  );
});

/// Debounces indexing off the Context Engine's extraction (see the file header
/// for why it does not simply reuse the 2.5s analysis debounce).
final ragIndexSchedulerProvider = Provider<RagIndexScheduler>((ref) {
  final scheduler = RagIndexScheduler(indexer: ref.watch(ragIndexerProvider));
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Indexes pages nobody has opened — the eager path after a PDF import and the
/// explicit "Index all pages" action. See `domain/rag/bulk_indexer.dart` for
/// why the live scheduler above cannot cover those.
///
/// Reads pages with vision ON: an imported PDF page is a picture, and the light
/// ML Kit path turns a slide into a handful of stray labels. This is a
/// user-initiated, one-off batch, so it can afford the deep read that the
/// passive per-keystroke loop deliberately cannot.
final bulkRagIndexerProvider = Provider<BulkRagIndexer>((ref) {
  final extractor = ref.watch(pageContentExtractorProvider);
  return BulkRagIndexer(
    indexer: ref.watch(ragIndexerProvider),
    readPage: (pageId) async {
      final content = await extractor.extractPage(
        pageId,
        languageCode: ref.read(settingsProvider).recognitionLanguage,
        useVision: true,
      );
      // Figures are indexed alongside the words, exactly as the live path does
      // — "what did the graph on slide 12 show" must be able to retrieve.
      return content.combinedTextWithFigures;
    },
    // The reads are the expensive part and a missing embedder would throw every
    // one of them away, so find out before the first.
    embedderReady: ref.read(embedderDownloadManagerProvider).isInstalled,
    // Every read first, THEN every embedding: give the vision model's ~2.6 GB
    // back the moment the last read is done, before the embedder works.
    releaseVisionModel: () async {
      final local = ref.read(localAiProvider);
      if (local is LocalGemmaProvider) await local.releaseModel();
    },
    // Sustained inference throttles a tablet and drains a phone: wait while the
    // device is hot or low on power, and carry on when it is not.
    pauseReason: () async =>
        backgroundPauseReason(await ref.read(deviceHealthProvider).read()),
    // A page is findable by keyword as soon as it has been read — which also
    // makes keyword search work for an import before the embedding model has
    // ever been downloaded. (The live path writes the same store; see
    // `pageContextProvider`.) Figures are included: for an imported deck they
    // are part of what the document says.
    onPageRead: (notebookId, pageId, text) =>
        ref.read(pageTextStoreProvider).save(
              notebookId: notebookId,
              pageId: pageId,
              text: text,
            ),
  );
});

/// Drives a bulk indexing run for one notebook. Family-scoped so two open
/// notebooks keep separate progress; session-scoped (not autoDispose) so a run
/// survives the sheet that started it being closed.
final notebookIndexProvider = StateNotifierProvider.family<
    NotebookIndexNotifier, NotebookIndexState, int>((ref, notebookId) {
  return NotebookIndexNotifier(indexer: ref.watch(bulkRagIndexerProvider));
});

/// Resolves "this page / this PDF / the whole notebook" to concrete page ids.
/// The single definition every AI feature scopes by — see `domain/ai_scope.dart`.
final aiScopeResolverProvider = Provider<AiScopeResolver>((ref) {
  final pages = ref.watch(pageRepositoryProvider);
  return AiScopeResolver(
    pagesOf: (notebookId) async => [
      for (final p in await pages.getPagesForNotebook(notebookId))
        ScopePage(
          pageId: p.id,
          importGroupId: p.importGroupId,
          importSourceName: p.importSourceName,
        ),
    ],
  );
});

/// Semantic search over a notebook, feeding "Ask your notes".
final ragRetrieverProvider = Provider<RagRetriever>((ref) => RagRetriever(
      embedder: ref.watch(textEmbedderProvider),
      loadChunks: ref.watch(noteChunkStoreProvider).forNotebook,
      // Keyword search runs over the plain page text, which exists whether or
      // not the embedding model has ever been downloaded — so a question about a
      // course code or a defined term finds its page either way.
      loadPageTexts: (notebookId) async => [
        for (final page
            in await ref.read(pageTextStoreProvider).forNotebook(notebookId))
          (pageId: page.pageId, text: page.text),
      ],
    ));

/// The accuracy fail-safe shared by Explain, Ask, Summarize and the Context
/// Engine: generate locally, check the output, escalate to the cloud when the
/// user's privacy setting allows it and flag low confidence when it doesn't.
///
/// Every input it needs is read at CALL time through a callback, never captured:
/// a student who toggles cloud AI (from Settings, the sidebar switch, or
/// `/cloud on` in the Ask box) must see the change take effect on their next
/// question, not after a restart.
final aiQualityGuardProvider = Provider<AiQualityGuard>((ref) {
  return AiQualityGuard(
    local: ref.watch(localAiProvider),
    cloud: ref.watch(cloudGatewayMidProvider),
    cloudEnabled: () => ref.read(settingsProvider).cloudAiEnabled,
    privacy: () => ref.read(settingsProvider).cloudPrivacy,
    isOnline: () => const Reachability().isOnline(),
  );
});

/// "Ask your notes": grounded QA over a notebook (retrieve → answer from those
/// passages only).
final notesQaProvider = Provider<NotesQa>((ref) => NotesQa(
      provider: ref.watch(localAiProvider),
      retriever: ref.watch(ragRetrieverProvider),
    ));

/// Drives the sidebar's Ask surface. Session-scoped (not autoDispose) for the
/// same reason as Explain/Quiz: closing the sidebar must not abort an in-flight
/// model download, and the answer stays put until dismissed.
final askNotesNotifierProvider =
    StateNotifierProvider<AskNotesNotifier, AskNotesState>((ref) {
  return AskNotesNotifier(
    qa: ref.watch(notesQaProvider),
    llmDownloads: ref.watch(modelDownloadManagerProvider),
    embedderDownloads: ref.watch(embedderDownloadManagerProvider),
    guard: ref.watch(aiQualityGuardProvider),
    // The `/cloud on|off` command and the sidebar switch write the same stored
    // setting, so neither can drift from the other.
    cloudEnabled: () => ref.read(settingsProvider).cloudAiEnabled,
    setCloudEnabled: (enabled) =>
        ref.read(settingsProvider.notifier).setCloudAiEnabled(enabled),
    privacyAsksEachTime: () =>
        ref.read(settingsProvider).cloudPrivacy == CloudPrivacy.askEachTime,
  );
});

/// Cloud tier seam — a no-op stub until Phase 3 stands up the gateway.
final cloudLlmClientProvider =
    Provider<CloudLlmClient>((ref) => StubCloudLlmClient());

/// On-device OCR for imported pictures — PDF pages, whiteboard photos.
///
/// App-wide, because it caches what it has already read: an imported file never
/// changes, so re-OCRing it on every debounced page analysis would be pure
/// waste. Distinct from the handwriting recogniser above, which reads strokes.
final imageTextRecognitionServiceProvider =
    Provider<ImageTextRecognitionService>((ref) {
  final service = ImageTextRecognitionService();
  ref.onDispose(service.dispose);
  return service;
});

/// The on-device Gemma model as an [ImageTranscriber] — the SAME instance as
/// [localAiProvider]. It must be the same instance, not a fresh one: vision
/// transcription and text generation share one mutex there so the 2.4 GB model
/// is never loaded twice at once. The cast is safe — the local provider is the
/// only implementation and it implements both contracts.
final imageTranscriberProvider = Provider<ImageTranscriber>(
    (ref) => ref.watch(localAiProvider) as ImageTranscriber);

/// The transcriber page reads actually use — on-device, or the cloud gateway
/// when the user picked [AiProcessingMode.cloudFirst].
///
/// Separate from [imageTranscriberProvider] (which must stay the raw local
/// instance for its mutex) so that only the READ path is routed. The mode is
/// read at call time, so switching it takes effect on the next read.
final routedImageTranscriberProvider = Provider<ImageTranscriber>((ref) {
  final cloud = ref.watch(cloudGatewayMidProvider);
  return CloudFirstTranscriber(
    local: ref.watch(imageTranscriberProvider),
    cloud: cloud,
    preferCloud: () => ref.read(settingsProvider).aiMode.prefersCloud,
  );
});

/// Vision OCR — the PRIMARY recogniser for deep page reads (handwriting and
/// imported images). ML Kit (above) is its last-resort fallback.
final gemmaVisionOcrServiceProvider = Provider<GemmaVisionOcrService>((ref) =>
    GemmaVisionOcrService(
        transcriber: ref.watch(routedImageTranscriberProvider)));

/// Reads charts and diagrams as structured figures — on-device first, cloud
/// only when the on-device read misses the quality bar.
///
/// The escalation predicate is the privacy control for this feature: an image
/// leaves the device only when the user has turned cloud AI on AND the local
/// VLM already failed to read the figure. Read (not watched) at call time so
/// toggling the setting takes effect on the next read without rebuilding the
/// extractor.
final figureAnalyzerProvider = Provider<FigureAnalyzer>((ref) {
  final local = ref.watch(imageTranscriberProvider);
  final cloud = ref.watch(cloudGatewayMidProvider);
  return FigureAnalyzer(
    local: local,
    cloud: cloud,
    canEscalate: () async => ref.read(settingsProvider).cloudAiEnabled,
    preferCloud: () => ref.read(settingsProvider).aiMode.prefersCloud,
    localModelId: ref.watch(localAiProvider).capabilities.modelId,
    cloudModelId: cloud.capabilities.modelId,
  );
});

/// The longest side, in pixels, of an ink or drawn-layer picture handed to the
/// vision model.
///
/// The model downsizes whatever it is given to a fixed patch budget — a
/// full-resolution read was measured at ~2,300 patches, roughly an 800x800-pixel
/// equivalent (see PageContentExtractor) — so pixels far beyond that were
/// rendered, PNG-encoded, passed across and decoded for nothing. 2,048 leaves a
/// wide margin for small handwriting while cutting a full page from ~8
/// megapixels to ~4 at most. Inferred from that measurement, not from the
/// plugin, which exposes no image budget: confirm with a time-to-first-token run.
const int kVisionRenderMaxSide = 2048;

/// Durable memory of what the vision model has already read — an imported
/// page, a region of handwriting, a drawn figure — so reopening a notebook after
/// a restart, or re-indexing it, never pays for the same read twice.
final readCacheProvider = Provider<ReadCache>((ref) => IsarReadCache());

/// Tells real text from noise — ML Kit Language ID, on-device. One identifier
/// for the app, freed with the container.
final languageDetectorProvider = Provider<LanguageDetector>((ref) {
  final detector = MlKitLanguageDetector();
  ref.onDispose(detector.dispose);
  return detector;
});

/// The one way AI features read a page (editor-2.0 scene store underneath).
final pageContentExtractorProvider = Provider<PageContentExtractor>((ref) {
  final store = ref.watch(sceneElementStoreProvider);
  final ocr = ref.watch(imageTextRecognitionServiceProvider);
  final docsDir = ref.watch(appDocsPathProvider);
  return PageContentExtractor(
    loadElements: store.loadForPage,
    recognition: ref.watch(handwritingRecognitionServiceProvider),
    // Elements store paths relative to the documents dir; resolve them the same
    // way the renderer does, so the AI reads exactly the file on screen.
    readImageText: (relative) =>
        ocr.readText(SceneImageCache.resolvePath(docsDir, relative)),
    // Gemma vision, primary on deep reads. Ink is rasterised to a tight PNG the
    // same painter draws to screen; images are read from their file bytes.
    visionOcr: ref.watch(gemmaVisionOcrServiceProvider),
    renderInk: (elements) =>
        SceneExporter.toPng(elements, maxSide: kVisionRenderMaxSide),
    loadImageBytes: (relative) =>
        _readFileBytes(SceneImageCache.resolvePath(docsDir, relative)),
    // Charts and diagrams — drawn with the shape tools or pasted in — read as
    // structured figures instead of vanishing into a few OCR'd axis labels.
    figureAnalyzer: ref.watch(figureAnalyzerProvider),
    // The optional figure passes are the first thing dropped when the local
    // model has fallen back to the CPU (whose reads are also cut short, so are
    // not remembered), or the device is below the full profile (which only
    // drops the passes). Neither in cloud-first mode: there the cloud reads the
    // page and the local model's speed is beside the point.
    localIsSlow: () =>
        !ref.read(settingsProvider).aiMode.prefersCloud &&
        (ref.read(localBackendProvider)?.isSlow ?? false),
    lite: () =>
        !ref.read(settingsProvider).aiMode.prefersCloud &&
        ref.read(deviceProfileProvider) != AiProfile.full,
    readCache: ref.watch(readCacheProvider),
    // Which model answers a read right now: part of the cache key, so switching
    // between on-device and cloud-first reads afresh rather than serving one
    // model's reading as the other's.
    readModelId: () => ref.read(settingsProvider).aiMode.prefersCloud
        ? ref.read(cloudGatewayMidProvider).capabilities.modelId
        : ref.read(localAiProvider).capabilities.modelId,
    // ML Kit's Latin text recognition answers with noise on Bengali script; this
    // keeps that noise out of a page's text. See [isUnreadable].
    languageDetector: ref.watch(languageDetectorProvider),
    // The text PDFium read off each imported PDF page at import, kept beside the
    // page's image. A page that has some is read without OCR or a model.
    // What was SAID in the lectures recorded on a page, transcribed on the
    // device: read as part of the page, so every feature sees it.
    lectureTranscript: (pageId) async => lectureTextOf(
        await ref.read(lectureRecordingStoreProvider).forPage(pageId),
        ref.read(transcriptStoreProvider)),
    pdfTextLayer: (relative) async {
      final file = File(SceneImageCache.resolvePath(
          docsDir, StoragePaths.pdfTextSidecar(relative)));
      try {
        return await file.exists() ? await file.readAsString() : null;
      } catch (_) {
        return null;
      }
    },
  );
});

/// Reads a file's bytes for Gemma vision, or null when it can't be read — an
/// unreadable picture costs its own text, never the whole page's analysis.
Future<Uint8List?> _readFileBytes(String absolutePath) async {
  try {
    final file = File(absolutePath);
    return await file.exists() ? await file.readAsBytes() : null;
  } catch (_) {
    return null;
  }
}

/// Session-lifetime cache of the last PageContext per page; survives the
/// sidebar closing and page switches (durable persistence is Phase 2's
/// Learning Memory).
final pageContextCacheProvider =
    Provider<PageContextCache>((ref) => PageContextCache());

/// Page analysis. Runs on the cloud tier directly under
/// [AiProcessingMode.cloudFirst], on-device otherwise.
///
/// Watched (not read) so switching modes rebuilds the engine — the provider
/// also supplies the input word budget, and cloud's context window is far
/// larger than the local one, so the two cannot share a cached engine.
///
/// Unlike the vision path, a cloud failure here is NOT swallowed into a local
/// retry: it surfaces as an error the panel can show. Analysis that silently
/// degraded is what made a failed read indistinguishable from a blank page.
final contextEngineProvider = Provider<ContextEngine>((ref) {
  final preferCloud = ref.watch(settingsProvider).aiMode.prefersCloud;
  return ContextEngine(
    provider: preferCloud
        ? ref.watch(cloudGatewayMidProvider)
        : ref.watch(localAiProvider),
    // The accuracy fail-safe: an extraction the on-device model returned
    // empty or looping is re-run on the cloud tier when the user's privacy
    // setting allows it, instead of silently reading as "this page is blank".
    guard: ref.watch(aiQualityGuardProvider),
  );
});

/// The Phase 3 cloud gateway's base URL — the Render deployment
/// (`server/ai-gateway`, built from the repo-root `render.yaml`). Free plan,
/// so the first request after ~15 min idle pays a cold start. Not
/// user-configurable yet; for local gateway work, point this at
/// `http://localhost:8000` (`cd server/ai-gateway && uvicorn app.main:app`).
const String cloudGatewayBaseUrl = 'https://inkflow-ai-gateway.onrender.com';

/// The two cloud tiers the Phase 3 gateway serves, each a thin [AiProvider]
/// over the same gateway with a different `model_tier`. [cloudGatewayMidProvider]
/// is typed as the concrete class (not just [AiProvider]) because Research
/// (Loop 3.4) also needs its [ToolCallingClient]-only `generateWithTools` —
/// every existing [AiProvider]-typed consumer still works unchanged since
/// [CloudGatewayProvider] implements that interface too.
final cloudGatewayMidProvider = Provider<CloudGatewayProvider>(
    (ref) => CloudGatewayProvider(baseUrl: cloudGatewayBaseUrl, modelTier: 'cloud-mid'));
final cloudGatewayFrontierProvider = Provider<AiProvider>((ref) =>
    CloudGatewayProvider(baseUrl: cloudGatewayBaseUrl, modelTier: 'cloud-frontier'));

/// Decides local vs. cloud-mid vs. cloud-frontier per request. Additive
/// alongside the existing, simpler [AiRouter] (still serves Summarize).
final intelligentRouterProvider = Provider<IntelligentRouter>((ref) =>
    IntelligentRouter(
      localCapabilities: ref.watch(localAiProvider).capabilities,
      localDegraded: ref.read(localDegradedProvider),
    ));

/// Explain, routed through the Phase 3 Intelligent Router — the one feature
/// wired to it in this pass (see `intelligent_router.dart`'s header for why
/// the others aren't, yet). [ExplainNotifier] reads [RoutedAiProvider.peekRoute]
/// directly (not through [Explainer]) so it can gate on user confirmation
/// before the network call — see `explain_notifier.dart`.
final explainAiProviderProvider = Provider<RoutedAiProvider>((ref) {
  return RoutedAiProvider(
    task: TaskType.explain,
    router: ref.watch(intelligentRouterProvider),
    local: ref.watch(localAiProvider),
    cloudMid: ref.watch(cloudGatewayMidProvider),
    cloudFrontier: ref.watch(cloudGatewayFrontierProvider),
    privacy: () => ref.read(settingsProvider).cloudPrivacy,
  );
});

/// Explain feature — streams an explanation of a passage, routed per
/// [explainAiProviderProvider].
final explainerProvider = Provider<Explainer>(
    (ref) => Explainer(provider: ref.watch(explainAiProviderProvider)));

/// The Loop 3.4 tool set — Calculator (no network) plus Wikipedia and Web
/// Search (both network, both cloud-only — see `researcher.dart`'s header).
/// [WebSearchTool] talks to the gateway's own `/v1/tools/search`, never to
/// Exa directly, using the same [sessionDeviceKey] identity as the LLM calls.
final toolsProvider = Provider<List<Tool>>((ref) => [
      const CalculatorTool(),
      WikipediaTool(),
      WebSearchTool(baseUrl: cloudGatewayBaseUrl, deviceKey: sessionDeviceKey),
    ]);

/// Research feature — free-form questions that may reach outside the notes
/// via [toolsProvider]'s tools. Cloud-mid only, never local, never frontier
/// (see `researcher.dart`'s header for why on-device is skipped this loop).
final researcherProvider = Provider<Researcher>((ref) => Researcher(
      client: ref.watch(cloudGatewayMidProvider),
      tools: ref.watch(toolsProvider),
    ));

/// Drives the sidebar's Research surface. Session-scoped (not autoDispose),
/// same reasoning as Ask/Explain/Quiz: closing the sidebar must not abort an
/// in-flight request, and the answer stays put until dismissed.
final researchNotifierProvider =
    StateNotifierProvider<ResearchNotifier, ResearchState>((ref) {
  return ResearchNotifier(
    researcher: ref.watch(researcherProvider),
    privacy: () => ref.read(settingsProvider).cloudPrivacy,
    hasSeenFirstCloudCall: () => ref.read(settingsProvider).hasSeenFirstCloudCall,
    markFirstCloudCallSeen: () =>
        ref.read(settingsProvider.notifier).markFirstCloudCallSeen(),
  );
});

/// Writing Assistant feature — reviews typed text for grammar/clarity/etc.
final writingAssistantProvider = Provider<WritingAssistant>(
    (ref) => WritingAssistant(provider: ref.watch(localAiProvider)));

/// Quiz Generator feature — builds gradeable questions from page content.
final quizGeneratorProvider = Provider<QuizGenerator>(
    (ref) => QuizGenerator(provider: ref.watch(localAiProvider)));

/// Drives the quiz sheet. Session-scoped (not autoDispose): closing the sidebar
/// must not abort an in-flight model download, and the generated quiz stays put
/// while the taker works through it.
final quizNotifierProvider =
    StateNotifierProvider<QuizNotifier, QuizState>((ref) {
  return QuizNotifier(
    generator: ref.watch(quizGeneratorProvider),
    downloads: ref.watch(modelDownloadManagerProvider),
  );
});

/// Flashcard Generator feature — builds a deck from a page's concepts/definitions.
final flashcardGeneratorProvider = Provider<FlashcardGenerator>(
    (ref) => FlashcardGenerator(provider: ref.watch(localAiProvider)));

/// Durable flashcard store (Isar). Flashcards persist across sessions.
final flashcardStoreProvider =
    Provider<FlashcardStore>((ref) => IsarFlashcardStore());

/// Drives the flashcard sheet. Session-scoped for the same reasons as the quiz.
final flashcardNotifierProvider =
    StateNotifierProvider<FlashcardNotifier, FlashcardState>((ref) {
  return FlashcardNotifier(
    generator: ref.watch(flashcardGeneratorProvider),
    store: ref.watch(flashcardStoreProvider),
    downloads: ref.watch(modelDownloadManagerProvider),
  );
});

/// Durable Learning Memory (Isar) — concept mastery, quiz history, preferences.
/// Phase 2's counterpart to the session-only [pageContextCacheProvider].
final learningMemoryProvider =
    Provider<LearningMemoryRepository>((ref) => IsarLearningMemoryRepository());

/// Which slice of a notebook a graph should be built from — the family key for
/// [knowledgeGraphProvider].
///
/// A record rather than a bare notebookId because the graph is no longer only
/// notebook-wide: it can be built for this page, this imported PDF, or the
/// whole notebook, using the same concepts and relations the Context Engine
/// already recorded (see `domain/ai_scope.dart`). [pageId] is what
/// [AiScopeKind.page] and [AiScopeKind.importGroup] resolve against, and is
/// unused for [AiScopeKind.notebook].
typedef KnowledgeGraphRequest = ({
  int notebookId,
  AiScopeKind kind,
  int? pageId,
});

/// A notebook-wide request, for callers with no page in hand.
KnowledgeGraphRequest wholeNotebookGraph(int notebookId) =>
    (notebookId: notebookId, kind: AiScopeKind.notebook, pageId: null);

/// A concept map: mastery-tagged nodes + Context-Engine edges, assembled from
/// Learning Memory and narrowed to [request]'s scope. A FutureProvider.family
/// so the graph screen can show loading/empty/error states per scope. Not
/// cached across the app beyond Riverpod's own lifecycle — cheap to rebuild
/// from Isar.
///
/// A scoped graph reads the SAME extraction path as the notebook-wide one: the
/// Context Engine's per-page analysis is what produces every concept and edge,
/// so narrowing is a filter over what it already recorded rather than a second,
/// differently-behaved pipeline.
final knowledgeGraphProvider =
    FutureProvider.family<KnowledgeGraph, KnowledgeGraphRequest>(
        (ref, request) async {
  final memory = ref.watch(learningMemoryProvider);
  final notebookId = request.notebookId;

  if (request.kind == AiScopeKind.notebook || request.pageId == null) {
    return KnowledgeGraph.build(
      concepts: await memory.allConcepts(notebookId),
      relations: await memory.relationsForNotebook(notebookId),
    );
  }

  final scope = await ref.watch(aiScopeResolverProvider).resolve(
        kind: request.kind,
        notebookId: notebookId,
        pageId: request.pageId!,
      );
  final pageIds = scope.pageIdSet;
  return KnowledgeGraph.build(
    concepts: await memory.conceptsForPages(notebookId, pageIds),
    relations: await memory.relationsForPages(notebookId, pageIds),
  );
});

/// Durable store of generated study plans (Isar), one per notebook.
final studyPlanStoreProvider =
    Provider<StudyPlanStore>((ref) => IsarStudyPlanStore());

/// Drives the Study Planner for one notebook: loads any saved plan, generates a
/// new one from Learning-Memory signals (deterministic — no model), toggles
/// day completion. Family-scoped so each notebook keeps its own plan state.
final studyPlannerProvider = StateNotifierProvider.family<StudyPlannerNotifier,
    AsyncValue<StudyPlan?>, int>((ref, notebookId) {
  return StudyPlannerNotifier(
    memory: ref.watch(learningMemoryProvider),
    store: ref.watch(studyPlanStoreProvider),
    notebookId: notebookId,
  );
});

/// Reads dates out of note text — ML Kit Entity Extraction, on-device. One
/// extractor for the app, freed with the container.
final dateFinderProvider = Provider<DateFinder>((ref) {
  final finder = MlKitDateFinder();
  ref.onDispose(finder.dispose);
  return finder;
});

/// The quiz and exam dates written in a notebook's notes, soonest first — what
/// the Study Planner offers as an exam countdown. Read from the stored page text
/// the moment the student asks (autoDispose: nothing runs until the planner
/// watches it), so there is no index to keep in step with edits.
final noteDeadlinesProvider = FutureProvider.autoDispose
    .family<List<NoteDeadline>, int>((ref, notebookId) async {
  final pages = await ref.read(pageTextStoreProvider).forNotebook(notebookId);
  return findNoteDeadlines(
    pageTexts: {for (final p in pages) p.pageId: p.text},
    finder: ref.read(dateFinderProvider),
    now: DateTime.now(),
  );
});

/// Session cache of the last suggestions per page (see [pageContextCacheProvider]).
final pageWritingCacheProvider =
    Provider<PageWritingCache>((ref) => PageWritingCache());

/// Writing suggestions for one page. autoDispose + fed by the Context Engine's
/// debounce, so it does no work unless the sidebar is open and content changes.
final writingSuggestionsProvider = StateNotifierProvider.autoDispose
    .family<WritingAssistantNotifier, List<WritingSuggestion>, ScenePageKey>(
        (ref, key) {
  return WritingAssistantNotifier(
    assistant: ref.watch(writingAssistantProvider),
    cache: ref.watch(pageWritingCacheProvider),
    pageId: key.pageId,
  );
});

/// Drives the sidebar's Explain surface. Session-scoped (not autoDispose):
/// closing/reopening the sidebar must not abort an in-flight model download,
/// and the last explanation stays available until dismissed.
final explainNotifierProvider =
    StateNotifierProvider<ExplainNotifier, ExplainState>((ref) {
  return ExplainNotifier(
    explainer: ref.watch(explainerProvider),
    downloads: ref.watch(modelDownloadManagerProvider),
    evaluateCloudRoute: (content) =>
        ref.read(explainAiProviderProvider).peekRoute(content),
    hasSeenFirstCloudCall: () => ref.read(settingsProvider).hasSeenFirstCloudCall,
    markFirstCloudCallSeen: () =>
        ref.read(settingsProvider.notifier).markFirstCloudCallSeen(),
    guard: ref.watch(aiQualityGuardProvider),
  );
});

/// Live context for one page. autoDispose: analysis runs only while something
/// (the AI sidebar) watches. The editor's scene state is observed through a
/// read-only listener here — the editor never knows the engine exists.
final pageContextProvider = StateNotifierProvider.autoDispose
    .family<ContextEngineNotifier, AsyncValue<PageContext>, ScenePageKey>(
        (ref, key) {
  final notifier = ContextEngineNotifier(
    engine: ref.watch(contextEngineProvider),
    extractor: ref.watch(pageContentExtractorProvider),
    recognition: ref.watch(handwritingRecognitionServiceProvider),
    cache: ref.watch(pageContextCacheProvider),
    pageId: key.pageId,
    languageCode: () => ref.read(settingsProvider).recognitionLanguage,
    // Writing Assistant and RAG indexing both ride this same debounce +
    // extraction (no second recognition pass, no second loop).
    onContent: (content) {
      // Searchable text is persisted immediately and unconditionally — before
      // anything that could throw, and deliberately NOT behind the indexer's
      // 20s debounce or its embedding step. Search must work for someone who
      // has never downloaded the embedding model, so this write is the one
      // thing here that cannot be allowed to depend on the AI stack.
      unawaited(ref.read(pageTextStoreProvider).save(
            notebookId: key.notebookId,
            pageId: key.pageId,
            text: content.combinedText,
          ));
      // Indexing goes FIRST deliberately. ContextEngineNotifier._notifyContent
      // guards the engine from this callback, but nothing guards these two
      // listeners from each other: a throw in the first would silently starve
      // the second. Scheduling only sets a timer and cannot realistically
      // throw, whereas review() reaches into an autoDispose notifier.
      // Figures ARE indexed (unlike the search text above, which stays the
      // student's own words): "what did my revenue chart show" has to be able
      // to retrieve the page holding that chart.
      ref.read(ragIndexSchedulerProvider).schedule(
            notebookId: key.notebookId,
            pageId: key.pageId,
            text: content.combinedTextWithFigures,
          );
      ref.read(writingSuggestionsProvider(key).notifier).review(content);
    },
    // Learning Memory rides it too: every analyzed page records which concepts
    // the learner was exposed to. Fire-and-forget — a storage hiccup must never
    // surface as an analysis failure.
    onContext: (context) => unawaited(
      ref
          .read(learningMemoryProvider)
          .observePageContext(
            notebookId: key.notebookId,
            pageId: key.pageId,
            keyConcepts: context.keyConcepts,
            knowledgeGaps: context.knowledgeGaps,
            // Knowledge Graph edges, captured from the same analysis pass.
            relations: context.relatedConcepts,
          )
          .catchError((Object _) {}),
    ),
  );
  ref.listen(
    sceneControllerProvider(key),
    (_, elements) => notifier.onSceneChanged(elements),
    fireImmediately: true,
  );
  return notifier;
});
