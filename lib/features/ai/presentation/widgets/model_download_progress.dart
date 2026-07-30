// The progress bar + percentage readout + cancel button shown while an AI
// model downloads — identical across every feature that can trigger a
// download (ask, explain, quiz, flashcards), only the cancel action differs.

import 'package:flutter/material.dart';

import '../../../../core/theme/ink_colors.dart';


class ModelDownloadProgress extends StatelessWidget {
  final int progress;
  final VoidCallback onCancel;

  const ModelDownloadProgress({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            color: context.ink.accent,
            backgroundColor: context.ink.surfaceHighlight,
          ),
        ),
        const SizedBox(height: 8),
        Text('$progress%',
            style: TextStyle(color: context.ink.textSecondary)),
        TextButton(
          onPressed: onCancel,
          child: Text('Cancel',
              style: TextStyle(color: context.ink.textSecondary)),
        ),
      ],
    );
  }
}
