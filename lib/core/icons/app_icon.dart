// The vuesax-linear SVG icon sets: the margo homepage (assets/icons) and the
// note editor's top bar (assets/Margo_Note_Toolbar/Icons).
//
// The SVGs hard-code a #292D32 stroke, so every icon is recoloured at paint
// time with a srcIn filter; the colour defaults to the theme's `textPrimary`
// so an icon follows light/dark without the caller doing anything.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Asset paths under `assets/`, without the `.svg` extension.
abstract final class AppIcons {
  static const sidebarLeft = 'icons/sidebar-left';
  static const noteText = 'icons/note-text';
  static const bookmark = 'icons/bookmark-2';
  static const people = 'icons/people';
  static const folder = 'icons/folder';
  static const addCircle = 'icons/add-circle';
  static const search = 'icons/search-normal';
  static const profile = 'icons/profile-circle';
  static const setting = 'icons/setting';
  static const sort = 'icons/sort';
  static const save = 'icons/save-add';
  static const saved = 'icons/save-added';

  // Note editor top bar.
  static const home = '$_toolbar/home';
  static const undo = '$_toolbar/undo';
  static const redo = '$_toolbar/redo';
  static const mic = '$_toolbar/microphone';
  // The toolbar's own 24px search; the homepage one is drawn on a 36px box,
  // so at 24 its stroke thins to 1px.
  static const toolbarSearch = '$_toolbar/search-normal';
  static const ai = '$_toolbar/ai';
  static const note = '$_toolbar/note';
  static const graph = '$_toolbar/knowledge_graph';
  static const book = '$_toolbar/book';
  static const more = '$_toolbar/more-circle';
  static const _toolbar = 'Margo_Note_Toolbar/Icons';
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
      'assets/$name.svg',
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
