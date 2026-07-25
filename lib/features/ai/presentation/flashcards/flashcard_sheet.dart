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
import '../widgets/model_download_progress.dart';

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
    // The deck view earns its own near-full-height, edge-to-edge canvas — the
    // big color card is the point. Every other state keeps the standard sheet
    // padding used across the AI surfaces (quiz, summarize).
    final isDeck = state is FlashcardReady;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: isDeck
            ? const EdgeInsets.fromLTRB(16, 10, 16, 12)
            : const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
        ModelDownloadProgress(
          progress: progress,
          onCancel: () => ref
              .read(flashcardNotifierProvider.notifier)
              .cancelModelDownload(),
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

  bool get _flippedCurrent => _flipped.contains(_index);

  void _toggleFlip() => setState(() {
        if (!_flipped.add(_index)) _flipped.remove(_index);
      });

  void _nextCard() => _controller.nextPage(
      duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final total = widget.cards.length;
    final flipped = _flippedCurrent;
    final onLastCard = _index == total - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Minimal top chrome — just position + close. The color card itself
        // carries the "Flashcards" identity, so no title line competes for
        // height here.
        Row(
          children: [
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close,
                  size: 20, color: AppColors.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            const Spacer(),
            Text('${_index + 1} / $total',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _CardFace(
                card: widget.cards[i],
                showBack: _flipped.contains(i),
                onTap: () => setState(() {
                  if (!_flipped.add(i)) _flipped.remove(i);
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: !flipped
                ? _toggleFlip
                : (onLastCard ? _toggleFlip : _nextCard),
            icon: Icon(!flipped
                ? Icons.sync
                : (onLastCard ? Icons.arrow_back : Icons.arrow_forward)),
            label: Text(!flipped
                ? 'Flip to answer'
                : (onLastCard ? 'Back to prompt' : 'Next card')),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _exporting ? null : () => _export(apkg: true),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textOnAccent))
                    : const Icon(Icons.style_outlined,
                        size: 16, color: AppColors.textOnAccent),
                label: const Text('Export to Anki (.apkg)',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textOnAccent)),
              ),
            ),
            TextButton(
              onPressed: _exporting ? null : () => _export(apkg: false),
              child: const Text('Export as CSV',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    );
  }
}

/// One full-bleed color card per side: a soft honey wash for the prompt, solid
/// coral for the answer. The color swap itself signals "flipped" — there's no
/// separate caption competing with the term for attention.
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
    final bg = showBack ? AppColors.accent : AppColors.accentYellowWash;
    final fg = showBack ? AppColors.textOnAccent : AppColors.textPrimary;
    final labelBg = showBack ? AppColors.accentStrong : AppColors.surface;
    final labelFg = showBack ? AppColors.textOnAccent : AppColors.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: labelBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(showBack ? 'ANSWER' : 'PROMPT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: labelFg,
                    )),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    child: Text(
                      showBack ? card.back : card.front,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: showBack ? 20 : 26,
                        height: 1.32,
                        letterSpacing: -0.2,
                        fontWeight:
                            showBack ? FontWeight.w500 : FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ),
              ),
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
