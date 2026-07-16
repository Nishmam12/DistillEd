// Riverpod wiring for the AI platform (this codebase uses Riverpod as its DI
// mechanism throughout — get_it is unused). Features consume these providers;
// nothing in features/ai depends on a consumer feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../editor/state/scene_controller.dart';
import '../data/handwriting/handwriting_recognition_service.dart';
import '../data/llm/cloud_llm_client.dart';
import '../data/llm/local_llm_service.dart';
import '../data/llm/model_download_manager.dart';
import '../data/providers/local_gemma_provider.dart';
import '../domain/ai_provider.dart';
import '../domain/page_content_extractor.dart';

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

/// Non-streaming convenience over the local runtime (used by Summarize).
final localLlmServiceProvider =
    Provider<LocalLlmService>((ref) => LocalLlmService());

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
