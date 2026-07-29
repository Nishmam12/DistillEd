// Cross-feature search wiring.
//
// The page-text store is written by the AI feature's extraction hook and read
// by the home list and in-note search, so its provider lives in `core/` rather
// than inside either feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/persistence/page_text_store.dart';

/// Durable per-page searchable text. Override with [InMemoryPageTextStore] in
/// tests and the dev playground.
final pageTextStoreProvider =
    Provider<PageTextStore>((ref) => IsarPageTextStore());
