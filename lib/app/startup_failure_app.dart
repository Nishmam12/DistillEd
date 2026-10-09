// What the user sees when the database cannot be opened. Without it the app
// stays on the splash screen with no explanation and no way out.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/error_log.dart';

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.error, required this.retry});

  final Object error;
  final Future<void> Function() retry;

  /// Shares the database file and the error log, so the notes can be rescued or
  /// diagnosed even when the app cannot open them.
  Future<void> _shareData() async {
    final dir = (await getApplicationDocumentsDirectory()).path;
    final files = [
      File('$dir/inkflow.isar'),
      File('$dir/inkflow_before_v2.isar'),
      File('$dir/inkflow_library.json'),
      (await ErrorLog.existing()),
    ];
    final existing = [
      for (final f in files)
        if (f != null && await f.exists()) XFile(f.path),
    ];
    if (existing.isEmpty) return;
    await SharePlus.instance.share(
        ShareParams(files: existing, text: 'DistillEd data for recovery'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text("Your notes couldn't be opened",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Nothing has been deleted. Try again, and if it keeps '
                  'happening, send your data so it can be recovered.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('$error',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                FilledButton(onPressed: retry, child: const Text('Try again')),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: _shareData, child: const Text('Send my data')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
