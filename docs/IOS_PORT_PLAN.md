# Margo on iOS / iPadOS: port plan

Branch: `iPadOS-build` (cut from `margo-device-fixes` at 5.1.1+32).
Written 2026-11-14.

## Goal

Everything that can be prepared on Linux is prepared on this branch, so that on
a Mac the work is: pull, `flutter pub get`, `pod install`, pick a signing team,
run on the iPad.

**What "just pull and compile" can and cannot promise.** Linux cannot compile
any iOS code, so nothing in `ios/` can be verified locally. The plan closes that
gap with a GitHub Actions macOS job (phase 2): the repository is public, so
macOS runners are free, and the job compiles the iOS app on every push to this
branch. If that job is green, the Mac build should work; if we skip it, expect
the first Mac session to be spent on build errors.

Test device: iPad (11th generation), about 6 GB RAM, 60 Hz, with an ESR digital
pencil (expected to report no pressure).

## Rules that keep Android safe

1. iOS work is additive: the `ios/` folder, new Dart files, and platform
   switches. No Android file is edited for iOS reasons.
2. Shared Dart code changes only behind a platform check or an existing port
   (`BackupTarget`, `DocumentScannerPort`, `AudioCapturePort`), and Android
   keeps its current implementation.
3. Channel names and method names stay identical to `MainActivity.kt`, so the
   Dart callers do not change.
4. After every phase: `flutter analyze`, `flutter test`, and
   `flutter build apk --debug` still pass on this branch.
5. Merge `main` (or the current Android release branch) into this branch
   regularly. A long-lived branch that never merges back becomes a fork; the
   changes here are designed so the branch can be merged into `main` once iOS
   works.

## Phase 1: generate the iOS project (Linux)

- `flutter create --platforms=ios --org com.margo --project-name margo .`
  Bundle id becomes `com.margo.margo`, matching Android. Review the diff and
  revert anything it touches outside `ios/`.
- `.gitignore`: add the standard iOS entries (`ios/Pods/`, `ios/.symlinks/`,
  `ios/Flutter/Flutter.framework`, `ios/Flutter/Generated.xcconfig`,
  `ios/Flutter/flutter_export_environment.sh`, `**/DerivedData/`,
  `**/xcuserdata/`). Commit `ios/Podfile`; `Podfile.lock` gets committed from
  the first successful CI or Mac build.
- `ios/Podfile`, modelled on the `flutter_edge_ai` example app:
  - `platform :ios, '16.0'` (ML Kit needs 15.5, the LLM runtime 15.0).
  - `use_frameworks! :linkage => :static` (required by `flutter_edge_ai`).
  - `post_install`: force `IPHONEOS_DEPLOYMENT_TARGET = 16.0` on every pod,
    and call `mlkit_apple_silicon_simulator_patch(installer)` from
    `google_mlkit_commons` so the simulator builds on Apple Silicon.
