// Fresh scene-element ids.
//
// Lives in `domain/model` so both the editor UI (`editorNewId`) and the state
// layer (page duplication) mint ids the same way without the state layer having
// to import a UI file.

import 'dart:math' as math;

/// A fresh, collision-resistant element id.
///
/// Microsecond timestamp plus 30 bits of randomness: the timestamp keeps ids
/// roughly sortable by creation, the random suffix survives two ids being
/// minted inside the same microsecond (which a bulk duplicate does routinely).
String newElementId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 30)}';
