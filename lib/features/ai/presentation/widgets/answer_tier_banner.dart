// Tells the student which model they are reading, and when not to trust it.
//
// The accuracy fail-safe is only half a feature without this. Catching that the
// on-device model produced something broken is worthless if the app then shows
// it in the same typeface as a good answer — "never silently show wrong
// teaching as if it were reliable" is the requirement, and this is the part of
// it the student actually sees.
//
// Three states, three different messages, because they mean three different
// things to someone revising:
//   • local            → nothing shown. The normal case needs no chrome.
//   • cloudVerified    → a badge. The privacy rule that cloud use is always
//                        visible applies here exactly as it does to a routed
//                        Explain call.
//   • localLowConfidence → a warning, and (when the user's settings permit it)
//                        a button to check the answer against the cloud model.

import 'package:flutter/material.dart';

import '../../../../core/theme/ink_colors.dart';
import '../../domain/quality/ai_quality_guard.dart';
import '../../domain/quality/output_quality.dart';

class AnswerTierBanner extends StatelessWidget {
  final AnswerTier tier;

  /// What the quality check objected to, used for the warning's second line.
  final QualityIssue? issue;

  /// Offered only when the guard said a cloud re-run is possible AND permitted.
  /// Null hides the action — a button that cannot work is worse than none.
  final VoidCallback? onVerifyWithCloud;

  const AnswerTierBanner({
    super.key,
    required this.tier,
    this.issue,
    this.onVerifyWithCloud,
  });

  @override
  Widget build(BuildContext context) {
    return switch (tier) {
      AnswerTier.local => const SizedBox.shrink(),
      AnswerTier.cloudVerified => _Chip(
          icon: Icons.cloud_done_outlined,
          label: 'Checked with the cloud model',
          foreground: context.ink.accentStrong,
          background: context.ink.accentWash,
        ),
      AnswerTier.localLowConfidence => _Warning(
          issue: issue,
          onVerifyWithCloud: onVerifyWithCloud,
        ),
    };
  }
}

class _Warning extends StatelessWidget {
  final QualityIssue? issue;
  final VoidCallback? onVerifyWithCloud;
  const _Warning({this.issue, this.onVerifyWithCloud});

  @override
  Widget build(BuildContext context) {
    final verify = onVerifyWithCloud;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.ink.surfaceHighlight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.ink.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: context.ink.accentYellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // Deliberately plain about what happened. A vague "something
                  // went wrong" would leave the student guessing whether the
                  // answer is usable, which is the state this exists to end.
                  issue?.message ??
                      "This answer didn't pass the on-device quality check.",
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: context.ink.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              "Don't rely on it without checking your notes.",
              style: TextStyle(fontSize: 12, color: context.ink.textMuted),
            ),
          ),
          if (verify != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: verify,
                  icon: Icon(Icons.cloud_upload_outlined,
                      size: 16, color: context.ink.accent),
                  label: Text(
                    'Check with the cloud model',
                    style: TextStyle(fontSize: 12, color: context.ink.accent),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  const _Chip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
