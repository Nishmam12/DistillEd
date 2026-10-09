part of 'ai_providers.dart';

/// The on-device EMBEDDING model (EmbeddingGemma) — a different model from the
/// LLM above, with its own download and its own mutex.
///
/// Exposed separately rather than only through [AiProvider.embed] because
/// embeddings are model-locked and must never be routed: see the header of
/// `domain/rag/text_embedder.dart`.
final textEmbedderProvider = Provider<TextEmbedder>(
    (ref) => LocalTextEmbedder(spec: ref.watch(servingEmbedderSpecProvider)));

/// The embedding model that answers questions and embeds new notes: the one the
/// rollout says is serving (docs/TECH_MIGRATION_PLAN.md, phase 4.5). It is the
/// active model until a switch, and changes only when a switch completes. An id no
/// spec has is an error: answering with another vector space would look plausible
/// and be wrong.
final servingEmbedderSpecProvider = Provider<EmbedderSpec>((ref) {
  final serving =
      ref.watch(embedderRolloutStatusProvider).value?.answeringModelId;
  if (serving == null) return EmbedderSpec.active;
  return EmbedderSpec.registry.firstWhere(
    (spec) => spec.modelId == serving,
    orElse: () => throw StateError('no embedder spec has the id $serving'),
  );
});

/// The effective HuggingFace token for gated downloads.
///
/// The user's Settings token is authoritative. In DEBUG builds only, a local
/// dev token ([kDevHuggingFaceToken], `lib/dev/dev_secrets.dart`) fills in when Settings is
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
    titleOf: (notebookId, pageId) => _pageTitle(ref, notebookId, pageId),
  );
});

/// What a page is embedded under: its notebook, and for an import its document.
Future<String?> _pageTitle(Ref ref, int notebookId, int pageId) async {
  final notebook =
      await ref.read(noteRepositoryProvider).getNotebook(notebookId);
  final pages =
      await ref.read(pageRepositoryProvider).getPagesForNotebook(notebookId);
  String? source;
  for (final page in pages) {
    if (page.id == pageId) source = page.importSourceName;
  }
  return chunkTitle(notebookTitle: notebook?.title, sourceName: source);
}

/// [_pageTitle] for a batch job: each notebook and its pages are read once, not
/// once per page. A rename mid-pass is picked up by the next pass.
Future<String?> Function(int, int) _memoizedPageTitle(Ref ref) {
  final byNotebook = <int, Future<(String?, Map<int, String?>)>>{};
  return (notebookId, pageId) async {
    final (title, sources) = await byNotebook.putIfAbsent(notebookId, () async {
      final notebook =
          await ref.read(noteRepositoryProvider).getNotebook(notebookId);
      final pages = await ref
          .read(pageRepositoryProvider)
          .getPagesForNotebook(notebookId);
      return (
        notebook?.title,
        {for (final p in pages) p.id: p.importSourceName},
      );
    });
    return chunkTitle(notebookTitle: title, sourceName: sources[pageId]);
  };
}

/// Every page with text, across every notebook, for the rollout's indexing job.
Future<List<RolloutPage>> _rolloutPages(Ref ref) async {
  final pages = <RolloutPage>[];
  final notebooks = await ref.read(noteRepositoryProvider).getAllNotebooks();
  for (final notebook in notebooks) {
    final texts = await ref.read(pageTextStoreProvider).forNotebook(notebook.id);
    for (final page in texts) {
      // What the live and bulk indexers embedded, so a rebuilt index matches them.
      if (page.indexText.trim().isNotEmpty) {
        pages.add(RolloutPage(
          notebookId: notebook.id,
          pageId: page.pageId,
          text: page.indexText,
        ));
      }
    }
  }
  return pages;
}

