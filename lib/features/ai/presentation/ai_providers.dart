// Riverpod wiring for the AI platform (this codebase uses Riverpod as its DI
// mechanism throughout — get_it is unused). Features consume these providers;
// nothing in features/ai depends on a consumer feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../editor/state/scene_controller.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/cloud_llm_client.dart';
import '../data/llm/model_download_manager.dart';
import '../data/providers/local_gemma_provider.dart';
import '../domain/ai_provider.dart';
import '../domain/context_engine/context_engine.dart';
import '../domain/context_engine/page_context.dart';
import '../domain/page_content_extractor.dart';
import 'context_engine_notifier.dart';

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
final localAiProvider = Provider<AiProvider>((ref) => LocalGemmaProvider());

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
  );
  ref.listen(
    sceneControllerProvider(key),
    (_, elements) => notifier.onSceneChanged(elements),
    fireImmediately: true,
  );
  return notifier;
});
