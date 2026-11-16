// The question the student sees before their text goes to a cloud model they
// picked: which model, and whose servers.
//
// `CloudSendGate` holds the question; this shows it. A screen that can start
// such a send calls [showCloudSendPrompts] from its `build`, and from then on a
// pending question appears as a dialog over it. Anything that is not a clear
// "Send" — the other button, a tap outside, the back gesture — is a no.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai_providers.dart';
import '../cloud_send_gate.dart';

/// Shows a dialog whenever a send is waiting for the student's answer. Call
/// from the `build` of a screen that hosts AI features.
void showCloudSendPrompts(BuildContext context, WidgetRef ref) {
  ref.listen<CloudSendPrompt?>(cloudSendGateProvider, (previous, next) async {
    if (next == null || previous != null) return;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (_) => _CloudSendDialog(prompt: next),
    );
    ref.read(cloudSendGateProvider.notifier).answer(allowed ?? false);
  });
}

class _CloudSendDialog extends ConsumerStatefulWidget {
  final CloudSendPrompt prompt;
  const _CloudSendDialog({required this.prompt});

  @override
  ConsumerState<_CloudSendDialog> createState() => _CloudSendDialogState();
}

class _CloudSendDialogState extends ConsumerState<_CloudSendDialog> {
  // Closing answers the gate, which clears the question, which this dialog also
  // listens for. Without the flag that second signal would pop the screen
  // underneath.
  bool _closed = false;

  void _close(bool allow) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(allow);
  }

  @override
  Widget build(BuildContext context) {
    // The gate gives up on a question nobody answers; take the dialog down
    // with it rather than leave a button that no longer does anything.
    ref.listen<CloudSendPrompt?>(cloudSendGateProvider, (_, next) {
      if (next == null) _close(false);
    });

    final prompt = widget.prompt;
    final destination = prompt.host.isEmpty
        ? 'a cloud service'
        : prompt.host;
    return AlertDialog(
      title: Text('Send this to ${prompt.modelName}?'),
      content: Text(
        prompt.firstEver
            ? 'Your question and the parts of your notes it needs will go to '
                '$destination to be answered. That text leaves this device. '
                'Everything else stays here, and you can switch cloud AI off '
                'at any time.'
            : 'Your question and the parts of your notes it needs will go to '
                '$destination.',
      ),
      actions: [
        TextButton(
          onPressed: () => _close(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => _close(true),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
