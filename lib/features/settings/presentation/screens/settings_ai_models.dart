part of 'settings_screen.dart';

/// Shows the downloaded state of the on-device LLM and the handwriting
/// language models, with delete actions to reclaim storage.
class _AiModelsCard extends ConsumerStatefulWidget {
  const _AiModelsCard();

  @override
  ConsumerState<_AiModelsCard> createState() => _AiModelsCardState();
}

class _AiModelsCardState extends ConsumerState<_AiModelsCard> {
  /// Bumped after a delete so the FutureBuilders re-query install status.
  int _refresh = 0;

  /// Rows whose download is running, and the percent of those that report one.
  final Set<String> _downloading = {};
  final Map<String, int> _percent = {};

  /// Debug builds only: shares the notes as the corpus the embedding evaluation
  /// reads. A failure is shown, since this is a button and not a background job.
  Future<void> _exportCorpus() async {
    try {
      await shareRagCorpus(ref);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't export the corpus: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.read(modelDownloadManagerProvider);
    final recognition = ref.read(handwritingRecognitionServiceProvider);
    final sizeGb =
        LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);
    // Where the model ran the last time it loaded; null until it has loaded.
    final backend = ref.watch(localBackendProvider);
    // The Whisper row reads whether it is installed only when it is built, so
    // it is rebuilt whenever the speech model changes (a download or a delete).
    final speechPhase =
        ref.watch(speechModelProvider.select((s) => s.phase));

    return _SettingsCard(
      children: [
        _modelRow(
          key: ValueKey('llm-$_refresh'),
          icon: PhosphorIconsRegular.brain,
          title: '${LlmModelSpec.active.displayName} (on-device AI)',
          sizeLabel: '${sizeGb.toStringAsFixed(1)} GB',
          isInstalled: downloads.isInstalled,
          confirmDelete: true,
          onDelete: downloads.delete,
          onDownload: downloads.download,
          progress: downloads.progress,
          // Said plainly because the fall-back from GPU to CPU is silent: a
          // device that is several times slower than it should be otherwise
          // gives no hint why.
          detail: switch (backend) {
            null => null,
            ComputeBackend.gpu => 'Running on the GPU',
            ComputeBackend.npu => 'Running on the NPU',
            ComputeBackend.cpu => 'Running on the CPU — slower',
          },
        ),
        _EmbeddingModelRow(
          key: ValueKey('embed-$_refresh'),
          onChanged: () => setState(() => _refresh++),
        ),
        _modelRow(
          key: ValueKey('en-$_refresh'),
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'English handwriting model',
          sizeLabel: '~20 MB',
          isInstalled: () => recognition.isModelDownloaded('en'),
          onDelete: () => recognition.deleteModel('en'),
          onDownload: () => recognition.ensureModelDownloaded('en'),
        ),
        _modelRow(
          key: ValueKey('bn-$_refresh'),
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'Bangla handwriting model',
          sizeLabel: '~20 MB',
          isInstalled: () => recognition.isModelDownloaded('bn'),
          onDelete: () => recognition.deleteModel('bn'),
          onDownload: () => recognition.ensureModelDownloaded('bn'),
        ),
        _modelRow(
          key: ValueKey('bn-Latn-$_refresh'),
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'Banglish handwriting model',
          sizeLabel: '~20 MB',
          isInstalled: () => recognition.isModelDownloaded('bn-Latn'),
          onDelete: () => recognition.deleteModel('bn-Latn'),
          onDownload: () => recognition.ensureModelDownloaded('bn-Latn'),
        ),
        _modelRow(
          key: ValueKey('speech-$_refresh-${speechPhase.name}'),
          icon: PhosphorIconsRegular.microphone,
          title: SpeechModelSpec.active.displayName,
          sizeLabel: '~80 MB',
          isInstalled: () => ref
              .read(speechModelInstallerProvider)
              .isInstalled(SpeechModelSpec.active),
          onDelete: () => ref.read(speechModelProvider.notifier).delete(),
          onDownload: _downloadWhisper,
        ),
        const _MobileDataRow(),
        const _RolloutRow(),
        if (kDebugMode) const _DryRunRow(),
        _ReclaimSpaceRow(
          key: ValueKey('reclaim-$_refresh'),
          onChanged: () => setState(() => _refresh++),
        ),
        // Debug builds only: the notes as the corpus tool/embedding_eval reads.
        if (kDebugMode)
          // A transparent Material gives the tile its ink over the card's own
          // background, which a bare ListTile refuses to paint over.
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              key: const ValueKey('export-rag-corpus'),
              title: const Text('Export RAG corpus'),
              subtitle: const Text('Debug build: notes for the embedding eval'),
              onTap: _exportCorpus,
            ),
          ),
      ],
    );
  }

  /// Downloads a model from its row. The row is the failsafe for a model that
  /// was meant to arrive on first use and did not, so it works for every model
  /// that is not installed. Failures are shown, and the button stays.
  Future<void> _downloadModel(
    String title,
    Future<void> Function() download, {
    Stream<int>? progress,
  }) async {
    final sub = progress?.listen((p) {
      if (mounted) {
        setState(() {
          _percent[title] = p;
        });
      }
    });
    setState(() {
      _downloading.add(title);
      _percent.remove(title);
    });
    String? failure;
    try {
      await download();
    } on LlmException catch (e) {
      failure = e.message;
    } catch (_) {
      failure = "Couldn't download $title. Check your connection and try again.";
    }
    unawaited(sub?.cancel());
    if (!mounted) return;
    setState(() {
      _downloading.remove(title);
      _percent.remove(title);
      _refresh++;
    });
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  /// The speech notifier reports a failed download as a state, not an error, so
  /// it is raised here for the row to show.
  Future<void> _downloadWhisper() async {
    await ref.read(speechModelProvider.notifier).download();
    if (ref.read(speechModelProvider).phase == SpeechModelPhase.failed) {
      throw StateError('the speech model did not download');
    }
  }

  Widget _modelRow({
    required Key key,
    required IconData icon,
    required String title,
    required String sizeLabel,
    required Future<bool> Function() isInstalled,
    required Future<void> Function() onDelete,
    required Future<void> Function() onDownload,
    Stream<int>? progress,
    bool confirmDelete = false,
    String? detail,
  }) {
    return FutureBuilder<bool>(
      key: key,
      future: isInstalled(),
      builder: (context, snapshot) {
        final installed = snapshot.data ?? false;
        final checking = !snapshot.hasData && !snapshot.hasError;
        final downloading = _downloading.contains(title);
        final percent = _percent[title];
        final String subtitle;
        if (checking) {
          subtitle = 'Checking…';
        } else if (installed) {
          subtitle =
              '$sizeLabel · Downloaded${detail == null ? '' : ' · $detail'}';
        } else if (downloading) {
          subtitle =
              percent == null ? 'Downloading…' : 'Downloading… $percent%';
        } else {
          subtitle = 'Not downloaded — fetched on first use';
        }
        final Widget? trailing;
        if (installed) {
          trailing = IconButton(
            icon: Icon(PhosphorIconsRegular.trash,
                color: context.colors.textSecondary),
            tooltip: 'Delete model',
            onPressed: () => _delete(onDelete, confirmDelete, title),
          );
        } else if (checking) {
          trailing = null;
        } else if (downloading) {
          trailing = const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else {
          trailing = TextButton(
            key: ValueKey('download-$title'),
            onPressed: () =>
                _downloadModel(title, onDownload, progress: progress),
            child: Text('Download',
                style: TextStyle(color: context.colors.accent)),
          );
        }
        return _SettingsRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
        );
      },
    );
  }

  Future<void> _delete(
      Future<void> Function() onDelete, bool confirm, String title) async {
    if (confirm) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete model?'),
          content: Text(
              '$title will be removed from this device. It will need to be '
              'downloaded again to use AI features offline.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete',
                  style: TextStyle(color: context.ink.accentRed)),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    try {
      await onDelete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Couldn't delete $title. Try again.")));
      }
    }
    if (mounted) setState(() => _refresh++);
  }
}

