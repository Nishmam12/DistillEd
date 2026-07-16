// Riverpod wiring for the summarize feature (this codebase uses Riverpod as
// its DI mechanism throughout — get_it is unused).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache/summary_store.dart';
import '../data/llm/cloud_llm_client.dart';
import '../data/llm/local_llm_service.dart';
import '../data/llm/model_download_manager.dart';
import '../domain/services/ai_router.dart';
import '../domain/services/handwriting_recognition_service.dart';
import '../domain/services/summarization_service.dart';

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

final localLlmServiceProvider =
    Provider<LocalLlmService>((ref) => LocalLlmService());

final cloudLlmClientProvider =
    Provider<CloudLlmClient>((ref) => StubCloudLlmClient());

final aiRouterProvider = Provider<AiRouter>((ref) {
  final downloads = ref.watch(modelDownloadManagerProvider);
  return AiRouter(isLocalModelInstalled: downloads.isInstalled);
});

final summarizationServiceProvider = Provider<SummarizationService>((ref) {
  return SummarizationService(
    recognition: ref.watch(handwritingRecognitionServiceProvider),
    router: ref.watch(aiRouterProvider),
    localLlm: ref.watch(localLlmServiceProvider),
    cloud: ref.watch(cloudLlmClientProvider),
    store: IsarSummaryStore(),
  );
});
