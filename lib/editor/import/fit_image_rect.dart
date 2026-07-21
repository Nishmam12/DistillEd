// Where an imported image lands on the page.
//
// Pure geometry, kept out of the import service so it can be tested without a
// file system, a PDF renderer or a device. Two shapes of answer:
//
//  * a whole page — a PDF page, or a photo the user wants as its own sheet —
//    which is aspect-fitted and centred to fill the page (see [fitCentred]);
//  * an inline image dropped onto a page that already has work on it, which is
//    capped against what the user can currently see (see [scaledToFit]) and
//    then positioned by the caller's usual free-slot search.

import 'dart:ui';

/// The largest size with [source]'s aspect ratio that fits inside [max].
///
/// Scales up as well as down: an imported page is meant to fill its sheet, and
/// a small source left at its pixel size would sit as a stamp in the corner.
/// A degenerate [source] or [max] has no aspect to preserve and yields
/// [Size.zero], which callers treat as "nothing to place".
Size scaledToFit(Size source, Size max) {
  if (source.width <= 0 ||
      source.height <= 0 ||
      max.width <= 0 ||
      max.height <= 0) {
    return Size.zero;
  }
  final scale = (max.width / source.width) < (max.height / source.height)
      ? max.width / source.width
      : max.height / source.height;
  return Size(source.width * scale, source.height * scale);
}

/// [source] aspect-fitted and centred inside [target], inset by [margin] on
/// every side.
///
/// [Rect.zero] when there is nothing sensible to fit — a zero-sized source, or
/// a margin thick enough to leave no room. Callers check `isEmpty` rather than
/// receiving an inverted rect.
Rect fitCentred(Size source, Rect target, {double margin = 0}) {
  final inner = target.deflate(margin);
  if (inner.width <= 0 || inner.height <= 0) return Rect.zero;

  final size = scaledToFit(source, inner.size);
  if (size.isEmpty) return Rect.zero;

  return Rect.fromLTWH(
    inner.left + (inner.width - size.width) / 2,
    inner.top + (inner.height - size.height) / 2,
    size.width,
    size.height,
  );
}

/// How large an inline image should be: [source] capped to [fraction] of
/// [visible], so a 4000px photo doesn't arrive filling the whole view, and a
/// small one is never blown up past its own resolution.
///
/// Unlike [fitCentred] this deliberately does *not* scale up — an inline image
/// is a figure alongside the user's work, not a backdrop, and upscaling a
/// screenshot to half the viewport only makes it blurry.
Size inlineSize(Size source, Size visible, {double fraction = 0.5}) {
  if (visible.width <= 0 || visible.height <= 0) return Size.zero;
  final capped = scaledToFit(
    source,
    Size(visible.width * fraction, visible.height * fraction),
  );
  if (capped.isEmpty) return Size.zero;
  return capped.width > source.width ? source : capped;
}
