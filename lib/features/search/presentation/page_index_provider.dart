// Wires the page index queue to the app: reads pages with ML Kit only (no
// vision model, no cloud), and runs when the app starts, when it comes back,
// and when a notebook is closed.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../data/persistence/page_index_queue.dart';
import '../../../data/persistence/page_text_store.dart';
import '../../ai/data/handwriting/handwriting_recognition_service.dart'
    show RecognitionException;
import '../../ai/domain/ai_exception.dart' show AiModelNotReadyException;
import '../../ai/domain/device_state.dart' show backgroundPauseReason;
import '../../ai/presentation/ai_providers.dart'
    show deviceHealthProvider, pageContentExtractorProvider;

final pageIndexQueueProvider = Provider<PageIndexQueue>((ref) {
  final extractor = ref.watch(pageContentExtractorProvider);
  return PageIndexQueue(
    texts: ref.watch(pageTextStoreProvider),
    readPage: (pageId) async {
      try {
        // The light read the live loop does: on the device, nothing to load.
        final c = await extractor.extractPage(
          pageId,
          languageCode: ref.read(settingsProvider).recognitionLanguage,
        );
        // Pictures that could not be read and nothing else: a failed read,
        // not an empty page (saving '' would wipe what search has).
        if (c.combinedTextWithFigures.isEmpty && c.hasUnrecognizedImages) {
          throw StateError('page $pageId: pictures could not be read');
        }
        return (text: c.combinedText, indexText: c.combinedTextWithFigures);
      } on RecognitionException {
        throw const PageReadDeferred(); // no handwriting model yet
      } on AiModelNotReadyException {
        throw const PageReadDeferred();
      }
    },
    shouldPause: () async =>
        backgroundPauseReason(await ref.read(deviceHealthProvider).read()) !=
        null,
  );
});

/// Runs the queue a few seconds after start-up and whenever the app comes
/// back. Read once from the app root.
final pageIndexLifecycleProvider = Provider<void>((ref) {
  Timer? startup;
  void run() => unawaited(ref.read(pageIndexQueueProvider).run());
  final listener = AppLifecycleListener(onResume: run);
  ref.onDispose(() {
    listener.dispose();
    startup?.cancel();
  });
  ref.listen<bool>(settingsProvider.select((s) => s.loaded), (was, loaded) {
    if (loaded && was != true) {
      startup = Timer(const Duration(seconds: 5), run);
    }
  }, fireImmediately: true);
});
