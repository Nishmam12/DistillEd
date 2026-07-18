// Task-type-based routing for Phase 3 — decides local vs. cloud-mid vs.
// cloud-frontier per request, then wraps that decision in an [AiProvider] so
// a feature's DI wiring is the only thing that changes to make it "routed".
//
// Distinct from the existing, simpler [AiRouter] (word-count-only, still
// serves Summarize's existing cloud path unchanged) — this one adds the task
// taxonomy and privacy gating the Phase 3 spec calls for, additively.

import 'dart:math';

import '../../../../core/providers/settings_provider.dart' show CloudPrivacy;
import '../ai_provider.dart';
import '../ai_router.dart' show AiRouter, Reachability;
import '../text_budget.dart';

export '../../../../core/providers/settings_provider.dart' show CloudPrivacy;

/// What kind of request this is, for routing purposes. Deliberately coarser
/// than any single feature's own vocabulary (e.g. Explain's [ExplainMode] is
/// about depth, not routing) — features map onto these categories.
enum TaskType {
  grammar,
  rewrite,
  explain,
  summarizePage,
  summarizeNotebook,
  research,
  thesisWriting,
  complexReasoning,
  largeCodebase,
}

enum CloudTier { mid, frontier }

/// Tasks that always warrant the frontier tier when privacy allows it,
/// regardless of length — per the phase spec's routing table.
const Set<TaskType> _frontierTasks = {
  TaskType.thesisWriting,
  TaskType.complexReasoning,
  TaskType.largeCodebase,
};

sealed class RouteTarget {
  const RouteTarget();
}

class RouteLocal extends RouteTarget {
  const RouteLocal();
}

class RouteCloud extends RouteTarget {
  final CloudTier tier;
  const RouteCloud(this.tier);
}

/// Decides [RouteTarget] for a request. Stateless and cheap other than the
/// [Reachability] probe — safe to call once per request.
class IntelligentRouter {
  final AiCapabilities localCapabilities;
  final Reachability _reachability;

  const IntelligentRouter({
    required this.localCapabilities,
    Reachability reachability = const Reachability(),
  }) : _reachability = reachability;

  /// Local input budget in words — same math as [AiRouter], so the two
  /// routers never disagree about what "fits locally" means.
  int get localInputWordBudget => AiRouter.inputWordBudgetFor(localCapabilities);

  Future<RouteTarget> decide({
    required TaskType task,
    required int inputWordCount,
    required CloudPrivacy privacy,
  }) async {
    if (_frontierTasks.contains(task)) {
      if (privacy == CloudPrivacy.localOnly) return const RouteLocal();
      if (!await _reachability.isOnline()) return const RouteLocal();
      return const RouteCloud(CloudTier.frontier);
    }

    if (inputWordCount <= localInputWordBudget) return const RouteLocal();

    // Over the local budget: only escape to cloud when privacy allows it and
    // we're actually online — otherwise the caller truncates and runs local
    // (the same "degrade gracefully" behavior as the existing [AiRouter]).
    if (privacy == CloudPrivacy.localOnly) return const RouteLocal();
    if (!await _reachability.isOnline()) return const RouteLocal();
    return const RouteCloud(CloudTier.mid);
  }
}

/// What a peeked route means for the UI: null (not returned; see
/// [RoutedAiProvider.peekRoute]) means "runs local, no confirmation needed".
class CloudRouteDecision {
  final CloudTier tier;
  const CloudRouteDecision(this.tier);
}

/// Wraps [IntelligentRouter] + three real providers as one [AiProvider], so a
/// feature's DI line is the only thing that changes to make it "routed" — the
/// feature itself (e.g. `Explainer`) is never aware routing exists.
///
/// [peekRoute] lets the *caller* (e.g. `ExplainNotifier`) ask what [generate]
/// would decide, before actually calling it — needed so the UI can pause for
/// a cloud-use confirmation ahead of the network call, per the spec's
/// "never silently send to cloud" rule. This can't live inside [generate]
/// itself: [AiProvider]'s contract only allows throwing the sealed
/// [AiException] hierarchy, which can't be extended from outside its own
/// file, and "pause for user confirmation" isn't a provider failure anyway.
class RoutedAiProvider implements AiProvider {
  final TaskType task;
  final IntelligentRouter router;
  final AiProvider local;
  final AiProvider cloudMid;
  final AiProvider cloudFrontier;
  final CloudPrivacy Function() privacy;

  const RoutedAiProvider({
    required this.task,
    required this.router,
    required this.local,
    required this.cloudMid,
    required this.cloudFrontier,
    required this.privacy,
  });

  @override
  AiCapabilities get capabilities => AiCapabilities(
        modelId: 'routed-${task.name}',
        displayName: 'Routed (${task.name})',
        // The LARGEST of the three tiers — deliberately not just local's.
        // Callers that truncate to this budget before calling (e.g.
        // `Explainer`) must not cut input down to local-size before the
        // router ever sees the real length; [generate] re-checks against
        // the local budget itself and truncates internally if it ends up
        // routing local.
        contextWindowTokens: [local, cloudMid, cloudFrontier]
            .map((p) => p.capabilities.contextWindowTokens)
            .reduce(max),
        supportsEmbeddings: local.capabilities.supportsEmbeddings,
        approxCostPerCallUsd: 0, // depends on the per-call decision
      );

  Future<RouteTarget> _decide(String prompt) => router.decide(
        task: task,
        inputWordCount: countWords(prompt),
        privacy: privacy(),
      );

  /// What [generate] would do for [prompt], without calling it. Null means
  /// "local — no cloud confirmation needed".
  Future<CloudRouteDecision?> peekRoute(String prompt) async {
    final target = await _decide(prompt);
    return switch (target) {
      RouteLocal() => null,
      RouteCloud(:final tier) => CloudRouteDecision(tier),
    };
  }

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    final target = await _decide(prompt);
    final chosen = switch (target) {
      RouteLocal() => local,
      RouteCloud(tier: CloudTier.mid) => cloudMid,
      RouteCloud(tier: CloudTier.frontier) => cloudFrontier,
    };

    final effectivePrompt = target is RouteLocal
        ? truncateToWords(prompt, router.localInputWordBudget)
        : prompt;

    yield* chosen.generate(
      prompt: effectivePrompt,
      systemPrompt: systemPrompt,
      history: history,
      options: options,
    );
  }

  @override
  Future<List<double>> embed(String text) => local.embed(text);
}
