// The app's one door out to a web browser.
//
// Why it exists at all: EmbeddingGemma lives in a GATED HuggingFace repo, and
// HuggingFace accepts a licence agreement ONLY from a browser — there is no
// API for it, and OAuth does not help either (it grants API scopes, it cannot
// click the agreement). So the one unavoidable step in setting up search is a
// hand-off to a browser.
//
// Why a Custom Tab and not a WebView: `inAppBrowserView` maps to an Android
// Custom Tab / iOS SFSafariViewController, which SHARES THE DEFAULT BROWSER'S
// COOKIE JAR. The user who just created a HuggingFace token is, by definition,
// already signed in there, so the gate form opens ready to accept — and it
// renders as a dismissible overlay, dropping them back where they started. An
// embedded `webview_flutter` would have its own cookie jar, forcing a second
// login *inside our app* — worse to use, and an app asking for someone's
// HuggingFace password in its own window is indistinguishable from phishing.
//
// FAIL-SOFT, mirroring `hf_access_check.dart`: nothing here throws. A device
// with no browser, a blocked intent, or a malformed URL returns false so the
// caller can show the link instead of appearing to do nothing.

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in a Custom Tab, falling back to the external browser.
///
/// Returns true if a browser took it. Returns false — never throws — when the
/// URL is unusable or no handler exists; callers MUST handle false by
/// surfacing the raw URL, because from the user's side a silent no-op looks
/// like a broken button.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;

  // Tried in order of how good the experience is, not how likely it is to
  // work. `inAppBrowserView` keeps the user inside the app's task; the
  // external browser costs an app switch but always exists in practice.
  for (final mode in const [
    LaunchMode.inAppBrowserView,
    LaunchMode.externalApplication,
  ]) {
    try {
      if (await launchUrl(uri, mode: mode)) return true;
    } catch (e) {
      // A PlatformException here means this MODE is unavailable (no Custom Tab
      // provider installed, for instance), not that the URL is bad — so keep
      // going and let the next mode try.
      debugPrint('openExternalUrl: $mode failed for $url — $e');
    }
  }
  return false;
}
