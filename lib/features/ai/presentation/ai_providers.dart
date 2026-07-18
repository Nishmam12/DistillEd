// Riverpod wiring for the AI platform (this codebase uses Riverpod as its DI
// mechanism throughout — get_it is unused). Features consume these providers;
// nothing in features/ai depends on a consumer feature.

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../dev/dev_secrets.dart';
import '../../../editor/state/scene_controller.dart';
import '../data/embeddings/embedder_download_manager.dart';
import '../data/embeddings/local_text_embedder.dart';
import '../data/flashcards/flashcard_store.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/cloud_llm_client.dart';
import '../data/llm/model_download_manager.dart';
import '../data/memory/learning_memory_repository.dart';
import '../data/providers/cloud_gateway_provider.dart';
import '../data/providers/local_gemma_provider.dart';
import '../data/rag/note_chunk_store.dart';
import '../data/study_planner/study_plan_store.dart';
import '../domain/ai_provider.dart';
import '../domain/context_engine/context_engine.dart';
import '../domain/context_engine/page_context.dart';
import '../domain/features/explainer.dart';
import '../domain/features/flashcard_generator.dart';
import '../domain/features/quiz_generator.dart';
import '../domain/features/notes_qa.dart';
import '../domain/features/writing_assistant.dart';
import '../domain/knowledge_graph/knowledge_graph.dart';
import '../domain/page_content_extractor.dart';
import '../domain/rag/rag_indexer.dart';
import '../domain/rag/rag_retriever.dart';
import '../domain/rag/text_embedder.dart';
import '../domain/routing/intelligent_router.dart';
import '../domain/study_planner/study_plan.dart';
import 'ask_notes_notifier.dart';
import 'study_planner_notifier.dart';
import 'context_engine_notifier.dart';
import 'explain_notifier.dart';
import 'flashcard_notifier.dart';
import 'quiz_notifier.dart';
import 'rag_index_scheduler.dart';
import 'writing_assistant_notifier.dart';

final handwritingRecognitionServiceProvider =
    Provider<HandwritingRecognitionService>((ref) {
  final service = HandwritingRecognitionService();
  ref.onDispose(service.dispose);
  return service;
});

final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  final manager = ModelDownloadManager();
  ref.onDispose(manager.dispose);
  return manager;
});

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

/// Semantic search over a notebook, feeding "Ask your notes".
final ragRetrieverProvider = Provider<RagRetriever>((ref) => RagRetriever(
      embedder: ref.watch(textEmbedderProvider),
      loadChunks: ref.watch(noteChunkStoreProvider).forNotebook,
    ));

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
  );
});

/// Cloud tier seam — a no-op stub until Phase 3 stands up the gateway.
final cloudLlmClientProvider =
    Provider<CloudLlmClient>((ref) => StubCloudLlmClient());

/// The one way AI features read a page (editor-2.0 scene store underneath).
final pageContentExtractorProvider = Provider<PageContentExtractor>((ref) {
  final store = ref.watch(sceneElementStoreProvider);
  return PageContentExtractor(
    loadElements: store.loadForPage,
    recognition: ref.watch(handwritingRecognitionServiceProvider),
  );
});

/// Session-lifetime cache of the last PageContext per page; survives the
/// sidebar closing and page switches (durable persistence is Phase 2's
/// Learning Memory).
final pageContextCacheProvider =
    Provider<PageContextCache>((ref) => PageContextCache());

final contextEngineProvider = Provider<ContextEngine>(
    (ref) => ContextEngine(provider: ref.watch(localAiProvider)));

/// The Phase 3 cloud gateway's base URL. Not deployed yet (per the phase
/// spec's own scope) — defaults to a local dev instance
/// (`cd server/ai-gateway && uvicorn app.main:app`). Not user-configurable
/// yet; revisit once a real deployment exists.
const String cloudGatewayBaseUrl = 'http://localhost:8000';

/// The two cloud tiers the Phase 3 gateway serves, each a thin [AiProvider]
/// over the same gateway with a different `model_tier`.
final cloudGatewayMidProvider = Provider<AiProvider>(
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

/// The notebook's concept map: mastery-tagged nodes + Context-Engine edges,
/// assembled from Learning Memory. A FutureProvider.family so the graph screen
/// can show loading/empty/error states per notebook. Not cached across the app
/// beyond Riverpod's own lifecycle — cheap to rebuild from Isar.
final knowledgeGraphProvider =
    FutureProvider.family<KnowledgeGraph, int>((ref, notebookId) async {
  final memory = ref.watch(learningMemoryProvider);
  final concepts = await memory.allConcepts(notebookId);
  final relations = await memory.relationsForNotebook(notebookId);
  return KnowledgeGraph.build(concepts: concepts, relations: relations);
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
      // Indexing goes FIRST deliberately. ContextEngineNotifier._notifyContent
      // guards the engine from this callback, but nothing guards these two
      // listeners from each other: a throw in the first would silently starve
      // the second. Scheduling only sets a timer and cannot realistically
      // throw, whereas review() reaches into an autoDispose notifier.
      ref.read(ragIndexSchedulerProvider).schedule(
            notebookId: key.notebookId,
            pageId: key.pageId,
            text: content.combinedText,
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