- `ios/Runner/Info.plist`:
  - `NSMicrophoneUsageDescription` (lecture recording).
  - `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
    (`image_picker`, later the document scanner).
  - `UIBackgroundModes` = `audio` (keeps a recording alive in the background;
    replaces `RecordingService.kt`).
  - `ITSAppUsesNonExemptEncryption` = `false`.
  - All four orientations for iPad (needed for Split View and Stage Manager).
  - Display name `Margo`.
- `ios/Runner/Runner.entitlements` with the three memory entitlements the LLM
  runtime asks for (`extended-virtual-addressing`, `increased-memory-limit`,
  `increased-debugging-memory-limit`). **Fallback:** if a free Apple ID refuses
  to sign with them, remove the file's entries; only the large model is
  affected.
- App icon and launch screen from the existing Android artwork.
- `README.md`: replace the "Android only" paragraph with the real status.

Done when: `flutter pub get` succeeds and `flutter analyze` is clean.

**Status (2026-11-14): done except icon and `Podfile.lock`.**

- Generated with Flutter 3.50 (Swift Package Manager on, scene lifecycle
  already in the template). `ios/Podfile` mixes SPM and CocoaPods; ML Kit and
  `flutter_edge_ai` come in through CocoaPods.
- `flutter create` re-resolved `pubspec.lock` to much newer package versions,
  which broke the Isar generated files (`const_eval_throws_exception`).
  The committed lock was restored and re-resolved with plain `pub get`;
  analyze is back to its baseline (0 errors). **Do not run
  `flutter create` again on this branch** without checking `pubspec.lock`.
- The app icon is still Flutter's default: the only Margo artwork in the repo
  is the 192 px Android launcher icon, too small for iOS (needs 1024 px, opaque,
  no transparency). Supply a 1024 px source.
- `ios/Podfile.lock` was taken from the first green CI run and should be
  committed; on the Mac `pod install` will keep it in sync.

## Phase 2: macOS CI job (Linux, verified in the cloud)

**Status: green (run 43575700965, 2026-11-14): `flutter build ios --debug
--no-codesign` produces `Runner.app`, so Dart, the Swift channels and every pod
(ML Kit, LiteRT-LM) compile and link on a clean macOS runner. Compiling is not
running: nothing has been launched on a device. `ios/Podfile.lock` came from
this run.** First run failed on a Podfile ordering bug, fixed in db84639. A separate workflow,
`.github/workflows/ios.yml`, so `ci.yml` and Android CI are untouched. It runs
on pushes to `iPadOS-build` and by hand. It does:

- `runs-on: macos-latest`, Flutter pinned to the version used locally (3.50.0).
- `flutter pub get`, then `flutter build ios --debug --no-codesign`.
- Upload `ios/Podfile.lock` as an artifact so it can be committed.

This is the only way to see compile and link errors before a Mac is available.
Every later phase is "done" only when this job is green.

Needs: pushing the branch to GitHub.

## Phase 3: port the platform channels to Swift (Linux, verified by CI)

**Status: written in `ios/Runner/AppDelegate.swift` (not in a separate file, to
avoid hand-editing the Xcode project); uncompiled until CI or a Mac builds it.**

All in `ios/Runner/` (one `MargoChannels.swift`, registered from the generated
`AppDelegate.swift` using whatever engine hook the template provides).

| Channel | Method | iOS implementation |
|---|---|---|
| `com.margo.margo/storage` | `getFreeBytes` | `volumeAvailableCapacityForImportantUsage` of the app's Documents volume. Without this the Dart side reads 0 and refuses every model download. |
| `com.margo.margo/device` | `snapshot` | `totalRamBytes`: `ProcessInfo.physicalMemory`. `thermalStatus`: map `ProcessInfo.thermalState` nominal/fair/serious/critical to 0/1/3/4 so `kPauseAtThermalStatus = 2` pauses at "serious". `thermalHeadroom`: null. `batteryPercent`/`charging`: `UIDevice` with battery monitoring on. `powerSave`: `isLowPowerModeEnabled`. `metered`: `NWPathMonitor` `isExpensive`. |
| `com.margo.margo/recording` | `start` / `stop` | Not implemented. The Dart side already ignores a missing channel, and the `audio` background mode does the job. |
| `com.margo.margo/backup` | `save` / `delete` | Not implemented in Swift; handled in Dart (phase 4). |

Expected result on the test iPad: 6 GB reports above `kLiteProfileMinRamBytes`
(5 GB) and below `kFullProfileMinRamBytes` (7 GB), so it gets `AiProfile.lite`.

## Phase 4: Dart changes behind existing ports (Linux, unit-tested)

**Status: done.** `AppDocumentsBackupTarget` (+ test), chosen in
`backup_controller.dart` only when the platform is iOS; Android still uses
`DownloadsBackupTarget`. The Settings backup note now says "On this device".
Full suite: 2974 tests pass.

- **Backup.** `DownloadsBackupTarget` throws on iOS because nothing answers the
  channel. Add `AppDocumentsBackupTarget implements BackupTarget` that copies
  into `<Documents>/Margo backups/` with `dart:io`, and choose between the two
  in `_backupTargetProvider` (`lib/features/backup/backup_controller.dart`) by
  platform. The provider's type becomes `BackupTarget`; the "saved in app
  storage" flag moves onto the interface or a small shared mixin. One test for
  the new target (save, overwrite, delete).
  - Known ceiling: these backups live inside the app and disappear with it.
    Showing them in the Files app would also expose the notes database, so that
    is left as an open decision (below).
- **Document scanner.** No change for the first build:
  `MlKitDocumentScanner.isSupported` is already false off Android, so the
  entry point is hidden.
- **Comments** that say "Android-only app" in `device_storage.dart` and
  `device_health.dart` get corrected.

## Phase 5: first run on the Mac

One-time setup:

1. Install Xcode from the App Store, open it once, accept the licence, install
   the iOS platform.
2. Install Flutter (same version as CI) and CocoaPods (`brew install cocoapods`).
3. `flutter doctor` until the Xcode and CocoaPods lines are green.

Build and install:

1. `git clone` / `git pull`, `git checkout iPadOS-build`.
2. `flutter pub get`, then `cd ios && pod install`.
3. Open `ios/Runner.xcworkspace` in Xcode. Runner target, Signing &
   Capabilities: tick automatic signing and choose your Apple ID as the team.
   With a free Apple ID the bundle id may need to be made unique (for example
   `com.<yourname>.margo`); do not commit that change.
4. On the iPad: connect by cable, tap Trust, then enable Settings > Privacy &
   Security > Developer Mode (the iPad restarts).
5. `flutter run --release` (a debug build cannot be launched from the home
   screen without the Mac attached).
6. First launch only: Settings > General > VPN & Device Management > trust the
   developer certificate.

With a free Apple ID the app stops launching after 7 days; run step 5 again.

## Phase 6: on-device test checklist

Ink (the part that decides whether the port is worth shipping):

- [ ] Pen strokes draw; palm resting on the screen is rejected.
- [ ] Does the ESR pencil arrive as a stylus or as a finger? If as a stylus
      with a constant pressure value, strokes come out uniform width: check
      `reportsPressure` in `lib/editor/input/scene_pointer_listener.dart`.
- [ ] Ink latency feels acceptable next to Apple Notes.
- [ ] Two-finger pan and pinch, finger-pan mode, hand tool.
- [ ] Erasing: neither Android eraser gesture exists on iPad (no eraser end,
      no side button), so only the toolbar eraser works. Decide if that is
      enough.

Everything else:

- [ ] Notes persist across a restart (Isar).
- [ ] PDF import and rendering; image import.
- [ ] Handwriting recognition model downloads and recognises (ML Kit).
- [ ] OCR on an imported image; date extraction; language ID.
- [ ] LLM model download completes (free-space check, background download).
- [ ] LLM loads and answers on the lite profile; watch for the app being killed
      for memory. If it is, test again without/with the memory entitlements.
- [ ] Lecture recording continues with the screen locked; playback and seek.
- [ ] Backup runs and restore reads the file back.
- [ ] Share / export (PDF, Anki).
- [ ] Split View and rotation do not break layouts.

## Later, not needed for the first build

- Document scanning with Apple's VisionKit behind `DocumentScannerPort`.
- Apple Pencil extras (double-tap, squeeze, hover, high-rate samples) via the
  `stylet` package or a small channel, only if testing shows the need.
- TestFlight and App Store work: paid developer account, cloud-AI consent
  screen (guideline 5.1.2(i)), privacy manifest, excluding model files from
  iCloud backup, the ModulusPro commercial licence.

## Open decisions

1. **Where backups live on iOS.** Default in this plan: inside the app's
   Documents folder (simple, automatic, lost if the app is deleted).
   Alternative: a save dialog into the Files app, which survives deletion but
   needs a tap each time.
2. **iPad only or iPhone too.** Default: a universal build, tested on iPad
   only. iPhone layouts and low-RAM iPhones are untested.

## Risks

- **Unverified until CI or a Mac builds it.** Static linking of ML Kit and the
  LiteRT-LM runtime together is the most likely place for link errors.
- **CocoaPods** goes read-only on 2 December 2026. Existing pod versions should
  remain installable; future ML Kit updates depend on Google moving to Swift
  Package Manager.
- **Memory.** iOS kills apps well below total RAM. The lite profile on a 6 GB
  iPad is the tight case and has not been measured.
- **Free Apple ID limits.** 7-day expiry, and possibly no memory entitlements.
