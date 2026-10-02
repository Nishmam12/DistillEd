// A PDF page's own text (docs/AI_PIPELINE_PLAN.md, item 8): decided here whether
// it is worth using, so the page can skip OCR and the vision model entirely.
//
// Most lecture slides and papers are not pictures of text — they carry the real
// text, and PDFium reads it out instantly and exactly. The app used to throw it
// away, rasterise the page, and then spend a model call reading it back. Pure
// and free of PDFium: the text is read at import and kept beside the page image
// (`StoragePaths.pdfTextSidecar`); this file only judges what comes back.

/// Reads the text kept for the PDF page whose image is at [relativeImagePath]
/// (relative to the app documents dir): null when none was kept — a photo, or a
/// PDF imported before the text was — and '' when the page has none (a scan).
/// Must not throw: an unreadable file should cost the shortcut, not the page.
typedef PdfTextLayerReader = Future<String?> Function(String relativeImagePath);

/// Meaningful characters a page's text needs to stand in for reading the page.
///
/// A scan often still carries a page number or a running header ("Chapter 3 ·
/// Cell Biology"), and trusting that would turn a whole page of picture into a
/// dozen words. A genuine slide or paragraph clears this easily; a slide that is
/// one diagram and a title may not, and is then read as a picture — which is what
/// it is.
const int kMinPdfTextChars = 80;

/// Whether [text] — the text layer of one PDF page — is enough to use as the
/// page's content. Letters, digits and the marks attached to them count;
/// whitespace and punctuation do not (marks matter: in Bengali the vowel signs
/// are combining marks, and a page of Bangla must not be judged short for it).
bool hasUsablePdfText(String text) =>
    RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true).allMatches(text).length >=
    kMinPdfTextChars;

/// [text] tidied for use: line endings made `\n`, the control characters and
/// noncharacters PDFium can emit removed, the ends trimmed.
String normalizePdfText(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]'), '')
    .trim();
