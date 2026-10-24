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
| 1 | Page delete can remove app-private files through unvalidated image paths | `lib/data/persistence/content_purge.dart:110-111` | Medium | 6/10 | Fixed 2026-10-24 (`StoragePaths.isSafeRelativePath`) |
| 2 | Gateway has no caller authentication | `server/ai-gateway/app/main.py`, `server/ai-gateway/README.md:65-66` | Accepted risk, outside criteria | n/a | Open, pre-launch |
| 3 | Release build can silently use the debug signing key | `android/app/build.gradle.kts:62-71` | Shipping blocker | n/a | Open, pre-launch |

---

## 1. Path traversal and app-file deletion on page delete

**Location:** `lib/data/persistence/content_purge.dart:110-111` (`deleteContentFiles`), fed by `lib/features/home/data/repositories/page_repository.dart:92-110` (`deletePage`).

**Category:** path_traversal

**Description:** `deleteContentFiles` runs `File('$docs/$rel').delete()` with no normalization or containment check. The `rel` values are the `relativeImagePath` fields of image elements on the page being deleted, plus their `.txt` sidecars. Those values can come from clipboard JSON:

- `ClipboardService.tryDecode` (`lib/editor/state/clipboard_service.dart:29-38`) checks only the type marker `margo/scene-elements`.
- `SceneElementCodec.decode` (`lib/data/persistence/scene_element_codec.dart:170`) reads `relativeImagePath` verbatim.
- `SelectionEditing.duplicate` and `SceneTransformer.translate` keep the value through `copyWith`.
- The record mapper saves it to Isar unchanged.

**Exploit scenario:**

1. The victim copies attacker-supplied JSON, for example from a web page with a copy handler, a shared snippet, or a background clipboard write (Android clipboard rules were not verified from the repo).
2. The victim pastes it into a notebook through ⋮ → Paste. This saves an invisible, locked image element whose `relativeImagePath` is `margo.isar`.
3. The victim later deletes that page and confirms. `<docs>/margo.isar` is unlinked. On the next launch the app opens an empty database, and all notebooks are lost.
4. `..` segments reach other app-private files, such as `margo_before_v2.isar` and `margo_library.json`.

The app declares no storage permission, so the damage stays inside the app's own data. There is no confidentiality impact.

**Why it is below the bar:** it needs several victim actions (paste, then a confirmed page delete), and the harm falls only on the victim's own data.

**Recommendation:**

- In `deleteContentFiles`, normalize `docs/rel` and refuse any path outside `<docs>/notes/`. Reject absolute paths and `..`. Apply the same check to the audio and sidecar paths.
- Validate `relativeImagePath` at decode time in `SceneElementCodec`, accepting only the app's own `notes/<id>/imports/...` layout. Drop other image elements.
- Stop `SceneImageCache.resolvePath` from passing absolute paths through unchanged.

The fix is small. It is worth doing even though the item is below the reporting bar.

---

## 2. Gateway has no caller authentication

**Location:** `server/ai-gateway/app/guards.py` (`IpThrottleMiddleware`, added in `server/ai-gateway/app/main.py`); `server/ai-gateway/app/routers/generate.py` (only the client-chosen `X-Device-Key` header is required); `server/ai-gateway/README.md` (the "Not done" note on attestation).

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

## Deployability audit, 2026-10-24

A project-wide pass (six lenses, three skeptical votes per finding; all 40 candidates survived). Gates: `flutter analyze` clean, `flutter test` 2714 passed, gateway `pytest` 78 passed (after the fixes below).

Fixed in code during this audit:

- Developer Mode, its settings section, the `/canvas-demo` route and the performance overlay are debug-only (`settings_screen.dart`, `router.dart`, `app.dart`).
- Isar's size cap is raised from 1 GiB to 4 GiB (`isar_service.dart`).
- Duplicating or deleting a page waits for that page's queued scene writes (`page_notifier.dart`, `scene_controller.dart`).
- Gateway search no longer 500s when `results` is not a list (`routers/tools.py`).
- Gateway Docker context excludes all `__pycache__`/`.pyc`/`.pytest_cache`; CI keys the pip cache on the lock file and builds and checks the release APK's native libraries; `.gitignore` covers keystores and `.env` at any depth.
- `/health` caches its database probe for 10 s, so probes no longer queue behind metered requests for the counter lock.
- A request body that stalls for 30 s mid-upload gets a 408 and is cut off. The container runs uvicorn with `--limit-concurrency 200`.
- Unexpected gateway failures before any reply refund the caller's charge, on both the streaming and non-streaming paths.
- Library: a read error no longer counts as an empty library, a removal is rolled back when its save fails, and saves are refused until a load succeeds.
- Notebook editor: a missing or unreadable notebook shows an error with a way back, not a spinner. An image import reports success only after its write lands.
- Scene writes are flushed when the app is paused or detached (best effort), and before a page is duplicated or deleted.
- The v2 migration records pages it gave up on in the error log.
- CI: Flutter pinned to 3.47.7 (the local toolchain); gateway dev tools pinned in `requirements-dev.txt`.

Still open, needs a decision or secrets outside the repo:

- Release signing (item 3): no `android/key.properties` on this machine, and CI never builds a release. Play upload is blocked until the keystore exists.
- Launcher icon is still the default Flutter logo. Needs final artwork.
- Gateway durability: the free Render plan resets the rate-limit counters and global kill switch on every restart (`render.yaml`). Use a paid disk, or set provider-side spend limits as the real backstop.
- Gateway caller authentication (item 2): still the accepted gap; attestation is not implemented.
- Certificate pin: release builds run unpinned unless `GATEWAY_CERT_SHA256` is supplied.
- Migration gives up on unreadable pages after three launches. The loss is now recorded in the error log, but the user is not yet told in the UI.

## Not in scope

- Dependency CVEs (excluded by criteria; manage separately).
- R8 is disabled in `build.gradle.kts` (hardening, not a vulnerability).
