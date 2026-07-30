// The quiz-taking surface: a near-full-height sheet that renders generation
// progress, then the interactive quiz, grades the attempt locally, and reveals
// answers + explanations.
//
// Grading stays UI-local, but checking answers now also files a durable
// [QuizAttempt] into Phase 2's Learning Memory, attributing each question to the
// concepts it tested so a miss decrements those concepts specifically. That
// write is strictly fire-and-forget: remembering must never break grading.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/ink_colors.dart';
import '../../data/llm/llm_model_spec.dart';
import '../../domain/features/quiz_generator.dart';
import '../../domain/memory/concept_mastery.dart';
import '../../domain/memory/quiz_attempt.dart';
import '../ai_providers.dart';
import '../quiz_notifier.dart';
import '../widgets/model_download_progress.dart';

/// Verdict colours. Deliberately a deeper green than the palette's decorative
/// leaf, so a correct answer reads as a *result* rather than an accent. It has
/// to lighten in dark for the same reason the coral accent does — a mid-tone
/// green on near-black fails contrast.
Color _correct(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);

Color _wrong(BuildContext context) => context.ink.accentRed;

/// Opens the quiz sheet. Call after kicking off [QuizNotifier.generate].
void showQuizSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.ink.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _QuizSheet(),
  );
}

class _QuizSheet extends ConsumerWidget {
  const _QuizSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizNotifierProvider);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: switch (state) {
          QuizIdle() || QuizGenerating() =>
            const _Status(label: 'Building your quiz…'),
          QuizDownloadingModel(:final progress) =>
            _Downloading(progress: progress),
          QuizReady(
            :final questions,
            :final notebookId,
            :final pageId,
            :final concepts
          ) =>
            _QuizRunner(
              questions: questions,
              notebookId: notebookId,
              pageId: pageId,
              concepts: concepts,
            ),
          QuizError() => _ErrorView(state: state),
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
        const _SheetTitle('Quiz'),
        const SizedBox(height: 28),
        CircularProgressIndicator(color: context.ink.accent),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(color: context.ink.textSecondary)),
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
          style: TextStyle(fontSize: 13, color: context.ink.textSecondary),
        ),
        const SizedBox(height: 20),
        ModelDownloadProgress(
          progress: progress,
          onCancel: () =>
              ref.read(quizNotifierProvider.notifier).cancelModelDownload(),
        ),
      ],
    );
  }
}

class _ErrorView extends ConsumerWidget {
  final QuizError state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(quizNotifierProvider.notifier);
    final sizeGb = LlmModelSpec.active.approxSizeBytes / (1024 * 1024 * 1024);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('Quiz'),
        const SizedBox(height: 20),
        Icon(Icons.error_outline, color: _wrong(context), size: 40),
        const SizedBox(height: 12),
        Text(state.message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.ink.textPrimary)),
        const SizedBox(height: 20),
        if (state.offerModelDownload)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.ink.accent),
            onPressed: notifier.downloadModelAndRetry,
            child: Text('Download model (${sizeGb.toStringAsFixed(1)} GB)',
                style: TextStyle(color: context.ink.textOnAccent)),
          )
        else if (state.retryable)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.ink.accent),
            onPressed: notifier.retry,
            child: Text('Try again',
                style: TextStyle(color: context.ink.textOnAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close',
              style: TextStyle(color: context.ink.textSecondary)),
        ),
      ],
    );
  }
}

class _QuizRunner extends ConsumerStatefulWidget {
  final List<QuizQuestion> questions;
  final int notebookId;
  final int pageId;
  final List<String> concepts;

  const _QuizRunner({
    required this.questions,
    required this.notebookId,
    required this.pageId,
    required this.concepts,
  });

  @override
  ConsumerState<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends ConsumerState<_QuizRunner> {
  final Map<int, int> _choice = {}; // question index → selected option
  final Map<int, TextEditingController> _text = {};
  final Set<int> _selfCorrect = {}; // coding questions self-marked correct
  bool _checked = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(int i) =>
      _text.putIfAbsent(i, () => TextEditingController());

  bool _isCorrect(int i) {
    final q = widget.questions[i];
    if (q.isChoice) return _choice[i] == q.correctIndex;
    if (q.type == QuestionType.fillBlank) {
      return q.isCorrectText(_text[i]?.text ?? '');
    }
    return _selfCorrect.contains(i); // coding: self-assessed
  }

  int get _score {
    var n = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      if (_isCorrect(i)) n++;
    }
    return n;
  }

  /// Reveals the answers and files the attempt. A retake (via [_reset]) files a
  /// second, separate attempt — which is exactly what it is.
  void _check() {
    setState(() => _checked = true);
    _recordAttempt();
  }

  /// Files the graded attempt into Learning Memory. Each question is attributed
  /// to the concepts named in its prompt or answer; questions that match no
  /// known concept still count toward the score but move no mastery.
  ///
  /// Wrapped end-to-end: the repository can throw synchronously (no database in
  /// a widget test) and asynchronously (a write failure). Neither is worth
  /// interrupting the learner's results for.
  void _recordAttempt() {
    try {
      final attempt = QuizAttempt.record(
        notebookId: widget.notebookId,
        pageId: widget.pageId,
        takenAt: DateTime.now(),
        outcomes: [
          for (var i = 0; i < widget.questions.length; i++)
            QuizQuestionOutcome(
              prompt: widget.questions[i].prompt,
              correct: _isCorrect(i),
              conceptKeys: conceptKeysMentionedIn(
                '${widget.questions[i].prompt} '
                '${widget.questions[i].correctAnswer}',
                widget.concepts,
              ),
            ),
        ],
      );
      unawaited(ref
          .read(learningMemoryProvider)
          .recordQuizAttempt(attempt)
          .catchError((Object _) {}));
    } catch (_) {
      // Remembering the attempt is a background nicety, never a blocker.
    }
  }

