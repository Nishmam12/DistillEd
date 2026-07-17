// The flashcard surface: generation progress, then a flip-through deck built
// from the current page, with one-tap "Export to Anki" (CSV). The deck is
// already persisted in Isar by the time it's shown here.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../export/export_share_service.dart';
import '../../data/flashcards/flashcard_apkg.dart';
import '../../data/flashcards/flashcard_csv.dart';
import '../../data/llm/llm_model_spec.dart';
import '../../domain/models/flashcard.dart';
import '../ai_providers.dart';
import '../flashcard_notifier.dart';

/// Opens the flashcard sheet. Call after kicking off [FlashcardNotifier.generate].
void showFlashcardSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _FlashcardSheet(),
  );
}

class _FlashcardSheet extends ConsumerWidget {
  const _FlashcardSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flashcardNotifierProvider);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: switch (state) {
          FlashcardIdle() || FlashcardGenerating() =>
            const _Status(label: 'Making flashcards…'),
          FlashcardDownloadingModel(:final progress) =>
            _Downloading(progress: progress),
          FlashcardReady(:final cards, :final deckName) =>
            _Deck(cards: cards, deckName: deckName),
          FlashcardError() => _ErrorView(state: state),
        },
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final String label;
  const _Status({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('Flashcards'),
        const SizedBox(height: 28),
        const CircularProgressIndicator(color: AppColors.accent),
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Downloading extends ConsumerWidget {
  final int progress;
  const _Downloading({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeGb = LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('Downloading model'),
        const SizedBox(height: 8),
        Text(
          '${LlmModelSpec.active.displayName} · '
          '${sizeGb.toStringAsFixed(1)} GB — one-time download',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceHighlight,
          ),
        ),
        const SizedBox(height: 8),
        Text('$progress%',
            style: const TextStyle(color: AppColors.textSecondary)),
        TextButton(
          onPressed: () => ref
              .read(flashcardNotifierProvider.notifier)
              .cancelModelDownload(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _ErrorView extends ConsumerWidget {
  final FlashcardError state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(flashcardNotifierProvider.notifier);
    final sizeGb = LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('Flashcards'),
        const SizedBox(height: 20),
        const Icon(Icons.error_outline, color: AppColors.accentRed, size: 40),
        const SizedBox(height: 12),
        Text(state.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 20),
        if (state.offerModelDownload)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: notifier.downloadModelAndRetry,
            child: Text('Download model (${sizeGb.toStringAsFixed(1)} GB)',
                style: const TextStyle(color: AppColors.textOnAccent)),
          )
        else if (state.retryable)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: notifier.retry,
            child: const Text('Try again',
                style: TextStyle(color: AppColors.textOnAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _Deck extends StatefulWidget {
  final List<Flashcard> cards;
  final String deckName;
  const _Deck({required this.cards, required this.deckName});

  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> {
  final _controller = PageController();
  final Set<int> _flipped = {};
  int _index = 0;
  bool _exporting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _export({required bool apkg}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      if (apkg) {
        try {
          final bytes =
              flashcardsToApkg(widget.cards, deckName: widget.deckName);
          await _share(bytes, 'apkg', 'application/octet-stream');
          return;
        } catch (_) {
          // The native SQLite engine is unavailable (or the build failed) — fall
          // back to the directive CSV so the user still gets an importable file.
          await _shareCsv();
          _notify('Exported as CSV — the .apkg deck format is unavailable here.');
          return;
        }
      }
      await _shareCsv();
    } catch (_) {
      _notify("Couldn't export the flashcards.");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareCsv() async {
    final csv = flashcardsToAnkiCsv(widget.cards, deckName: widget.deckName);
    await _share(Uint8List.fromList(utf8.encode(csv)), 'csv', 'text/csv');
  }

  Future<void> _share(Uint8List bytes, String ext, String mimeType) {
    return ExportShareService.shareFile(
      bytes: bytes,
      filename: 'flashcards_${DateTime.now().millisecondsSinceEpoch}.$ext',
      mimeType: mimeType,
    );
  }

  void _notify(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.cards.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SheetTitle('Flashcards')),
            Text('${_index + 1} / $total',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close,
                  size: 20, color: AppColors.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          child: PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _CardFace(
              card: widget.cards[i],
              showBack: _flipped.contains(i),
              onTap: () => setState(() {
                if (!_flipped.add(i)) _flipped.remove(i);
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _exporting ? null : () => _export(apkg: true),
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textOnAccent))
              : const Icon(Icons.style_outlined,
                  size: 18, color: AppColors.textOnAccent),
          label: const Text('Export to Anki (.apkg)',
              style: TextStyle(color: AppColors.textOnAccent)),
        ),
        TextButton(
          onPressed: _exporting ? null : () => _export(apkg: false),
          child: const Text('Export as CSV',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  final Flashcard card;
  final bool showBack;
  final VoidCallback onTap;
  const _CardFace({
    required this.card,
    required this.showBack,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: showBack ? AppColors.accentWash : AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(showBack ? 'ANSWER' : 'PROMPT',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  )),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    showBack ? card.back : card.front,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: showBack ? 16 : 18,
                      height: 1.4,
                      fontWeight:
                          showBack ? FontWeight.w400 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(showBack ? 'Tap to see prompt' : 'Tap to reveal answer',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String text;
  const _SheetTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ));
  }
}
