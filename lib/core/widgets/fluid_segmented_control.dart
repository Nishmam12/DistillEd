// Fluid sliding-pill segmented toggle control.
//
// Preserves the existing warm cream/coral design language while replacing
// discrete jumping segment buttons with an animated sliding background pill.

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';
import 'bouncy_tap.dart';

class FluidSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const FluidSegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

class FluidSegmentedControl<T> extends StatelessWidget {
  final List<FluidSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double? segmentWidth;
  final double height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const FluidSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.segmentWidth,
    this.height = 40.0,
    this.width,
    this.padding = const EdgeInsets.all(4.0),
    this.fontSize = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    final selectedIndex = segments.indexWhere((s) => s.value == selected);
    final validIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final count = segments.length;

    final double padH = (padding is EdgeInsets)
        ? (padding as EdgeInsets).horizontal
        : 8.0;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final double effTotalWidth = width ??
            (segmentWidth != null
                ? (segmentWidth! * count + padH + 2.0)
                : (outerConstraints.maxWidth.isFinite
                    ? outerConstraints.maxWidth
                    : (80.0 * count + padH + 2.0)));

        return Container(
          width: effTotalWidth,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, innerConstraints) {
              final segW = innerConstraints.maxWidth / count;
              final segH = innerConstraints.maxHeight;

              return Stack(
                children: [
                  // Sliding active pill
                  AnimatedPositioned(
                    duration: AppMotion.standard,
                    curve: AppMotion.spring,
                    left: validIndex * segW,
                    top: 0,
                    width: segW,
                    height: segH,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentWash,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.accent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Segment labels & tap targets
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: BouncyTap(
                            scaleDown: 0.96,
                            enableHaptic: false, // Handled by onChanged
                            onTap: () {
                              if (segments[i].value != selected) {
                                AppMotion.selectionClick();
                                onChanged(segments[i].value);
                              }
                            },
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (segments[i].icon != null) ...[
                                    AnimatedCrossFade(
                                      duration: AppMotion.fast,
                                      crossFadeState: i == validIndex
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: Icon(
                                        segments[i].icon,
                                        size: 16,
                                        color: AppColors.accent,
                                      ),
                                      secondChild: Icon(
                                        segments[i].icon,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: AnimatedDefaultTextStyle(
                                      duration: AppMotion.fast,
                                      curve: Curves.easeOut,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: fontSize,
                                        fontWeight: i == validIndex
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: i == validIndex
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                      ),
                                      child: Text(
                                        segments[i].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
