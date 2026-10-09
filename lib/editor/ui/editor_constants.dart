// Shared lookup tables for the editor toolbar and its tool option panels.

import 'package:flutter/material.dart';
import 'package:distill_ed/core/icons/phosphor_icons_regular.dart';

import '../../domain/model/scene_element.dart';
import '../../editor/state/editor_tool_controller.dart';

// The primary drawing tools, in the order they sit in the toolbar. Frame and
// hand stay in [EditorTool] (the canvas still handles them, and two-finger pan
// covers hand) but are kept off this row to match the pared-back design; image
// import rides at the end as an action, not a tool (see EditorBottomBar).
const List<(EditorTool, IconData)> kEditorTools = [
  (EditorTool.select, PhosphorIconsRegular.lasso),
  (EditorTool.pen, PhosphorIconsRegular.pencilSimple),
  (EditorTool.shape, PhosphorIconsRegular.shapes),
  (EditorTool.eraser, PhosphorIconsRegular.eraser),
  (EditorTool.text, PhosphorIconsRegular.textT),
  (EditorTool.laser, PhosphorIconsRegular.highlighter),
];

// Line and arrow are deliberately not chips here — they're reachable as their
// own Arrow tool in the main tool row instead, right next to the general shape
// tool rather than buried in this picker.
const List<(ShapeType, IconData)> kEditorShapes = [
  (ShapeType.rectangle, Icons.crop_square),
  (ShapeType.circle, Icons.circle_outlined),
  (ShapeType.diamond, Icons.diamond_outlined),
  (ShapeType.triangle, Icons.change_history),
];

// Ink text uses these generic family names, which each platform resolves with its
// own font matching. The app's bundled UI fonts (Poppins, Nunito) are not offered
// here: a stroke of text should look the way the device draws that family.
const List<String> kFontFamilies = ['Roboto', 'Serif', 'Monospace', 'Cursive'];

const Map<Arrowhead, IconData> kArrowheadIcons = {
  Arrowhead.none: Icons.remove,
  Arrowhead.triangle: Icons.arrow_right_alt,
  Arrowhead.dot: Icons.fiber_manual_record,
  Arrowhead.bar: Icons.border_vertical,
};

/// The palette offered when reassigning a favourite swatch (long-press). A
/// compact, purposeful spread — greys through the warm/cool spectrum — rather
/// than a full colour wheel, which is overkill for three quick-pick slots.
///
/// These are *ink* values, so they are written out literally rather than
/// borrowed from the app's chrome palette. Three of them used to resolve from
/// `AppColors` — which meant a chosen swatch would have silently changed hue
/// when the app theme did. A stroke keeps the colour it was drawn in; see
/// `core/theme/paper_colors.dart` for the boundary between ink and chrome.
const List<int> kFavoritePickerColors = [
  0xFF1F2933, // charcoal
  0xFF000000, // black
  0xFF868E96, // grey
  0xFFE03131, // red
  0xFFF2802E, // orange
  0xFFE3A53D, // honey
  0xFF2F9E44, // green
  0xFF1971C2, // blue
  0xFF6741D9, // violet
  0xFF8B8BD8, // periwinkle
  0xFFC2255C, // magenta
  0xFFFFFFFF, // white
];
