// Dev-only screen that runs the figure benchmark (see
// `domain/figure_benchmark.dart`) over one notebook and shows the scores.
//
// Reached from Settings → Developer in debug builds. Nothing here ships.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../editor/state/page_notifier.dart';
import '../../../../editor/state/scene_controller.dart';
import '../../../home/domain/models/notebook.dart';
import '../../../home/presentation/home_notifier.dart';
import '../../domain/ai_provider.dart';
import '../../domain/figure_benchmark.dart';
import '../../domain/untrusted_text.dart';
import '../ai_providers.dart';

class FigureBenchmarkScreen extends ConsumerStatefulWidget {
  const FigureBenchmarkScreen({super.key});

  @override
  ConsumerState<FigureBenchmarkScreen> createState() =>
      _FigureBenchmarkScreenState();
}

class _FigureBenchmarkScreenState extends ConsumerState<FigureBenchmarkScreen> {
  late final Future<List<Notebook>> _notebooks =
      ref.read(noteRepositoryProvider).getAllNotebooks();

  int? _notebookId;
  bool _running = false;
  bool _cancelled = false;
  String _status = '';
  BenchReport? _report;

  Future<void> _run() async {
    final notebookId = _notebookId;
    if (notebookId == null || _running) return;
    setState(() {
      _running = true;
      _cancelled = false;
      _report = null;
      _status = 'Starting…';
    });

    final extractor = ref.read(pageContentExtractorProvider);
    final store = ref.read(sceneElementStoreProvider);
    final settings = ref.read(settingsProvider);
    final text = ref.read(localAiProvider);
    final pages =
        await ref.read(pageRepositoryProvider).getPagesForNotebook(notebookId);
    pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

    final benchmark = FigureBenchmark(
      loadElements: store.loadForPage,
      readPage: (elements) => extractor.extractElements(elements,
          languageCode: settings.recognitionLanguage),
      imageOf: extractor.figureImageFrom,
      pictureOf: extractor.largestPictureFrom,
      answerFromText: (notes, question) => text
          .generate(
            prompt: 'NOTES:\n${fenceUntrusted(notes)}\n\nQUESTION: $question',
            systemPrompt: '$kUntrustedDataRule\n\nAnswer the question using '
                'only the notes. One or two sentences. If the notes do not '
                'say, reply exactly: NOT IN NOTES',
            options: const AiGenerationOptions(
                temperature: 0.0, topP: 0.9, maxTokens: 160),
          )
          .join(),
      local: ref.read(imageTranscriberProvider),
      // The cloud tier follows the same rule as every other page image.
      cloud: settings.cloudAiEnabled &&
              settings.cloudPrivacy == CloudPrivacy.allowCloudForNonSensitive
          ? ref.read(cloudGatewayMidProvider)
          : null,
    );

    final report = await benchmark.run(
      [for (final p in pages) p.id],
      onProgress: (s) {
        if (mounted) setState(() => _status = s);
      },
      isCancelled: () => _cancelled,
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _report = report;
      _status = _cancelled ? 'Stopped.' : 'Done.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Figure benchmark')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pick a notebook of test pages. On each page, put a figure and a '
            'typed text box like:\n\n'
            '    Q: What is the value in Q3?\n'
            '    A: 40\n\n'
            'Several Q/A pairs per box are fine; alternatives go after A: '
            'separated by |. The boxes are hidden from the AI. Pages with no '
            'Q/A box are skipped.',
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Notebook>>(
            future: _notebooks,
            builder: (context, snapshot) {
              final notebooks = snapshot.data ?? const <Notebook>[];
              return DropdownButtonFormField<int>(
                initialValue: _notebookId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Notebook'),
                items: [
                  for (final n in notebooks)
                    DropdownMenuItem(value: n.id, child: Text(n.title)),
                ],
                onChanged:
                    _running ? null : (id) => setState(() => _notebookId = id),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: _notebookId == null || _running ? null : _run,
                child: const Text('Run'),
              ),
              const SizedBox(width: 12),
              if (_running)
                TextButton(
                  onPressed: () => setState(() => _cancelled = true),
                  child: const Text('Stop'),
                ),
              if (report != null)
                TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: report.toText())),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy report'),
                ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_running) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(_status)),
              ],
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 20),
            if (report.results.isEmpty)
              const Text('No questions found in this notebook.')
            else
              SelectableText(
                report.toText(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}
