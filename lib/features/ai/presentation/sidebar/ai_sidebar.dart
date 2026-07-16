// The AI sidebar: the in-editor home for the Live Context Engine and the
// launch surface for every Phase 1 feature (Explain, Quiz, Flashcards land
// here in later loops).
//
// It coexists with the canvas — a fixed-width right-hand panel on tablet-width
// screens ([AiSidebar]), and a bottom sheet on phone-width ([showAiSidebarSheet]).
// Both wrap the same [AiContextView] body, so the AI's read of the page looks
// identical in either form factor.

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../editor/state/scene_controller.dart';
import 'ai_context_view.dart';

/// Width of the docked panel on wide screens.
const double kAiSidebarWidth = 340;

/// At or above this width the sidebar docks beside the canvas; below it, the
/// AI action opens the bottom sheet instead.
const double kAiSidebarBreakpoint = 720;

/// Docked side panel (wide screens). The editor puts this in a [Row] next to
/// the canvas and controls its visibility.
class AiSidebar extends StatelessWidget {
  final ScenePageKey pageKey;
  final VoidCallback onClose;
  const AiSidebar({super.key, required this.pageKey, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kAiSidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _SidebarHeader(onClose: onClose),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: AiContextView(pageKey: pageKey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone-width presentation: the same body in a bottom sheet.
Future<void> showAiSidebarSheet(BuildContext context, ScenePageKey pageKey) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SidebarHeader(onClose: () => Navigator.of(context).pop()),
            const SizedBox(height: 8),
            Flexible(child: AiContextView(pageKey: pageKey)),
          ],
        ),
      ),
    ),
  );
}

class _SidebarHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _SidebarHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          const Text('AI insights',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          const Spacer(),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
