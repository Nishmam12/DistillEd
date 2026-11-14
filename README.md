# Margo

A beefed up notepad app

## Platforms

**Android only.** The on-device AI (LiteRT-LM, ML Kit) and several platform
channels (`MainActivity.kt`) exist only there. There is no iOS project: the
`ios/` folder, if present, holds files Flutter regenerates and is not buildable.
Supporting iOS would mean `flutter create --platforms=ios .` plus ports of those
channels and the model runtime.

## Build

```bash
flutter pub get
flutter run                                   # debug on a device
flutter build apk --release                   # signs with the debug key unless
                                              # android/key.properties exists
flutter build apk --release -PrequireReleaseSigning=true   # fails without it
flutter build appbundle --release -PrequireReleaseSigning=true   # the Play upload
tool/check_16kb_alignment.sh build/app/outputs/flutter-apk/app-debug.apk
```

Release signing reads `android/key.properties` (gitignored):
`storeFile`, `storePassword`, `keyAlias`, `keyPassword`.

R8 shrinking is off on purpose (see `android/app/build.gradle.kts`): turning it on
needs keep rules for the on-device ML libraries and a run on a real device.

## Docs

`docs/ARCHITECTURE.md` and `docs/AI_PIPELINE_PLAN.md`.
