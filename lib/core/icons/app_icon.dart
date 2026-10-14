// The vuesax-linear SVG icon set used by the margo homepage (assets/icons).
//
// The SVGs hard-code a #292D32 stroke, so every icon is recoloured at paint
// time with a srcIn filter; the colour defaults to the theme's `textPrimary`
// so an icon follows light/dark without the caller doing anything.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// File stems under `assets/icons/`.
abstract final class AppIcons {
  static const sidebarLeft = 'sidebar-left';
  static const noteText = 'note-text';
  static const bookmark = 'bookmark-2';
  static const people = 'people';
  static const folder = 'folder';
  static const addCircle = 'add-circle';
  static const search = 'search-normal';
  static const profile = 'profile-circle';
  static const setting = 'setting';
  static const sort = 'sort';
  static const save = 'save-add';
  static const saved = 'save-added';
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;

  /// Defaults to `context.colors.textPrimary`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? context.colors.textPrimary,
        BlendMode.srcIn,
      ),
    );
  }
}

/// An [AppIcon] drawn at its design size inside a tap target of at least
/// 48 dp, so icons sit exactly where the mockup puts them while staying easy
/// to hit. The target overhangs the glyph by [inset] on every side.
class AppIconButton extends StatelessWidget {
  const AppIconButton(
    this.name, {
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.size = 24,
    this.color,
  });

  final String name;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;

  /// Space between the glyph and the edge of its tap target.
  static double insetFor(double size) => size >= 48 ? 0 : (48 - size) / 2;

  @override
  Widget build(BuildContext context) {
    final box = size + insetFor(size) * 2;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: box, height: box),
      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      icon: AppIcon(name, size: size, color: color),
    );
  }
}
