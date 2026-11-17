// "Share to Margo" and "Open with Margo" (Android).
//
// MainActivity holds the incoming intent and copies its files into the cache;
// this asks for it on start and whenever it says one "arrived", asks where it
// should go (a new note or an existing one), and opens the editor with it. The
// editor runs it through the same import paths its own import sheet uses.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/error_log.dart';
import '../home/presentation/home_notifier.dart';

@immutable
class SharedFile {
  final String path;
  final String mimeType;
  final String name;

  const SharedFile({required this.path, required this.mimeType, required this.name});

  String get _ext => name.contains('.') ? name.split('.').last.toLowerCase() : '';

  // The sender's MIME type can be missing or generic (`*/*`), so the
  // extension decides too.
  bool get isPdf => mimeType == 'application/pdf' || _ext == 'pdf';
  bool get isImage =>
      mimeType.startsWith('image/') ||
      const {'jpg', 'jpeg', 'png', 'webp', 'heic', 'gif', 'bmp'}.contains(_ext);
}

@immutable
class SharedPayload {
  final String? text;
  final String? subject;
  final List<SharedFile> files;

  const SharedPayload({this.text, this.subject, this.files = const []});

  /// From the map MainActivity's `take` returns; null when there is nothing.
  static SharedPayload? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final files = [
      for (final f in (map['files'] as List<Object?>? ?? const []))
        if (f is Map && f['path'] is String)
          SharedFile(
            path: f['path'] as String,
            mimeType: (f['mimeType'] as String?) ?? '',
            name: (f['name'] as String?) ?? '',
          ),
    ];
    final text = (map['text'] as String?)?.trim();
    if (files.isEmpty && (text == null || text.isEmpty)) return null;
    return SharedPayload(
      text: (text == null || text.isEmpty) ? null : text,
      subject: (map['subject'] as String?)?.trim(),
      files: files,
    );
  }

  /// A title for a note made from this share.
  String get suggestedTitle {
    if (subject != null && subject!.isNotEmpty) return subject!;
    if (files.isNotEmpty) {
      final name = files.first.name;
      final dot = name.lastIndexOf('.');
      return dot > 0 ? name.substring(0, dot) : name;
    }
    final firstLine = text!.split('\n').first.trim();
    return firstLine.length > 40 ? '${firstLine.substring(0, 40)}…' : firstLine;
  }
}

/// Read once at the app root (see [MargoApp]) to start listening.
final shareIntakeProvider = Provider<void>((ref) {
  const channel = MethodChannel('com.margo.margo/share');
  var busy = false;

  Future<void> take() async {
    if (busy) return; // the next "arrived" picks up anything newer
    busy = true;
    try {
      final map = await channel.invokeMethod<Map<Object?, Object?>>('take');
      final share = SharedPayload.fromMap(map);
      if (share != null) await _deliver(ref, share);
    } on MissingPluginException {
      // Not Android (or a test): nothing is ever shared in.
    } catch (e, st) {
      await ErrorLog.record(e, st);
    } finally {
      busy = false;
    }
  }

  channel.setMethodCallHandler((call) async {
    if (call.method == 'arrived') await take();
  });
  // A cold start from a share: wait for the first frame so there is a
  // navigator to show the sheet on.
  WidgetsBinding.instance.addPostFrameCallback((_) => take());
});

Future<void> _deliver(Ref ref, SharedPayload share) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  final home = ref.read(homeNotifierProvider.notifier);
  await home.loadNotebooks();
  if (!context.mounted) return;
  final notebooks = ref.read(homeNotifierProvider);

  // null = cancelled, -1 = new note, else the notebook id.
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add to Margo')),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('New note'),
              subtitle: Text(share.suggestedTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).pop(-1),
            ),
            if (notebooks.isNotEmpty) const Divider(),
            for (final nb in notebooks)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(nb.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).pop(nb.id),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice == null) return;
  final id = choice == -1
      ? (await home.createNotebook(share.suggestedTitle.isEmpty
              ? 'Shared note'
              : share.suggestedTitle))
          .id
      : choice;
  await appRouter.push('/note2/$id', extra: share);
}
