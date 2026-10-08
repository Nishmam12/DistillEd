// The Study Planner screen (Phase 2, Loop 2.5): pick a horizon, generate a
// day-by-day plan from the notebook's weak / due / gap concepts, then work
// through it and tick days off.
//
// The plan is deterministic and built with no model call (see
// `study_planner_notifier.dart`), so this file is only the picker, the day list,
// and completion toggles.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/ink_colors.dart';
import '../../domain/study_planner/note_deadlines.dart';
import '../../domain/study_planner/study_plan.dart';
import '../ai_providers.dart';

/// Task kind → colour. Distinct from the graph's mastery palette on purpose —
/// here the colour means the KIND of work, not how well a concept is known.
Color _taskColor(InkPalette ink, StudyTaskKind kind) => switch (kind) {
      StudyTaskKind.review => ink.accentYellow,
      StudyTaskKind.quiz => ink.accent,
      StudyTaskKind.learnNew => ink.accentPurple,
    };

class StudyPlannerScreen extends ConsumerWidget {
  final int notebookId;
  const StudyPlannerScreen({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(studyPlannerProvider(notebookId));

    return Scaffold(
      backgroundColor: context.ink.background,
      appBar: AppBar(
        title: const Text('Study plan'),
        actions: [
          if (planAsync.value != null)
            IconButton(
              tooltip: 'New plan',
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(studyPlannerProvider(notebookId).notifier).clear(),
            ),
        ],
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Centered(
          icon: Icons.error_outline,
          title: "Couldn't load your plan",
          subtitle: '$e',
        ),
        data: (plan) => plan == null
            ? _GeneratePane(notebookId: notebookId)
            : _PlanView(notebookId: notebookId, plan: plan),
      ),
    );
  }
}

/// Horizon picker + generate button, shown when no plan exists.
class _GeneratePane extends ConsumerStatefulWidget {
  final int notebookId;
  const _GeneratePane({required this.notebookId});

  @override
  ConsumerState<_GeneratePane> createState() => _GeneratePaneState();
}

class _GeneratePaneState extends ConsumerState<_GeneratePane> {
  StudyHorizonKind _kind = StudyHorizonKind.week;
  DateTime? _examDate;

  bool get _needsExamDate => _kind == StudyHorizonKind.exam;
  bool get _canGenerate => !_needsExamDate || _examDate != null;

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  void _generate() {
    final horizon = StudyHorizon(
      kind: _kind,
      startDate: DateTime.now(),
      examDate: _examDate,
    );
    ref.read(studyPlannerProvider(widget.notebookId).notifier).generate(horizon);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Icon(Icons.event_note_outlined,
            size: 40, color: context.ink.accentSoft),
        const SizedBox(height: 12),
        Text('Plan your study',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.ink.textPrimary,
            )),
        const SizedBox(height: 8),
        Text(
          'A day-by-day plan built from what you\'re struggling with, what\'s '
          'due for review, and concepts your notes mention but don\'t explain '
          'yet. Everything on-device.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: context.ink.textSecondary),
        ),
        const SizedBox(height: 24),
        for (final kind in StudyHorizonKind.values)
          _HorizonTile(
            kind: kind,
            selected: _kind == kind,
            onTap: () => setState(() => _kind = kind),
          ),
        if (_needsExamDate) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickExamDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_examDate == null
                ? 'Pick your exam date'
                : 'Exam: ${_formatDate(_examDate!)}'),
          ),
          _NoteDates(
            notebookId: widget.notebookId,
            chosen: _examDate,
            onChoose: (date) => setState(() => _examDate = date),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.ink.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _canGenerate ? _generate : null,
          child: Text('Generate plan',
              style: TextStyle(color: context.ink.textOnAccent, fontSize: 15)),
        ),
      ],
    );
  }
}

/// "Find dates in my notes": looks through the notebook's text for quiz and exam
/// dates and offers each as the exam date, so the countdown can fill itself in.
///
/// Nothing runs until the student asks — the first lookup downloads a small
/// on-device model, which should be something they chose.
class _NoteDates extends ConsumerStatefulWidget {
  final int notebookId;

  /// The exam date currently chosen, to mark the matching suggestion.
  final DateTime? chosen;
  final ValueChanged<DateTime> onChoose;
  const _NoteDates({
    required this.notebookId,
    required this.chosen,
    required this.onChoose,
  });

  @override
  ConsumerState<_NoteDates> createState() => _NoteDatesState();
}

