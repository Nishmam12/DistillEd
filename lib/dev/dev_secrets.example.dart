// TEMPLATE — kept for reference / for anyone re-forking this into a public
// repo later. As of the repo going private, `lib/dev/dev_secrets.dart` itself
// is committed with a real shared team token (see its header) so this
// template is no longer required for a fresh clone to compile.
//
// The token is a convenience only: it's read as a fallback when Settings has
// no token, and ONLY in debug builds (see `huggingFaceTokenProvider`). Release
// builds ignore it entirely. The real, per-user mechanism is Settings → AI →
// HuggingFace Token.
library;

/// Debug-only HuggingFace token fallback. `''` = none — use Settings instead.
const String kDevHuggingFaceToken = '';
