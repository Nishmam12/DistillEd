// Draws model output with its formulas rendered.
//
// The one widget every AI surface uses for model prose, so a derivative looks
// the same in an explanation, an answer and a summary. Prose stays plain text
// — only the segments [parseMathSegments] identified as LaTeX go through the
// maths renderer, so an ordinary reply is styled exactly as it was before this
// existed.
//
// Two failure modes are handled rather than avoided, because both WILL happen
// with a small on-device model:
//   • Malformed LaTeX. `Math.tex`'s onErrorFallback shows the raw source
//     instead, so one bad formula costs its own line and never the answer or
//     the frame.
//   • A half-arrived formula. Mid-stream the text ends in `$\frac{1`, which
//     the parser reports as prose; it becomes maths on the chunk that closes
//     it. The only visible effect is a formula that appears as source for a
//     moment and then resolves.

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/math_markup.dart';

/// Renders [text], drawing `$…$` / `$$…$$` LaTeX as maths and the rest as
/// ordinary text in [style].
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Appended to the very end of the text — used for the streaming caret, which
  /// must sit after the last character rather than on its own line.
  final InlineSpan? trailing;

  const MathText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effective =
        style ?? DefaultTextStyle.of(context).style;
    final segments = parseMathSegments(text);

    // The overwhelmingly common case: no maths at all. Rendering it through the
    // segmented path would produce identical pixels at more cost, and this way
    // ordinary answers keep the exact text layout they had before.
    if (!segments.any((s) => s.isMath)) {
      return Text.rich(
        TextSpan(text: text, children: [if (trailing != null) trailing!]),
        style: effective,
        textAlign: textAlign,
      );
    }

    // Block formulas break the flow, so the layout is a column of "paragraphs",
    // where each paragraph is prose and inline maths woven together.
    final rows = <Widget>[];
    var inline = <InlineSpan>[];

    void flushInline() {
      if (inline.isEmpty) return;
      rows.add(Text.rich(
        TextSpan(children: List.of(inline)),
        style: effective,
        textAlign: textAlign,
      ));
      inline = [];
    }

    for (final segment in segments) {
      if (segment.isBlock) {
        flushInline();
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.center,
            child: _math(segment.text, effective, MathStyle.display),
          ),
        ));
      } else if (segment.isMath) {
        inline.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _math(segment.text, effective, MathStyle.text),
        ));
      } else {
        inline.add(TextSpan(text: segment.text));
      }
    }
    if (trailing != null) inline.add(trailing!);
    flushInline();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  /// One formula. A parse failure falls back to the LaTeX source in the
  /// surrounding text style — visibly unrendered, but never lost and never a
  /// red error box in the middle of a lesson.
  Widget _math(String latex, TextStyle style, MathStyle mathStyle) {
    return Math.tex(
      latex,
      mathStyle: mathStyle,
      textStyle: style,
      onErrorFallback: (_) => Text(latex, style: style),
    );
  }
}

/// A single short label that may be a formula — a knowledge-graph node caption,
/// a flashcard front. Same rendering rules as [MathText]; separate only because
/// a label must stay on one line and ellipsize rather than wrap into a column.
class MathLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;

  const MathLabel(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final segments = parseMathSegments(text);
    if (!segments.any((s) => s.isMath)) {
      return Text(
        text,
        style: effective,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text.rich(
      TextSpan(children: [
        for (final segment in segments)
          if (segment.isMath)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                segment.text,
                // A label is always inline: a display-style formula inside a
                // graph node would blow the node's size out.
                mathStyle: MathStyle.text,
                textStyle: effective,
                onErrorFallback: (_) => Text(segment.text, style: effective),
              ),
            )
          else
            TextSpan(text: segment.text),
      ]),
      style: effective,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
