// Riverpod wiring for the summarize feature — a consumer of the AI platform
// (features/ai): runtime, recognition and download management come from
// ai_providers.dart; only summarize-specific composition lives here.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/presentation/ai_providers.dart';
import '../../editor/presentation/page_notifier.dart';
import '../data/cache/summary_store.dart';
import '../data/scene_notebook_ink_loader.dart';
import '../domain/services/ai_router.dart';
import '../domain/services/summarization_service.dart';
import '../../../editor/state/scene_controller.dart';

export '../../ai/presentation/ai_providers.dart'
    show handwritingRecognitionServiceProvider, modelDownloadManagerProvider;

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

/// Editor-2.0 ink source: freehand elements from the unified scene store,
/// adapted to the recognition pipeline's stroke shape.
final sceneNotebookInkLoaderProvider = Provider<SceneNotebookInkLoader>((ref) {
  return SceneNotebookInkLoader(
    store: ref.watch(sceneElementStoreProvider),
    pagesOf: ref.watch(pageRepositoryProvider).getPagesForNotebook,
  );
});
