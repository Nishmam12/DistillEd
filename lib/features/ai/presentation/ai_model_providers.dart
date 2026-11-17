part of 'ai_providers.dart';

// The model list, the student's pick, and the provider that answers with it.
// See docs/AI_TUTOR_PLAN.md part 1 for the design these implement.

/// Reads and writes the student's own cloud connections.
final userConnectionStoreProvider = Provider<UserConnectionStore>(
  (ref) => UserConnectionStore(secrets: ref.watch(secretStoreProvider)),
);

/// The cloud AIs the student has added with their own keys.
final userConnectionsProvider =
    StateNotifierProvider<UserConnectionsNotifier, List<UserConnection>>(
      (ref) => UserConnectionsNotifier(ref.watch(userConnectionStoreProvider)),
    );

/// Checks a key the student has just typed and lists the models it can use.
final modelConnectionTesterProvider = Provider<ModelConnectionTester>(
  (ref) => ModelConnectionTester(),
);

/// Margo's own cloud models remain unavailable. The old gateway was removed.
final margoCatalogProvider = Provider<List<AiModelEntry>>(
  (ref) => kBundledMargoCatalog,
);

/// The default cloud connection also appears in the answer picker. It remains
/// separate from answer-only connections because it may read pages in the
/// background when the processing mode and privacy setting allow that.
final defaultCloudModelProvider = Provider<AiModelEntry?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.hasCloudKey) return null;
  final cloud = ref.watch(cloudAiProvider);
  return AiModelEntry(
    id: 'default:${cloud.capabilities.modelId}',
    displayName:
        '${cloudProviderName(presetId: settings.cloudPresetId, baseUrl: settings.cloudBaseUrl)} · ${settings.cloudModel}',
    source: ModelSource.userKey,
    contextWindowTokens: cloud.capabilities.contextWindowTokens,
    supportsTools: true,
    supportsVision: true,
    host: Uri.tryParse(settings.cloudBaseUrl)?.host,
  );
});

/// Cloud permission for answers can use either a default connection or an
/// answer-only connection. Background reads still require the default key.
final hasAnswerCloudKeyProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.hasCloudKey)) ||
      ref.watch(userConnectionsProvider).any((c) => c.models.isNotEmpty),
);

final answerCloudEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.aiMode.allowsCloud)) &&
      ref.watch(hasAnswerCloudKeyProvider),
);

/// Every cloud model that can be shown in the picker: Margo's, then one row per
/// model of each connection the student added. The on-device model and "Auto"
/// are not entries; they are the two fixed choices above the list.
final modelCatalogueProvider = Provider<List<AiModelEntry>>(
  (ref) => [
    ...ref.watch(margoCatalogProvider),
    ?ref.watch(defaultCloudModelProvider),
    for (final connection in ref.watch(userConnectionsProvider))
      ...connection.entries,
  ],
);

/// Who answers the next thing the student asks.
///
/// A function, read at call time: the cloud switch, the privacy setting, the
/// pick and the list of connections can each change between two questions, and
/// the next question must see the change.
final answerRouteProvider = Provider<AnswerRoute Function()>(
  (ref) => () {
    final settings = ref.read(settingsProvider);
    final defaultModel = ref.read(defaultCloudModelProvider);
    if (settings.answerModelId == kAnswerAuto &&
        settings.prefersCloud &&
        settings.cloudPrivacy != CloudPrivacy.localOnly &&
        defaultModel != null) {
      return CloudDirect(defaultModel);
    }
    return resolveAnswerRoute(
      aiMode: settings.aiMode,
      privacy: settings.cloudPrivacy,
      answerModelId: settings.answerModelId,
      catalogue: ref.read(modelCatalogueProvider),
    );
  },
);

/// The provider for one of the student's own models, kept so its connection is
/// reused from one question to the next. Null when [entryId] no longer names a
/// model of a saved connection.
final userModelProviderFamily =
    Provider.family<OpenAiCompatibleProvider?, String>((ref, entryId) {
      final target = UserModelRef.parse(entryId);
      if (target == null) return null;
      for (final connection in ref.watch(userConnectionsProvider)) {
        if (connection.id != target.connectionId) continue;
        for (final model in connection.models) {
          if (model.modelId != target.modelId) continue;
          return OpenAiCompatibleProvider.connection(
            baseUrl: connection.baseUrl,
            modelId: model.modelId,
            displayName: '${connection.label} · ${model.displayName}',
            label: connection.label,
            contextWindowTokens: model.contextWindowTokens,
            // Read when a request is made, so a replaced key is used at once.
            apiKey: () => ref
                .read(userConnectionsProvider.notifier)
                .keyFor(connection.id),
            isCloudAllowed: () => _mayUseAnswerCloud(ref),
          );
        }
      }
      return null;
    });

/// Stands in for a model that vanished between being picked and being asked.
class _GoneModelProvider implements AiProvider {
  const _GoneModelProvider();

