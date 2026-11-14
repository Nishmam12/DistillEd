// What typing text on the page produces. The modal "Add text" / "Edit text"
// dialog that once lived here was replaced by typing on the page itself
// (`inline_text_editor.dart`); this stays the contract between that field
// and the canvas that commits it.

import '../../domain/model/scene_element.dart';

/// The words as typed plus the formatting chosen alongside them. Formatting
/// is set while typing as well as in the selection bar, so text can be styled
/// as it is written rather than only after.
class SceneTextResult {
  final String text;
  final bool isBold;
  final bool isItalic;
  final TextAlignKind align;

  const SceneTextResult({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.align = TextAlignKind.left,
  });
}