  void _reset() => setState(() {
        _choice.clear();
        for (final c in _text.values) {
          c.clear();
        }
        _selfCorrect.clear();
        _checked = false;
      });

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SheetTitle('Quiz')),
            if (_checked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.ink.accentWash,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$_score / $total',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.ink.accentStrong)),
              ),
            IconButton(
              tooltip: 'Close',
              icon: Icon(Icons.close,
                  size: 20, color: context.ink.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: total,
            itemBuilder: (context, i) => _QuestionCard(
              index: i,
              question: widget.questions[i],
              checked: _checked,
              selected: _choice[i],
              controller: _controller(i),
              selfMarked: _selfCorrect.contains(i),
              onSelect: _checked
                  ? null
                  : (o) => setState(() => _choice[i] = o),
              onSelfMark: (v) => setState(() {
                if (v) {
                  _selfCorrect.add(i);
                } else {
                  _selfCorrect.remove(i);
                }
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!_checked)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.ink.accent),
            onPressed: _check,
            child: Text('Check answers',
                style: TextStyle(color: context.ink.textOnAccent)),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: Text('Retake',
                      style: TextStyle(color: context.ink.accent)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: context.ink.accent),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Done',
                      style: TextStyle(color: context.ink.textOnAccent)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final QuizQuestion question;
  final bool checked;
  final int? selected;
  final TextEditingController controller;
  final bool selfMarked;
  final ValueChanged<int>? onSelect;
  final ValueChanged<bool> onSelfMark;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.checked,
    required this.selected,
    required this.controller,
    required this.selfMarked,
    required this.onSelect,
    required this.onSelfMark,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.ink.surfaceWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.ink.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q${index + 1} · ${q.type.label}'.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: context.ink.textMuted,
              )),
          const SizedBox(height: 6),
          Text(q.prompt,
              style: TextStyle(
                  fontSize: 15, height: 1.35, color: context.ink.textPrimary)),
          const SizedBox(height: 10),
          if (q.isChoice)
            for (var o = 0; o < q.options.length; o++)
              _OptionRow(
                text: q.options[o],
                selected: selected == o,
                state: _optionState(o),
                onTap: onSelect == null ? null : () => onSelect!(o),
              )
          else
            TextField(
              controller: controller,
              enabled: !checked,
              minLines: q.type == QuestionType.coding ? 3 : 1,
              maxLines: q.type == QuestionType.coding ? 8 : 2,
              decoration: InputDecoration(
                hintText: q.type == QuestionType.coding
                    ? 'Write your solution…'
                    : 'Your answer…',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          if (checked) ...[
            const SizedBox(height: 10),
            _Result(question: q, selfMarked: selfMarked, onSelfMark: onSelfMark),
          ],
        ],
      ),
    );
  }

  _OptionState _optionState(int o) {
    if (!checked) return _OptionState.neutral;
    if (o == question.correctIndex) return _OptionState.correct;
    if (o == selected) return _OptionState.wrong;
    return _OptionState.neutral;
  }
}

enum _OptionState { neutral, correct, wrong }

class _OptionRow extends StatelessWidget {
  final String text;
  final bool selected;
  final _OptionState state;
  final VoidCallback? onTap;
  const _OptionRow({
    required this.text,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (border, icon, iconColor) = switch (state) {
      _OptionState.correct => (
          _correct(context),
          Icons.check_circle,
          _correct(context)
        ),
      _OptionState.wrong => (_wrong(context), Icons.cancel, _wrong(context)),
      _OptionState.neutral => (
          selected ? context.ink.accent : context.ink.border,
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          selected ? context.ink.accent : context.ink.textMuted,
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 14, color: context.ink.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final QuizQuestion question;
  final bool selfMarked;
  final ValueChanged<bool> onSelfMark;
  const _Result({
    required this.question,
    required this.selfMarked,
    required this.onSelfMark,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!q.isChoice)
          Text.rich(TextSpan(
            style: const TextStyle(fontSize: 13, height: 1.35),
            children: [
              TextSpan(
                  text: q.isSelfAssessed ? 'Reference: ' : 'Answer: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.ink.textMuted)),
              TextSpan(
                  text: q.correctAnswer,
                  style: TextStyle(color: context.ink.textPrimary)),
            ],
          )),
        if (q.explanation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(q.explanation,
              style: TextStyle(
                  fontSize: 13, height: 1.35, color: context.ink.textSecondary)),
        ],
        if (q.isSelfAssessed) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => onSelfMark(!selfMarked),
            child: Row(
              children: [
                Icon(selfMarked ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color:
                        selfMarked ? _correct(context) : context.ink.textMuted),
                const SizedBox(width: 8),
                Text('I got this right',
                    style: TextStyle(fontSize: 13, color: context.ink.textPrimary)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String text;
  const _SheetTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: context.ink.textPrimary,
        ));
  }
}
