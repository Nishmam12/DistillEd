// One row of the model list: a model the student can ask to answer with.
//
// The list has three sources — the on-device model, the cloud models Margo
// provides, and models reached with a key the student typed in — and this is
// the one shape all three take, so the picker and the routing never care which
// it is.

import 'package:flutter/foundation.dart' show immutable;

enum ModelSource { onDevice, margo, userKey }

/// Which of Margo's own tiers a [ModelSource.margo] entry belongs to.
enum MargoTier { free, budget, premium }

/// The stored answer-model choice meaning "on-device first, as before".
const String kAnswerAuto = 'auto';

/// The stored answer-model choice meaning "only ever the on-device model".
const String kAnswerLocal = 'local';

@immutable
class AiModelEntry {
  /// `margo:<id>` or `user:<connectionId>:<modelId>`. Stored as the answer
  /// model choice, so it must stay stable for a given model.
  final String id;
  final String displayName;
  final ModelSource source;
  final MargoTier? tier;

  /// Drives every prompt budget. An unknown model must be given a small one:
  /// a window guessed too large overflows the real one.
  final int contextWindowTokens;
  final bool supportsTools;
  final bool supportsVision;

  /// Listed, but not something this user can use yet (a paid tier).
  final bool locked;

  /// False when the model is listed but cannot answer right now.
  final bool available;

  /// Where text is sent, for the consent wording. Null for the on-device model.
  final String? host;

  const AiModelEntry({
    required this.id,
    required this.displayName,
    required this.source,
    required this.contextWindowTokens,
    this.tier,
    this.supportsTools = false,
    this.supportsVision = false,
    this.locked = false,
    this.available = true,
    this.host,
  });

  bool get pickable => available && !locked;

  static String userModelId(String connectionId, String modelId) =>
      'user:$connectionId:$modelId';
}

/// The connection and model a `user:…` entry id names.
@immutable
class UserModelRef {
  final String connectionId;
  final String modelId;
  const UserModelRef(this.connectionId, this.modelId);

  /// Null when [entryId] is not a user model's id. A model id may itself hold
  /// colons (`org/model:free`), so only the first two are separators.
  static UserModelRef? parse(String entryId) {
    const prefix = 'user:';
    if (!entryId.startsWith(prefix)) return null;
    final rest = entryId.substring(prefix.length);
    final split = rest.indexOf(':');
    if (split <= 0 || split == rest.length - 1) return null;
    return UserModelRef(rest.substring(0, split), rest.substring(split + 1));
  }
}
