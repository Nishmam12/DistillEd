// Asked before a lecture is recorded: which language it is in. The answer is what
// Whisper is told to transcribe as (see transcriptionLanguage), so the student
// says it for every lecture instead of the app guessing from the notes beside it.

import 'package:flutter/material.dart';

/// The Whisper code the student picked, or null when they backed out, in which
/// case nothing is recorded.
Future<String?> pickLectureLanguage(BuildContext context) => showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('What language is the lecture in?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('en'),
            child: const Text('English'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('bn'),
            child: const Text('বাংলা'),
          ),
        ],
      ),
    );
