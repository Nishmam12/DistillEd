// Debug-only HuggingFace token fallback.
//
// Read as a fallback when Settings has no token, and ONLY in debug builds
// (see `huggingFaceTokenProvider` in features/ai/presentation/ai_providers.dart).
// Release builds ignore it entirely. The real, per-user mechanism is
// Settings → AI → HuggingFace Token.
library;

/// Debug-only HuggingFace token fallback. `''` = none — use Settings instead.
const String kDevHuggingFaceToken = '';
