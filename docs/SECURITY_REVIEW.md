# Security review: branch `tech-migration` vs `main`

Date: 2026-10-09
Status: open. Items below are for follow-up. None met the 8/10 confidence bar for a reported vulnerability.

## Scope and method

- Diff: the full branch against `main`, covering the Flutter app, the Python AI gateway (`server/ai-gateway`), Android native code, and CI workflows.
- Three parallel identification reviews: (A) gateway, CI and committed secrets; (B) Android, app shell, outbound links, logging and rendering; (C) Dart data, networking and file handling.
- Candidates went to separate verifiers. The verifier was resumed once after an interruption and then completed.
- Area A and Area B reported no candidates. Area C reported one candidate, which the verifier scored 6/10.

## Open items

| # | Item | Location | Severity | Confidence | Status |
|---|------|----------|----------|------------|--------|
| 1 | Page delete can remove app-private files through unvalidated image paths | `lib/data/persistence/content_purge.dart:110-111` | Medium | 6/10 | Open, below bar |
| 2 | Gateway has no caller authentication | `server/ai-gateway/app/main.py`, `server/ai-gateway/README.md:65-66` | Accepted risk, outside criteria | n/a | Open, pre-launch |
| 3 | Release build can silently use the debug signing key | `android/app/build.gradle.kts:62-71` | Shipping blocker | n/a | Open, pre-launch |

---

## 1. Path traversal and app-file deletion on page delete

**Location:** `lib/data/persistence/content_purge.dart:110-111` (`deleteContentFiles`), fed by `lib/features/home/data/repositories/page_repository.dart:92-110` (`deletePage`).

**Category:** path_traversal

**Description:** `deleteContentFiles` runs `File('$docs/$rel').delete()` with no normalization or containment check. The `rel` values are the `relativeImagePath` fields of image elements on the page being deleted, plus their `.txt` sidecars. Those values can come from clipboard JSON:

- `ClipboardService.tryDecode` (`lib/editor/state/clipboard_service.dart:29-38`) checks only the type marker `inkflow/scene-elements`.
- `SceneElementCodec.decode` (`lib/data/persistence/scene_element_codec.dart:170`) reads `relativeImagePath` verbatim.
- `SelectionEditing.duplicate` and `SceneTransformer.translate` keep the value through `copyWith`.
- The record mapper saves it to Isar unchanged.

**Exploit scenario:**

1. The victim copies attacker-supplied JSON, for example from a web page with a copy handler, a shared snippet, or a background clipboard write (Android clipboard rules were not verified from the repo).
2. The victim pastes it into a notebook through ⋮ → Paste. This saves an invisible, locked image element whose `relativeImagePath` is `inkflow.isar`.
3. The victim later deletes that page and confirms. `<docs>/inkflow.isar` is unlinked. On the next launch the app opens an empty database, and all notebooks are lost.
4. `..` segments reach other app-private files, such as `inkflow_before_v2.isar` and `inkflow_library.json`.

The app declares no storage permission, so the damage stays inside the app's own data. There is no confidentiality impact.

**Why it is below the bar:** it needs several victim actions (paste, then a confirmed page delete), and the harm falls only on the victim's own data.

**Recommendation:**

- In `deleteContentFiles`, normalize `docs/rel` and refuse any path outside `<docs>/notes/`. Reject absolute paths and `..`. Apply the same check to the audio and sidecar paths.
- Validate `relativeImagePath` at decode time in `SceneElementCodec`, accepting only the app's own `notes/<id>/imports/...` layout. Drop other image elements.
- Stop `SceneImageCache.resolvePath` from passing absolute paths through unchanged.

The fix is small. It is worth doing even though the item is below the reporting bar.

---

## 2. Gateway has no caller authentication

**Location:** `server/ai-gateway/app/main.py` (only `_throttle_by_ip` is applied as a dependency); `server/ai-gateway/app/routers/generate.py` (only the client-chosen `X-Device-Key` header is required); `server/ai-gateway/README.md:65-66`.

**Category:** authentication_bypass (accepted design gap)

**Description:** The README documents this: "Not done: real attestation (Firebase App Check / Play Integrity). Until then anyone can mint device keys; the global caps are the backstop." Anyone who extracts the gateway URL from the APK can call `/v1/generate`, `/v1/vision` and `/v1/tools/search` and spend the provider budget.

**Why it is not reported as a finding:** the impact is bounded by the global caps. Under the review criteria this is resource abuse and rate limiting, which are excluded.

**Why it matters before shipping:** once the global caps are hit, cloud features stop for every user, and the operator's provider spend is exposed.

**Recommendation:**

- Add Play Integrity or Firebase App Check to the gateway before launch.
- Set spend alerts and hard limits on each provider account.

---

## 3. Release build can silently use the debug signing key

**Location:** `android/app/build.gradle.kts:62-71`.

**Description:** When `android/key.properties` is absent, the release build is signed with the per-machine debug key and only logs a warning. The build fails only when `-PrequireReleaseSigning` is passed. Play rejects a debug-signed build, and it cannot update an install signed with a different key.

**Recommendation:** Ensure the shipping build has `android/key.properties`, or passes `-PrequireReleaseSigning=true`. Consider making the build fail by default.

---

## Areas reviewed with no findings

Per the area review reports:

- Committed secrets: none live. `lib/dev/dev_secrets.dart` holds an empty token and is read only in debug builds. The dump files (`code_dump.txt`, `codebase_dump.txt`, `logcat_dump.txt`) contain no credentials.
- Android components: only the launcher activity is exported. `RecordingService` is not exported. `allowBackup="false"`. No cleartext-traffic allowance, no WebView, no share-intent intake.
- Outbound links: only `http` and `https` are launched, and the callers pass fixed URLs.
- Model downloads: LLM and embedder files are checked against pinned SHA-256 hashes before loading. The Whisper download (`resolve/main`) has no hash check; this is hardening only, since TLS applies.
- Gateway: SQL is parameterized. Provider keys and upstream error text are not returned to clients or logged. Docker and Render config do not copy `.env` into the image, and `render.yaml` uses `sync: false` for keys. Docs endpoints are disabled in production.
- Export: `ExportShareService.safeFilename` strips path separators and `..`. Anki HTML fields are escaped.
- Logging: no HuggingFace token, device key, or note text is logged in the areas reviewed.

## Not in scope

- Dependency CVEs (excluded by criteria; manage separately).
- R8 is disabled in `build.gradle.kts` (hardening, not a vulnerability).
