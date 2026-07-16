// Automatic tier routing — the user never picks a model.
//
// Generalization of the summarize feature's original router onto the AI
// platform: the local input budget now derives from the local provider's
// [AiCapabilities] instead of a hard-coded constant, so swapping the on-device
// model (bigger context window, different tier) re-budgets every feature
// automatically. The decision table is unchanged:
//
//   offline                                → local
//   offline + local model not downloaded   → actionable error state
//   online + cloud opt-in + input longer
//     than the local budget                → cloud tier
//   online, anything else                  → local
//     (model not downloaded yet            → download-then-local)
//
// Input that exceeds the local budget but still routes local (cloud off,
// offline, or cloud fallback) is truncated by the caller; [truncateForLocal]
// signals that. Privacy invariant: the cloud route requires BOTH the user's
// explicit opt-in and the note not fitting locally.

import 'dart:async';
import 'dart:io';

import 'ai_capabilities.dart';

/// Small reachability probe: can we resolve a well-known host right now?
/// (Airplane mode / no network fails in milliseconds; the timeout guards
/// against hanging resolvers. Captive portals may false-positive — acceptable
/// for a routing hint, the download/cloud layers handle real failures.)
class Reachability {
  final Duration timeout;
  const Reachability({this.timeout = const Duration(seconds: 2)});

  Future<bool> isOnline() async {
    try {
      final result =
          await InternetAddress.lookup('dns.google').timeout(timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}

enum AiRoute {
  /// Run the on-device provider.
  local,

  /// Send to the cloud tier (only: online + opt-in + over local budget).
  cloud,

  /// Local model missing but we're online — download it, then run locally.
  downloadThenLocal,

  /// Local model missing AND offline — nothing can run; show actionable error.
  errorOfflineNoModel,
}

class RoutingDecision {
  final AiRoute route;

  /// True when the input exceeds the local budget but the route is still
  /// local — the caller must truncate before prompting.
  final bool truncateForLocal;

  const RoutingDecision(this.route, {this.truncateForLocal = false});
}

class AiRouter {
  /// Tokens kept free for the model's response within the context window.
  static const int responseReserveTokens = 512;

  /// Tokens assumed consumed by prompt scaffolding (instruction, framing).
  static const int scaffoldingReserveTokens = 200;

  /// Rough English tokens-per-word ratio used to express the budget in words
  /// (callers count words, not tokens).
  static const double tokensPerWord = 1.35;

  /// Capabilities of the local tier — the budget source.
  final AiCapabilities localCapabilities;

  final Reachability _reachability;
  final Future<bool> Function() _isLocalModelInstalled;

  AiRouter({
    required this.localCapabilities,
    required Future<bool> Function() isLocalModelInstalled,
    Reachability reachability = const Reachability(),
  })  : _isLocalModelInstalled = isLocalModelInstalled,
        _reachability = reachability;

  /// Input budget in WORDS for a provider with [capabilities]: its context
  /// window minus the response and scaffolding reserves. Static so features
  /// that prompt a provider directly (e.g. the Context Engine) budget with
  /// the same math as the routing decision.
  static int inputWordBudgetFor(AiCapabilities capabilities) =>
      ((capabilities.contextWindowTokens -
                  responseReserveTokens -
                  scaffoldingReserveTokens) /
              tokensPerWord)
          .floor();

  /// Local input budget in WORDS, derived from the local context window minus
  /// the response and scaffolding reserves.
  int get localInputWordBudget => inputWordBudgetFor(localCapabilities);

  Future<RoutingDecision> decide({
    required int inputWordCount,
    required bool cloudEnabled,
  }) async {
    final online = await _reachability.isOnline();
    final tooLong = inputWordCount > localInputWordBudget;

    // Privacy default: cloud only when online, explicitly enabled, AND the
    // note doesn't fit the local budget.
    if (online && cloudEnabled && tooLong) {
      return const RoutingDecision(AiRoute.cloud);
    }

    final hasModel = await _isLocalModelInstalled();
    if (!hasModel) {
      return RoutingDecision(
        online ? AiRoute.downloadThenLocal : AiRoute.errorOfflineNoModel,
      );
    }

    return RoutingDecision(AiRoute.local, truncateForLocal: tooLong);
  }
}
