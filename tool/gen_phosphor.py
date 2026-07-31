"""Generate a plain-IconData replacement for phosphor_flutter's Regular style.

phosphor_flutter 2.1.0 declares `class PhosphorIconData extends IconData`, which
cannot compile against Flutter 3.44+ where IconData became a final class.
The app only uses PhosphorIconsRegular, so we emit that one style as plain
const IconData values backed by the bundled Phosphor.ttf font.
"""
import re
import sys

SRC = r"C:\Users\nabil\AppData\Local\Pub\Cache\hosted\pub.dev\phosphor_flutter-2.1.0\lib\src\phosphor_icons_regular.dart"
DST = r"g:\Notepad-\lib\core\icons\phosphor_icons_regular.dart"

DECL = re.compile(r"^\s*static const (\w+) = PhosphorFlatIconData\((0x[0-9a-fA-F]+), 'Regular'\);")
DOC = re.compile(r"^\s*/// (.*)$")

out = []
pending_doc = None
count = 0

with open(SRC, encoding="utf-8") as f:
    for line in f:
        d = DOC.match(line)
        if d:
            pending_doc = d.group(1)
            continue
        m = DECL.match(line)
        if m:
            name, code = m.group(1), m.group(2)
            if pending_doc:
                out.append(f"  /// {pending_doc}")
            out.append(
                f"  static const {name} = IconData({code},\n"
                f"      fontFamily: _family, matchTextDirection: true);"
            )
            out.append("")
            count += 1
        pending_doc = None

if count == 0:
    sys.exit("ERROR: no icon declarations parsed - source format changed")

header = '''// GENERATED FILE - DO NOT EDIT BY HAND.
//
// Local replacement for `package:phosphor_flutter` (2.1.0), which cannot compile
// against Flutter 3.44+: it declares `class PhosphorIconData extends IconData`,
// and IconData became a `final class` in 3.44. Upstream has no released fix
// (phosphor-icons/flutter issues #61/#64/#66 open).
//
// Only the Regular style is reproduced - it is the only style this app uses.
// Values are plain `IconData` constants backed by assets/fonts/Phosphor.ttf,
// declared in pubspec.yaml as the `PhosphorRegular` family. Because the font
// ships with the app rather than a package, no `fontPackage` is set.
//
// Regenerate with: tool/gen_phosphor.py

import 'package:flutter/widgets.dart';

const String _family = 'PhosphorRegular';

@staticIconProvider
class PhosphorIconsRegular {
  const PhosphorIconsRegular();

'''

body = "\n".join(out).rstrip() + "\n}\n"

with open(DST, "w", encoding="utf-8", newline="\n") as f:
    f.write(header + body)

print(f"generated {count} icons -> {DST}")
