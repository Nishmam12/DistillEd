// TEMPLATE — copy this to `dev_secrets.dart` (same folder) and put your own
// token in the copy. On a fresh clone the app won't compile until you do:
//
//   cp lib/dev/dev_secrets.example.dart lib/dev/dev_secrets.dart
//
// `dev_secrets.dart` is gitignored and MUST NEVER be committed — this repo is
// PUBLIC, and a committed token would be scraped within minutes and is
// impossible to fully remove from git history. This file (the *.example) is
// the only one that is tracked, and it must always hold `null`.
//
// The token here is a convenience only: it's read as a fallback when Settings
// has no token, and ONLY in debug builds (see `huggingFaceTokenProvider`).
// Release builds ignore it entirely. The real, per-user mechanism is
// Settings → AI → HuggingFace Token.
library;

/// Debug-only HuggingFace token fallback. `''` = none — use Settings instead.
const String kDevHuggingFaceToken = '';
