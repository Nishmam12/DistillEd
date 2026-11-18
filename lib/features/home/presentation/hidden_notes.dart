// Hidden notes (docs/COMPETITOR_UPGRADE_PLAN.md, Phase 6, "note lock — hide").
//
// A hidden notebook stays on the device as it was, not encrypted, but it is
// kept out of the notes list, search, the link picker, previews and cloud
// calls, and it opens only after the device's fingerprint or screen lock. One
// unlock opens the Hidden view for as long as Margo stays in front; leaving
// the app locks it again. The interface says "hidden", never "encrypted".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import 'home_notifier.dart';

/// Whether hidden notes are unlocked right now. Reset when the app leaves the
/// foreground (see `app.dart`).
final hiddenUnlockedProvider = StateProvider<bool>((ref) => false);

/// Locks hidden notes again whenever Margo leaves the foreground, and keeps
/// an open hidden note out of screenshots. Read once
/// from `app.dart`. The device's own lock prompt pauses the app too, but the
/// unlock lands after it returns, so it is not undone.
final hiddenRelockProvider = Provider<void>((ref) {
  final listener = AppLifecycleListener(
    onPause: () {
      ref.read(hiddenUnlockedProvider.notifier).state = false;
      ref.read(notesHiddenViewProvider.notifier).state = false;
    },
  );
  ref.onDispose(listener.dispose);
  // While a hidden note is open the window is kept out of screenshots and the
  // recents thumbnail.
  ref.listen<Set<int>>(openHiddenNotebooksProvider, (was, open) {
    if ((was?.isNotEmpty ?? false) == open.isNotEmpty) return;
    const MethodChannel('com.margo.margo/secure')
        .invokeMethod<void>('set', open.isNotEmpty)
        .catchError((Object _) {}); // not Android, or a test: nothing to do
  });
});

/// Home shows the Hidden view (only hidden notes) instead of the notes list.
final notesHiddenViewProvider = StateProvider<bool>((ref) => false);

/// The ids of every hidden live notebook.
final hiddenNotebookIdsProvider = Provider<Set<int>>(
  (ref) => {
    for (final n in ref.watch(homeNotifierProvider))
      if (n.hidden) n.id,
  },
);

enum DeviceAuthResult { unlocked, cancelled, noScreenLock }

/// Asks the device for the owner's fingerprint, face or screen lock. A seam
/// so tests can answer without a device.
final deviceAuthProvider =
    Provider<Future<DeviceAuthResult> Function(String reason)>(
      (ref) => _deviceAuth,
    );

Future<DeviceAuthResult> _deviceAuth(String reason) async {
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) return DeviceAuthResult.noScreenLock;
    return await auth.authenticate(
          localizedReason: reason,
          persistAcrossBackgrounding: true,
        )
        ? DeviceAuthResult.unlocked
        : DeviceAuthResult.cancelled;
  } on LocalAuthException catch (e) {
    return e.code == LocalAuthExceptionCode.noCredentialsSet
        ? DeviceAuthResult.noScreenLock
        : DeviceAuthResult.cancelled;
  }
}

Future<DeviceAuthResult>? _asking;

const _noScreenLock = 'Set a screen lock on this device to use hidden notes.';

/// Unlocks hidden notes, asking the device first unless they already are.
/// True when unlocked; on a refusal says why in a snack bar.
Future<bool> unlockHidden(BuildContext context, WidgetRef ref) async {
  if (ref.read(hiddenUnlockedProvider)) return true;
  // A notebook route and its child route can both ask at once: one prompt.
  final result = await (_asking ??= ref
      .read(deviceAuthProvider)('Open hidden notes')
      .whenComplete(() => _asking = null));
  if (result == DeviceAuthResult.unlocked) {
    ref.read(hiddenUnlockedProvider.notifier).state = true;
    return true;
  }
  if (result == DeviceAuthResult.noScreenLock && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_noScreenLock)));
  }
  return false;
}

/// Hides notebooks [ids], or shows them again. Hiding needs the device's
/// lock first, so a note can't be hidden where it could never be opened.
Future<bool> setNotesHidden(
  BuildContext context,
  WidgetRef ref,
  Set<int> ids, {
  required bool hidden,
}) async {
  if (!await unlockHidden(context, ref)) return false;
  await ref.read(homeNotifierProvider.notifier).setHiddenMany(ids, hidden);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            hidden
                ? (ids.length == 1
                      ? 'Note hidden'
                      : '${ids.length} notes hidden')
                : (ids.length == 1
                      ? 'Note shown'
                      : '${ids.length} notes shown'),
          ),
        ),
      );
  }
  return true;
}

/// Hidden notebooks open on screen right now. While any is, nothing goes to a
/// cloud model (`_mayUseCloud` in ai_providers.dart): every AI feature works
/// on the open notebook only, so this covers them all, background reads too.
final openHiddenNotebooksProvider = StateProvider<Set<int>>((ref) => const {});

/// Wraps every `/note2/:id` screen. A hidden notebook shows only once the
/// device has unlocked hidden notes; a refusal goes back. However the note
/// was reached (a link in another note, a backlink, recents) it passes here.
class HiddenGate extends ConsumerStatefulWidget {
  const HiddenGate({super.key, required this.notebookId, required this.child});

  final int notebookId;
  final Widget child;

  @override
  ConsumerState<HiddenGate> createState() => _HiddenGateState();
}

class _HiddenGateState extends ConsumerState<HiddenGate> {
  bool _open = false;
  StateController<Set<int>>? _registered;

  @override
  void initState() {
    super.initState();
    // The home list is normally loaded, so a shown note opens with no wait.
    final home = ref.read(homeNotifierProvider);
    if (home.isNotEmpty &&
        !ref.read(hiddenNotebookIdsProvider).contains(widget.notebookId)) {
      _open = true;
    } else {
      Future.microtask(_check);
    }
  }

  Future<void> _check() async {
    final notebook = await ref
        .read(noteRepositoryProvider)
        .getNotebook(widget.notebookId);
    if (!mounted) return;
    if (notebook == null || !notebook.hidden) {
      setState(() => _open = true);
      return;
    }
    final open = ref.read(openHiddenNotebooksProvider.notifier);
    _registered = open;
    open.update((s) => {...s, widget.notebookId});
    if (await unlockHidden(context, ref)) {
      if (mounted) setState(() => _open = true);
    } else if (mounted) {
      final router = GoRouter.of(context);
      router.canPop() ? router.pop() : router.go('/');
    }
  }

  @override
  void dispose() {
    // Riverpod refuses changes while the tree is finalising: just after.
    final open = _registered;
    final id = widget.notebookId;
    if (open != null) {
      Future.microtask(() => open.update((s) => {...s}..remove(id)));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _open ? widget.child : const Scaffold();
}