/// The shadow re-index (docs/TECH_MIGRATION_PLAN.md, phase 4.5): downloads a target
/// model, builds its chunks beside the serving ones, and switches once every page
/// is current. [embedderRolloutResumeProvider] starts and resumes it at launch.
final embedderRolloutRunnerProvider = Provider<EmbedderRolloutRunner>((ref) {
  final store = ref.watch(noteChunkStoreProvider);
  return EmbedderRolloutRunner(
    states: SharedPrefsRolloutStateStore(),
    models: EmbedderRolloutModels(
      installerFor: embedderInstallerFor,
      downloadFor: (spec) async {
        final manager = EmbedderDownloadManager(
          spec: spec,
          authToken: () => ref.read(huggingFaceTokenProvider),
        );
        try {
          await manager.download();
        } finally {
          manager.dispose();
        }
      },
    ),
    chunks: store,
    index: NotebookRolloutIndex(
      pages: () => _rolloutPages(ref),
      indexerFor: (target) => RagIndexer(
        embedder: target,
        saveChunks: store.replaceForPage,
        deleteChunks: store.deleteForPage,
        indexStateOf: store.indexStateForPage,
        titleOf: _memoizedPageTitle(ref),
      ),
      // The same rule the bulk indexer follows: wait while hot or low on power.
      pauseReason: () async =>
          backgroundPauseReason(await ref.read(deviceHealthProvider).read()),
    ),
    embedderFor: (modelId) => LocalTextEmbedder(
      spec: EmbedderSpec.registry.firstWhere(
        (spec) => spec.modelId == modelId,
        orElse: () => throw StateError('no embedder spec has the id $modelId'),
      ),
    ),
    now: DateTime.now,
  );
});

/// True while a new search model waits on the user's mobile-data answer.
final embedderMobileDataPromptProvider = StateProvider<bool>((ref) => false);

/// Launch hook for the rollout (see [EmbedderRolloutRunner.resume]). The
/// download needs the HuggingFace token, and on a metered network it needs the
/// user's say-so: until they answer, or while they chose Wi-Fi only, the rollout
/// waits and this checks again every few minutes. Failures leave the saved state,
/// so the next launch retries.
final embedderRolloutResumeProvider = FutureProvider<void>((ref) async {
  var waiting = false;
  try {
    waiting = await ref.read(embedderRolloutRunnerProvider).resume(
      EmbedderSpec.active.modelId,
      mayDownload: () async {
        if (ref.read(huggingFaceTokenProvider).isEmpty) return false;
        if (!(await ref.read(deviceHealthProvider).read()).metered) return true;
        switch (await loadMobileDataChoice()) {
          case MobileDataChoice.allow:
            return true;
          case MobileDataChoice.wifiOnly:
            return false;
          case MobileDataChoice.ask:
            ref.read(embedderMobileDataPromptProvider.notifier).state = true;
            return false;
        }
      },
    );
  } catch (e) {
    debugPrint('embedder rollout resume failed: $e');
  }
  ref.invalidate(embedderRolloutStatusProvider);
  if (waiting) {
    // ponytail: polls while the app is open; a connectivity listener would react
    // the moment Wi-Fi joins.
    final timer = Timer(const Duration(minutes: 2), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
});

/// The rollout as it was last saved, for the Settings row and for the model that
/// answers questions. While a rollout runs it is read again every second, so the
/// progress row moves; each step saves before the next one starts, so each read is
/// current. Invalidate it after an action that changes the saved state.
final embedderRolloutStatusProvider =
    StreamProvider<EmbedderRollout>((ref) async* {
  final states = SharedPrefsRolloutStateStore();
  while (true) {
    final rollout = await states.load(EmbedderSpec.active.modelId);
    yield rollout;
    if (!rollout.isRunning) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});

/// Whether the dry run's copy is installed. Only the debug settings read it.
final dryRunCopyInstalledProvider = FutureProvider<bool>((ref) {
  const copy = EmbedderSpec.dryRunCopy;
  return embedderInstallerFor(copy).isInstalled(copy);
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
      final text = content.combinedTextWithFigures;
      // Images that could not be read and nothing else to show for the page:
      // this is a failed read (OOM, timeout, no model), not an empty page.
      // Returning '' would CLEAR the page's chunks and search text, so fail the
      // page instead and keep what is already indexed.
      if (text.isEmpty && content.hasUnrecognizedImages) {
        throw StateError('page $pageId has images that could not be read');
      }
      return text;
    },
    // The reads are the expensive part and a missing embedder would throw every
    // one of them away, so find out before the first.
    // The model that embeds the notes, which after a switch is not the active one.
    embedderReady: () async {
      final spec = ref.read(servingEmbedderSpecProvider);
      return embedderInstallerFor(spec).isInstalled(spec);
    },
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
              indexText: text,
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