  @override
  AiCapabilities get capabilities => const AiCapabilities(
    modelId: 'gone',
    displayName: 'Unavailable model',
    contextWindowTokens: kUnknownModelWindowTokens,
  );

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) => Stream.error(
    const AiUnavailableException(
      'That model is no longer available. Pick another one.',
    ),
  );
}

/// Turns a catalogue entry into the provider that reaches it. A provider of its
/// own so tests can answer with a fake instead of the network.
final cloudProviderForProvider = Provider<AiProvider Function(AiModelEntry)>(
  (ref) =>
      (entry) => switch (entry.source) {
        ModelSource.userKey =>
          entry.id == ref.read(defaultCloudModelProvider)?.id
              ? ref.read(cloudAiProvider)
              : ref.read(userModelProviderFamily(entry.id)) ??
                    const _GoneModelProvider(),
        ModelSource.margo => const _GoneModelProvider(),
        ModelSource.onDevice => ref.read(localAiProvider),
      },
);

/// The [AiProvider] for features that answer the student: the on-device model,
/// or the cloud model they picked. Decided per call, so a new pick takes effect
/// on the next question.
///
/// Not for background work. Page analysis, page reading and writing
/// suggestions run without the student asking, so they keep their own wiring
/// and never reach a model the student is paying for.
final answerAiProvider = Provider<AiProvider>(
  (ref) => SelectedAnswerProvider(
    local: ref.watch(localAiProvider),
    route: ref.watch(answerRouteProvider),
    cloudFor: ref.watch(cloudProviderForProvider),
  ),
);

/// Whether Margo's own cloud can answer right now. Currently unavailable.
final margoCloudAvailableProvider = Provider<bool>(
  (ref) => ref.watch(margoCatalogProvider).any((entry) => entry.pickable),
);

/// The model Research talks to, decided per question.
///
/// Research needs a model that can call tools. A cloud model the student picked
/// is used when it can; when it cannot, Research says so instead of quietly
/// sending the question to a different service. With nothing picked it uses
/// the default cloud connection, after Research's confirmation.
class _PickedToolsClient implements ToolCallingClient {
  final AnswerRoute Function() _route;
  final AiProvider Function(AiModelEntry) _cloudFor;
  final ToolCallingClient _defaultCloud;

  const _PickedToolsClient(this._route, this._cloudFor, this._defaultCloud);

  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
  }) {
    final route = _route();
    if (route is LocalOnly) {
      return Stream.error(
        const AiUnavailableException(
          'Research needs a cloud model. Pick one or enable cloud AI in Settings.',
        ),
      );
    }
    if (route is! CloudDirect) {
      return _defaultCloud.generateWithTools(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
      );
    }
    final provider = _cloudFor(route.model);
    if (!route.model.supportsTools || provider is! ToolCallingClient) {
      return Stream.error(
        AiUnavailableException(
          "${route.model.displayName} can't use tools, which Research needs. "
          'Pick another model for Research.',
        ),
      );
    }
    return (provider as ToolCallingClient).generateWithTools(
      prompt: prompt,
      systemPrompt: systemPrompt,
      history: history,
      tools: tools,
    );
  }
}

/// Whether the model that would answer now can call tools.
final answerSupportsToolsProvider = Provider<bool Function()>(
  (ref) =>
      () => switch (ref.read(answerRouteProvider)()) {
        CloudDirect(:final model) => model.supportsTools,
        LocalOnly() || LocalFirst() => false,
      },
);

/// For a feature about to send a page to [answerAiProvider]: yes at once when
/// the on-device model answers, and the "send this?" question when a cloud
/// model is picked. Called once per thing the student asks for.
final confirmAnswerSendProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final route = ref.read(answerRouteProvider)();
    if (route is! CloudDirect) return true;
    return ref.read(cloudSendGateProvider.notifier).confirm(route.model);
  },
);

/// Asks the student before text is sent to a model they picked. See
/// `cloud_send_gate.dart`.
final cloudSendGateProvider =
    StateNotifierProvider<CloudSendGate, CloudSendPrompt?>(
      (ref) => CloudSendGate(
        privacy: () => ref.read(settingsProvider).cloudPrivacy,
        hasSeenFirstCloudCall: () =>
            ref.read(settingsProvider).hasSeenFirstCloudCall,
        // Margo's own models are covered by the first-cloud-call explanation;
        // each connection the student adds is a different company, so each is
        // explained once.
        hasConsentedTo: (model) {
          final target = UserModelRef.parse(model.id);
          if (target == null) return true;
          for (final connection in ref.read(userConnectionsProvider)) {
            if (connection.id == target.connectionId) {
              return connection.consentShown;
            }
          }
          return false;
        },
        markConsented: (model) async {
          await ref.read(settingsProvider.notifier).markFirstCloudCallSeen();
          final target = UserModelRef.parse(model.id);
          if (target != null) {
            await ref
                .read(userConnectionsProvider.notifier)
                .markConsented(target.connectionId);
          }
        },
      ),
    );
