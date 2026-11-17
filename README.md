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

## Cloud AI

Settings → AI Models → Cloud AI provider configures the default connection
for cloud page reading and Research. The default also appears in the AI
panel's answer-model picker. Use "Add an AI" for additional connections whose
keys are used only when their models are selected to answer; `/model` opens
the same picker. Cloud-first uses the configured default for answers when
the picker is on Auto. Explicit model choices take precedence.

Keys are kept in the device's secure storage. Sending text follows the cloud
privacy and confirmation settings; background image reading requires the
default connection and permission to use cloud AI without asking. The Render
gateway has been removed. Research has Calculator and Wikipedia tools;
Margo's bundled cloud models are not available yet.

## Docs

`docs/ARCHITECTURE.md` and `docs/AI_PIPELINE_PLAN.md`.
