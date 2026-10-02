// Switches for the page-reading pipeline restructuring in
// docs/AI_PIPELINE_PLAN.md ("Next — restructure the pipeline").
//
// Each turns one change on or off so it can be compared on a device against the
// measurements the plan lists — time to page text, handwriting accuracy,
// retrieval hit rate — rather than taken on faith. They are constants, not
// settings: flip one, hot-restart, run the same pages again. The defaults are
// the plan's target pipeline; the code behind each flag keeps the previous
// behaviour reachable, so switching one off is a real A/B and not a stub.

/// Item 9. Read handwriting with ML Kit Digital Ink first and send Gemma vision
/// only the lines ML Kit cannot be trusted on (low confidence, symbol soup,
/// maths), cropped to those lines. Off restores the whole-page Gemma read first,
/// with ML Kit as the fallback. A Re-read always does the whole-page read.
const bool kMlKitFirstInk = true;

/// Item 10. Remember every vision read by a hash of what was sent, so reopening
/// a notebook, re-indexing it, or switching pages costs nothing for content
/// already read. Off reads everything afresh each time, as before. A Re-read
/// always skips the lookup.
const bool kPersistReads = true;

/// Item 12. Index an import in two passes — every vision read first, then
/// unload Gemma, then every embedding — instead of alternating the two models
/// page by page. Off restores the one-page-at-a-time loop.
const bool kBatchByModel = true;
