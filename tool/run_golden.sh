#!/usr/bin/env bash
# Runs the embedding golden test on a device (docs/TECH_MIGRATION_PLAN.md, phase 4.1).
# integration_test must not be in the app's pubspec (it breaks release builds), so this
# adds it for one run and restores pubspec.yaml and pubspec.lock afterwards.
# Usage: tool/run_golden.sh <device-id> [extra flutter test args]
# Always uses --no-uninstall. Afterwards reinstall the normal debug build: the test
# installs the harness as the app.
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?usage: tool/run_golden.sh <device-id> [args]}"; shift || true
bak="$(mktemp -d)"
cp pubspec.yaml "$bak/pubspec.yaml"; cp pubspec.lock "$bak/pubspec.lock"
restore() { cp "$bak/pubspec.yaml" pubspec.yaml; cp "$bak/pubspec.lock" pubspec.lock; rm -rf "$bak"; flutter pub get >/dev/null; }
trap restore EXIT
flutter pub add 'dev:integration_test:{"sdk":"flutter"}' >/dev/null
flutter test integration_test/embedding_golden_test.dart -d "$device" --no-uninstall --no-pub "$@"
