// Where an imported image lands on the page.
//
// Pure geometry, kept out of the import service so it can be tested without a
// file system, a PDF renderer or a device. Two shapes of answer:
//
//  * a whole page — a PDF page, or a photo the user wants as its own sheet —
//    which is aspect-fitted and centred to fill the page (see [fitCentred]);
//  * an inline image dropped onto a page that already has work on it, which is
//    capped against what the user can currently see and centred there (see
//    [inlineSize] and [inlinePlacement]).

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

/// Where an inline image lands: sized by [inlineSize] against the area it will
/// occupy, then centred in it.
///
/// [visible] is the slice of scene currently on screen; [page] is the sheet in
/// single-page mode, or null on the infinite canvas. Only the sheet is drawn in
/// page mode and everything outside it is clipped away, so the image is centred
/// in the part of the page the user can see — centring it in the visible area
/// alone would push it off the paper whenever the view extends past the edge.
/// A view that has left the page entirely falls back to the page's own centre,
/// which is at least somewhere the image exists.
///
/// The centre is deliberately not a free-slot search: a picture is positioned
/// and resized by hand the moment it arrives, and a search that slides it clear
/// of existing work drops it in a far corner of a page that already has any.
///
/// [Rect.zero] when [source] has no measurable size — callers report that
/// rather than adding an image nobody can find.
Rect inlinePlacement(
  Size source,
  Rect visible, {
  Rect? page,
  double fraction = 0.5,
}) {
  var area = visible;
  if (page != null && !page.isEmpty) {
    area = visible.overlaps(page) ? visible.intersect(page) : page;
  }
  final size = inlineSize(source, area.size, fraction: fraction);
  if (size.isEmpty) return Rect.zero;
  return Rect.fromCenter(
    center: area.center,
    width: size.width,
    height: size.height,
  );
}
