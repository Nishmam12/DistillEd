#!/usr/bin/env bash
# Fails if any 64-bit native library in an APK is not 16 KB page-size ready.
# Android 15+ devices may use 16 KB pages; Play requires apps targeting 15+ to
# support them. A library is ready when every LOAD segment is aligned to >= 0x4000.
#
#   tool/check_16kb_alignment.sh build/app/outputs/flutter-apk/app-release.apk
set -euo pipefail
apk="${1:?usage: $0 path/to/app.apk}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
unzip -q "$apk" 'lib/arm64-v8a/*.so' 'lib/x86_64/*.so' -d "$work" 2>/dev/null || true

bad=0
checked=0
while IFS= read -r so; do
  checked=$((checked + 1))
  # The p_align column of each LOAD line, e.g. 0x4000 or 0x1000.
  aligns="$(readelf -lW "$so" | awk '$1 == "LOAD" { print $NF }')"
  for a in $aligns; do
    if [ $((a)) -lt $((0x4000)) ]; then
      echo "NOT 16 KB aligned ($a): ${so#"$work"/}"
      bad=1
      break
    fi
  done
done < <(find "$work" -name '*.so' | sort)

echo "checked $checked libraries"
[ "$checked" -gt 0 ] || { echo "no 64-bit libraries found in $apk"; exit 1; }
exit $bad