/// The embedding model row. Unlike the fetch-on-first-use rows above, this
/// model is gated and large, so its download is explicit: a button when a token
/// is set, guidance to add one when it isn't, live progress while running, and
/// a delete once installed.
class _EmbeddingModelRow extends ConsumerStatefulWidget {
  /// Called after a state change (download finished, deleted) so the parent can
  /// re-query every model row's install status.
  final VoidCallback onChanged;

  const _EmbeddingModelRow({super.key, required this.onChanged});

  @override
  ConsumerState<_EmbeddingModelRow> createState() => _EmbeddingModelRowState();
}

/// What is actually on disk for the embedding model.
enum _InstallState {
  /// Both files present — ready to use.
  installed,

  /// Exactly one file present, left by a failed attempt. Costs real space
  /// (the model file is ~171 MB of the ~175 MB pair) while being unusable.
  partial,

  /// Nothing downloaded.
  absent,
}

class _EmbeddingModelRowState extends ConsumerState<_EmbeddingModelRow>
    with WidgetsBindingObserver {
  int? _progress; // non-null while downloading

  /// The typed failure, not just its text, so `build` can offer the fix that
  /// matches it — a licence problem needs a link to HuggingFace, a dead token
  /// needs the Change button above.
  LlmException? _failure;

  /// Set while the user is away accepting the licence in a browser. Their
  /// return is the signal to re-check: without this the app would sit on a
  /// stale error until they thought to press Retry, which is exactly the
  /// friction the browser hand-off was meant to remove.
  bool _awaitingLicence = false;

  static const _spec = EmbedderSpec.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingLicence) return;
    _awaitingLicence = false;
    _resumeAfterLicence();
  }

  /// Re-asks HuggingFace whether access was granted, and just carries on if it
  /// was. `gated: auto` repos grant access the moment the form is submitted,
  /// so by the time the Custom Tab is dismissed this usually succeeds.
  Future<void> _resumeAfterLicence() async {
    if (!mounted) return;
    setState(() => _failure = null);
    // download() re-runs the same preflight probe, so a still-unaccepted
    // licence lands back on the licence error rather than starting a doomed
    // 185 MB transfer.
    await _download();
  }

  /// Held in state rather than created inside `build`.
  ///
  /// These are platform-channel round trips behind plugin initialization.
  /// Building the future inline meant every rebuild — each progress tick,
  /// theme change, or parent `setState` — fired a fresh one and snapped the
  /// row back to "Checking…" while it resolved. It is recomputed only when
  /// something can actually have changed the answer.
  late Future<_InstallState> _installedCheck = _checkInstalled();

  Future<_InstallState> _checkInstalled() async {
    final manager = ref.read(embedderDownloadManagerProvider);
    if (await manager.isInstalled()) return _InstallState.installed;
    if (await manager.isPartiallyInstalled()) return _InstallState.partial;
    return _InstallState.absent;
  }

  // A block, not an arrow: the arrow would return the assigned Future, which
  // setState refuses, so the row would keep its old state.
  void _refreshInstalled() {
    setState(() {
      _installedCheck = _checkInstalled();
    });
  }

  Future<void> _download() async {
    final manager = ref.read(embedderDownloadManagerProvider);
    setState(() {
      _progress = 0;
      _failure = null;
    });
    final sub = manager.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    try {
      await manager.download();
      if (mounted) widget.onChanged(); // flips the row to "Downloaded"
    } on LlmException catch (e) {
      // Every typed download failure — auth, licence, rate limit, storage,
      // network — already carries a message written for the user, so one arm
      // covers them all. See `download_failure.dart`.
      _fail(e);
    } finally {
      await sub.cancel();
      if (mounted) {
        setState(() => _progress = null);
        // A failed download can still have landed one of the two files; re-ask
        // rather than assuming the row's state is unchanged.
        _refreshInstalled();
      }
    }
  }

  void _fail(LlmException failure) {
    if (mounted) setState(() => _failure = failure);
  }

  /// Hands the user to HuggingFace to accept the licence, then waits for them
  /// to come back (see [didChangeAppLifecycleState]).
  Future<void> _acceptLicence(String url) async {
    // Armed before launching, not after: the app can be backgrounded the
    // instant the Custom Tab appears, and a flag set afterwards could miss the
    // resume entirely.
    _awaitingLicence = true;
    final opened = await openExternalUrl(url);
    if (opened) return;
    _awaitingLicence = false;
    if (!mounted) return;
    await _openHuggingFace(context, url); // shows the copyable fallback
  }

  Future<void> _delete() async {
    try {
      await ref.read(embedderDownloadManagerProvider).delete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't delete the search model. Try again.")));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _failure = null);
    _refreshInstalled();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = _spec.approxSizeBytes / (1024 * 1024);
    final sizeLabel = '${sizeMb.round()} MB';
    // The effective token, so a local dev token (debug only) also enables the
    // download — not just a token typed into Settings.
    final hasToken = ref.watch(huggingFaceTokenProvider).isNotEmpty;
    // Settings load from SharedPreferences asynchronously. Until that lands the
    // token reads as '' even when one is stored, so treat "not loaded yet" as
    // unknown rather than as "no token" — otherwise the row briefly tells a
    // user who HAS a token to go add one, and disables the button under them.
    final settingsLoaded = ref.watch(settingsProvider).loaded;

    if (_progress != null) {
      return _SettingsRow(
        icon: PhosphorIconsRegular.magnifyingGlass,
        title: '${_spec.displayName} (search)',
        subtitle: 'Downloading… $_progress%',
        trailing: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: (_progress! > 0) ? _progress! / 100 : null,
          ),
        ),
      );
    }

    return FutureBuilder<_InstallState>(
      future: _installedCheck,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _InstallState.absent;
        final checking =
            !settingsLoaded || (!snapshot.hasData && !snapshot.hasError);
        final installed = state == _InstallState.installed;
        final partial = state == _InstallState.partial;

        // A gated-model failure the user can fix in one tap, rather than by
        // re-examining a token that is usually fine.
        final licenceUrl = switch (_failure) {
          ModelLicenceNotAcceptedException(:final modelPageUrl) => modelPageUrl,
          ModelTokenScopeException(:final modelPageUrl) => modelPageUrl,
          _ => null,
        };

        final String subtitle;
        if (_failure != null) {
          subtitle = _failure!.message;
        } else if (checking) {
          subtitle = 'Checking…';
        } else if (installed) {
          subtitle = '$sizeLabel · Downloaded';
        } else if (partial) {
          // Say the space is recoverable, because nothing else in the UI would
          // reveal that a failed attempt is still holding most of it.
          subtitle = 'Download incomplete — finish it, or delete to free space';
        } else if (!hasToken) {
          subtitle = 'Add a HuggingFace token above to download';
        } else {
          subtitle = '$sizeLabel · Powers semantic search across your notes';
        }

        return _SettingsRow(
          icon: PhosphorIconsRegular.magnifyingGlass,
          title: '${_spec.displayName} (search)',
          subtitle: subtitle,
          trailing: installed
              ? IconButton(
                  icon: Icon(PhosphorIconsRegular.trash,
                      color: context.colors.textSecondary),
                  tooltip: 'Delete model',
                  onPressed: _delete,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A half-finished attempt is the only not-installed state
                    // that occupies space, so it is the only one that also
                    // gets a delete.
                    if (partial && !checking)
                      IconButton(
                        icon: Icon(PhosphorIconsRegular.trash,
                            color: context.colors.textSecondary),
                        tooltip: 'Delete partial download',
                        onPressed: _delete,
                      ),
                    // Leads, because when it is shown it is the ONLY thing
                    // that unblocks the download — retrying without accepting
                    // the licence just reproduces the same error.
                    if (licenceUrl != null)
                      TextButton(
                        onPressed: () => _acceptLicence(licenceUrl),
                        child: Text(
                          _failure is ModelTokenScopeException
                              ? 'Fix token'
                              : 'Accept licence',
                          style: TextStyle(color: context.colors.accent),
                        ),
                      ),
                    TextButton(
                      key: ValueKey('download-${_spec.displayName} (search)'),
                      // Disabled only once we KNOW there is no token — a
                      // pending settings load must not look like a missing one.
                      onPressed:
                          (hasToken && settingsLoaded) ? _download : null,
                      child: Text(
                        (_failure != null || partial) ? 'Retry' : 'Download',
                        style: TextStyle(
                          // Disabled must read as disabled in BOTH modes: the
                          // enabled accent against `textSecondary` at 40%.
                          color: (hasToken && settingsLoaded)
                              ? context.colors.accent
                              : context.colors.textSecondary
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