class _NoteDatesState extends ConsumerState<_NoteDates> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    if (!_asked) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _asked = true),
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Find dates in my notes'),
        ),
      );
    }

    final found = ref.watch(noteDeadlinesProvider(widget.notebookId));
    return found.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => _NoteDatesMessage(
        text: e is DateFinderUnavailable
            ? "Couldn't load the date model. It downloads once, so connect to "
                'the internet and try again.'
            : "Couldn't look through your notes.",
        onRetry: () => ref.invalidate(noteDeadlinesProvider(widget.notebookId)),
      ),
      data: (deadlines) => deadlines.isEmpty
          ? const _NoteDatesMessage(
              text: 'No upcoming quiz or exam dates found in your notes.')
          : Column(
              children: [
                for (final d in deadlines)
                  _DeadlineTile(
                    deadline: d,
                    selected: widget.chosen != null &&
                        DateUtils.isSameDay(widget.chosen, d.date),
                    onTap: () => widget.onChoose(d.date),
                  ),
              ],
            ),
    );
  }
}

class _NoteDatesMessage extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _NoteDatesMessage({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.ink.textSecondary)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

/// One date found in the notes: what the line said, and the day it means.
class _DeadlineTile extends StatelessWidget {
  final NoteDeadline deadline;
  final bool selected;
  final VoidCallback onTap;
  const _DeadlineTile({
    required this.deadline,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? context.ink.accentWash : context.ink.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? context.ink.accent : context.ink.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deadline.label,
                  style: TextStyle(
                      fontSize: 14, color: context.ink.textPrimary)),
              const SizedBox(height: 2),
              Text(_formatDate(deadline.date),
                  style: TextStyle(
                      fontSize: 12, color: context.ink.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizonTile extends StatelessWidget {
  final StudyHorizonKind kind;
  final bool selected;
  final VoidCallback onTap;
  const _HorizonTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? context.ink.accentWash : context.ink.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? context.ink.accent : context.ink.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? context.ink.accent : context.ink.textMuted,
              ),
              const SizedBox(width: 12),
              Text(kind.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: context.ink.textPrimary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanView extends ConsumerWidget {
  final int notebookId;
  final StudyPlan plan;
  const _PlanView({required this.notebookId, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plan.isEmpty) {
      return const _Centered(
        icon: Icons.inbox_outlined,
        title: 'Nothing to schedule yet',
        subtitle: "There aren't any weak, due, or unexplained concepts in this "
            'notebook right now. Study a few pages (open the AI sidebar so it '
            'learns your concepts), then generate a plan.',
      );
    }

    final notifier = ref.read(studyPlannerProvider(notebookId).notifier);
    return Column(
      children: [
        _PlanHeader(plan: plan),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: plan.days.length,
            itemBuilder: (context, i) => _DayCard(
              index: i,
              day: plan.days[i],
              onToggle: (done) => notifier.setDayCompleted(i, done),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final StudyPlan plan;
  const _PlanHeader({required this.plan});

  @override
  Widget build(BuildContext context) {
    final pct = (plan.progress * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: context.ink.surface,
        border: Border(bottom: BorderSide(color: context.ink.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${plan.horizonKind.label} plan · ${plan.conceptCount} concepts',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.ink.textPrimary,
              )),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: plan.progress,
              minHeight: 8,
              color: context.ink.accentGreen,
              backgroundColor: context.ink.surfaceHighlight,
            ),
          ),
          const SizedBox(height: 6),
          Text('$pct% complete',
              style: TextStyle(
                  fontSize: 12, color: context.ink.textSecondary)),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final int index;
  final StudyDay day;
  final ValueChanged<bool> onToggle;
  const _DayCard({
    required this.index,
    required this.day,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.ink.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.ink.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Day ${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink.textPrimary,
                    )),
                const SizedBox(width: 8),
                Text(_formatDate(day.date),
                    style: TextStyle(
                        fontSize: 12, color: context.ink.textMuted)),
                const Spacer(),
                if (!day.isRest)
                  // A subtle "done" toggle per day.
                  Checkbox(
                    value: day.completed,
                    onChanged: (v) => onToggle(v ?? false),
                    activeColor: context.ink.accentGreen,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (day.isRest)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text('Rest / catch-up day',
                    style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: context.ink.textSecondary)),
              )
            else
              for (final task in day.tasks) _TaskRow(task: task),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final StudyTask task;
  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration:
                BoxDecoration(
                    color: _taskColor(context.ink, task.kind),
                    shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.label,
                    style: TextStyle(
                        fontSize: 14, color: context.ink.textPrimary)),
                Text(task.kind.reason,
                    style: TextStyle(
                        fontSize: 12, color: context.ink.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Centered({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.ink.accentSoft),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.ink.textPrimary,
                )),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: context.ink.textSecondary)),
          ],
        ),
      ),
    );
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Mon, Jul 20" — no intl dependency for a one-line label.
String _formatDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
