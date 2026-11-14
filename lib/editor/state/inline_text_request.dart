import 'package:flutter_riverpod/legacy.dart';

import 'scene_controller.dart';

/// The id of a text element someone outside the canvas (the selection bar's
/// "Edit text") wants opened for typing on the page. The canvas for that page
/// picks it up, opens its inline editor on it, and clears it back to null.
final inlineTextEditRequestProvider =
    StateProvider.family<String?, ScenePageKey>((ref, key) => null);
