// Automatic model routing — the user never picks a model (locked decision #1).
//
// Decision table (locked decision #6):
//   offline                                → local Gemma
//   offline + local model not downloaded   → actionable error state
//   online + cloud enabled + input longer
//     than the local context budget        → cloud client
//   online, anything else                  → local Gemma
//     (model not downloaded yet            → download-then-local)
//
// Input that exceeds the local budget but still routes local (cloud off,
// offline, or cloud fallback) is truncated by the summarization service; the
// [truncateForLocal] flag signals that.

import 'dart:async';
import 'dart:io';

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
  /// Run on-device Gemma.
  local,

  /// Send to the cloud client (only: online + opt-in + over local budget).
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
  /// Local input budget in WORDS. The local context window is 4096 tokens;
  /// minus prompt scaffolding and a 512-token response reserve, ~3400 tokens
  /// remain for input ≈ 2500 English words (~1.35 tokens/word).
  static const int localInputWordBudget = 2500;

  final Reachability _reachability;
  final Future<bool> Function() _isLocalModelInstalled;

  AiRouter({
    required Future<bool> Function() isLocalModelInstalled,
    Reachability reachability = const Reachability(),
  })  : _isLocalModelInstalled = isLocalModelInstalled,
        _reachability = reachability;

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
