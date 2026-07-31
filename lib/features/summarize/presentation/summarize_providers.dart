// Riverpod wiring for the summarize feature — a consumer of the AI platform
// (features/ai): extraction, generation, routing and download management come
// from ai_providers.dart; only summarize-specific composition lives here.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/domain/ai_router.dart';
import '../../ai/presentation/ai_providers.dart';
import '../data/cache/summary_store.dart';
import '../domain/services/summarization_service.dart';

export '../../ai/presentation/ai_providers.dart'
    show
        handwritingRecognitionServiceProvider,
        modelDownloadManagerProvider,
        embedderDownloadManagerProvider,
        modelStorageCleanerProvider,
        huggingFaceTokenProvider,
        huggingFaceIdentityProvider;

final aiRouterProvider = Provider<AiRouter>((ref) {
  final downloads = ref.watch(modelDownloadManagerProvider);
  return AiRouter(
    localCapabilities: ref.watch(localAiProvider).capabilities,
    isLocalModelInstalled: downloads.isInstalled,
  );
});

final summarizationServiceProvider = Provider<SummarizationService>((ref) {
  return SummarizationService(
    extractor: ref.watch(pageContentExtractorProvider),
    router: ref.watch(aiRouterProvider),
    local: ref.watch(localAiProvider),
    cloud: ref.watch(cloudLlmClientProvider),
    // The accuracy fail-safe: a summary the on-device model mangled is
    // re-run on the cloud tier when the user's privacy setting allows it,
    // and labelled low-confidence when it doesn't.
    guard: ref.watch(aiQualityGuardProvider),
    store: IsarSummaryStore(),
  );
});
