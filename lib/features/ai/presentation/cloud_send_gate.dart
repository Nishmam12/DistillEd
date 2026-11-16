// Asks the student, once, before their text is sent to a cloud model they
// picked.
//
// A notifier starting a piece of work calls [CloudSendGate.confirm] and waits.
// When no question is needed the answer is an immediate yes. When one is, the
// gate's state becomes the question; whatever is on screen shows it and calls
// [CloudSendGate.answer]. Keeping the question here, rather than as one more
// state in each of Ask, Summarize, quiz and flashcards, means there is one
// wording and one rule for all of them.
//
// A send that is not confirmed does not happen: no answer within the timeout,
// or a second request while a question is already up, both count as no.

import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/providers/settings_provider.dart' show CloudPrivacy;
import '../domain/catalog/ai_model_entry.dart';
import '../domain/catalog/cloud_consent.dart';

/// The question being asked.
class CloudSendPrompt {
  final String modelName;

  /// Where the text would go.
  final String host;

  /// The app's very first cloud call: show the longer explanation.
  final bool firstEver;

  const CloudSendPrompt({
    required this.modelName,
    required this.host,
    required this.firstEver,
  });
}

class CloudSendGate extends StateNotifier<CloudSendPrompt?> {
  final CloudPrivacy Function() _privacy;
  final bool Function() _hasSeenFirstCloudCall;
  final bool Function(AiModelEntry model) _hasConsentedTo;
  final Future<void> Function(AiModelEntry model) _markConsented;
  final Duration _timeout;

  /// Every setting is read when [confirm] is called, never captured, so a
  /// change in Settings applies to the next send.
  CloudSendGate({
    required this._privacy,
    required this._hasSeenFirstCloudCall,
    required this._hasConsentedTo,
    required this._markConsented,
    this._timeout = const Duration(seconds: 60),
  }) : super(null);

  Completer<bool>? _pending;

  /// Whether sending to [model] has to wait for a yes. For a surface that
  /// shows its own question (Explain's panel) instead of this gate's dialog.
  bool needsConfirmation(AiModelEntry model) => needsSendConfirmation(
        privacy: _privacy(),
        firstEverCloudCall: !_hasSeenFirstCloudCall(),
        firstUseOfModel: !_hasConsentedTo(model),
      );

  /// Records a yes that was given somewhere other than this gate's dialog.
  Future<void> markConsented(AiModelEntry model) => _markConsented(model);

  /// True when text may be sent to [model] for the work about to start.
  Future<bool> confirm(AiModelEntry model) async {
    final firstEver = !_hasSeenFirstCloudCall();
    if (!needsConfirmation(model)) return true;
    // One question at a time. A second piece of work starting meanwhile is not
    // sent, rather than riding on an answer given about something else.
    if (_pending != null) return false;

    final pending = _pending = Completer<bool>();
    state = CloudSendPrompt(
      modelName: model.displayName,
      host: model.host ?? '',
      firstEver: firstEver,
    );
    final allowed = await pending.future.timeout(
      _timeout,
      onTimeout: () => false,
    );
    _pending = null;
    if (mounted) state = null;
    if (allowed) await _markConsented(model);
    return allowed;
  }

  /// The student's answer to the question showing. Does nothing when there is
  /// none.
  void answer(bool allow) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    pending.complete(allow);
  }
}
