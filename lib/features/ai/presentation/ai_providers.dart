// Riverpod wiring for the AI platform (this codebase uses Riverpod as its DI
// mechanism throughout). Features consume these providers; nothing in
// features/ai depends on a consumer feature.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/search_providers.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../dev/dev_secrets.dart';
import '../../../editor/render/scene_exporter.dart';
import '../../../editor/render/scene_image_cache.dart';
import '../../../editor/state/page_notifier.dart' show pageRepositoryProvider;
import '../../../editor/state/scene_controller.dart';
import '../data/embeddings/embedder_download_manager.dart';
import '../data/embeddings/local_text_embedder.dart';
import '../data/flashcards/flashcard_store.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/cloud_llm_client.dart';
import '../data/llm/hf_token_check.dart';
import '../data/llm/model_download_manager.dart';
import '../data/llm/model_storage_cleaner.dart';
import '../data/memory/learning_memory_repository.dart';
import '../data/ocr/gemma_vision_ocr_service.dart';
import '../data/ocr/image_text_recognition_service.dart';
import '../data/providers/cloud_gateway_provider.dart';
import '../data/providers/local_gemma_provider.dart';
import '../data/rag/note_chunk_store.dart';
import '../data/study_planner/study_plan_store.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_scope.dart';
import '../domain/context_engine/context_engine.dart';
import '../domain/context_engine/page_context.dart';
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
import '../domain/rag/rag_indexer.dart';
import '../domain/rag/rag_retriever.dart';
import '../domain/rag/text_embedder.dart';
import '../domain/routing/cloud_first_transcriber.dart';
import '../domain/routing/intelligent_router.dart';
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
    Provider<ModelStorageCleaner>((ref) => FlutterGemmaStorageCleaner());

/// The on-device model behind the platform-wide [AiProvider] contract —
/// streaming, typed failures, load→generate→unload memory invariant.
final localAiProvider = Provider<AiProvider>(
    (ref) => LocalGemmaProvider(embedder: ref.watch(textEmbedderProvider)));

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
    renderInk: (inkElements) => SceneExporter.toPng(inkElements),
    loadImageBytes: (relative) =>
        _readFileBytes(SceneImageCache.resolvePath(docsDir, relative)),
    // Charts and diagrams — drawn with the shape tools or pasted in — read as
    // structured figures instead of vanishing into a few OCR'd axis labels.
    figureAnalyzer: ref.watch(figureAnalyzerProvider),
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
    IntelligentRouter(localCapabilities: ref.watch(localAiProvider).capabilities));

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
