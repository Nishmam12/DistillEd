// The words selected on a page picture with the select tool's Text mode. The
// canvas sets it while the finger or pen drags; the editor's text bar reads it
// for Copy, Highlight, Ask the AI and Search.

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/geometry/word_geometry.dart';
import '../../domain/model/page_words.dart';
import 'scene_controller.dart' show ScenePageKey;

class PageTextSelection {
  final ScenePageKey key;

  /// The picture the words are on.
  final String imageId;
  final PageWords words;

  /// Indexes into [words], in reading order.
  final List<int> indexes;

  const PageTextSelection({
    required this.key,
    required this.imageId,
    required this.words,
    required this.indexes,
  });

  String get text => textOf(words, indexes);
}

final pageTextSelectionProvider =
    StateProvider<PageTextSelection?>((ref) => null);
