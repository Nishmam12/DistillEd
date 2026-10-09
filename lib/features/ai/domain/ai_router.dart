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
//   online + cloud opt-in + local model
//     fell back to the CPU (several times
//     slower)                              → cloud tier
//   online, anything else                  → local
//     (model not downloaded yet            → download-then-local)
//
// Input that exceeds the local budget but still routes local (cloud off,
// offline, or cloud fallback) is truncated by the caller; [truncateForLocal]
// signals that. Privacy invariant: the cloud route requires the user's explicit
// opt-in AND a reason local can't serve the request well — the note not fitting,
// or the on-device model running on the CPU. Slow never overrides the opt-in.

import 'dart:async';
import 'dart:io';

import 'ai_capabilities.dart';
import 'text_budget.dart' show kLatinTokensPerWord;

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
  static const double tokensPerWord = kLatinTokensPerWord;

  /// Capabilities of the local tier — the budget source.
  final AiCapabilities localCapabilities;

  final Reachability _reachability;
  final Future<bool> Function() _isLocalModelInstalled;

  /// Whether the on-device model has fallen back to the CPU. Read per decision,
  /// because it is only learned when the model first loads.
  final bool Function() _isLocalDegraded;

  AiRouter({
    required this.localCapabilities,
    required this._isLocalModelInstalled,
    this._reachability = const Reachability(),
    this._isLocalDegraded = _notDegraded,
  });

  static bool _notDegraded() => false;

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
    bool preferCloud = false,
  }) async {
    final online = await _reachability.isOnline();
    final tooLong = inputWordCount > localInputWordBudget;

    // Cloud-first: the user asked for the cloud to do the work, so length is
    // irrelevant. Still gated on [cloudEnabled] (belt and braces — the mode
    // that sets this also permits cloud) and on actually being online: offline
    // falls through to the local path below rather than failing the call.
    if (online && cloudEnabled && preferCloud) {
      return const RoutingDecision(AiRoute.cloud);
    }

    // Privacy default: cloud only when online, explicitly enabled, AND local
    // can't serve it well — the note doesn't fit the budget, or the model has
    // fallen back to the CPU and would take several times as long.
    if (online && cloudEnabled && (tooLong || _isLocalDegraded())) {
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
