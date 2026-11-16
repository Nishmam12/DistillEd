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

/// Margo's own cloud models. All "coming soon" until the gateway serves a
/// catalogue.
final margoCatalogProvider = Provider<List<AiModelEntry>>(
  (ref) => kBundledMargoCatalog,
);

/// Every cloud model that can be shown in the picker: Margo's, then one row per
/// model of each connection the student added. The on-device model and "Auto"
/// are not entries; they are the two fixed choices above the list.
final modelCatalogueProvider = Provider<List<AiModelEntry>>(
  (ref) => [
    ...ref.watch(margoCatalogProvider),
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
          return OpenAiCompatibleProvider(
            baseUrl: connection.baseUrl,
            modelId: model.modelId,
            displayName: '${connection.label} · ${model.displayName}',
            label: connection.label,
            contextWindowTokens: model.contextWindowTokens,
            // Read when a request is made, so a replaced key is used at once.
            apiKey: () => ref
                .read(userConnectionsProvider.notifier)
                .keyFor(connection.id),
            isCloudAllowed: () => _mayUseCloud(ref),
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
  (ref) => (entry) => switch (entry.source) {
    ModelSource.userKey =>
      ref.read(userModelProviderFamily(entry.id)) ?? const _GoneModelProvider(),
    // One gateway tier until the gateway serves a catalogue of its own.
    ModelSource.margo => ref.read(cloudGatewayMidProvider),
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

/// Whether the model that would answer now can call tools.
final answerSupportsToolsProvider = Provider<bool Function()>(
  (ref) => () => switch (ref.read(answerRouteProvider)()) {
    CloudDirect(:final model) => model.supportsTools,
    LocalOnly() || LocalFirst() => false,
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
