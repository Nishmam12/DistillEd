// Persistence for the element library. The library is a single JSON document
// (a list of items, each a named cluster of encoded scene elements). It is tiny
// and read/written whole, so a JSON file is simpler than an Isar collection and
// keeps library items portable.
//
// [InMemoryLibraryRepository] backs tests and the dev playground;
// [FileLibraryRepository] persists to a JSON file (path injected, so it is
// testable against a temp directory without path_provider).

import 'dart:convert';
import 'dart:io';

import '../../domain/model/library_item.dart';
import 'scene_element_codec.dart';

abstract class LibraryRepository {
  Future<List<LibraryItem>> load();
  Future<void> saveAll(List<LibraryItem> items);
}

/// Shared (de)serialisation so both implementations and tests agree on format.
class LibraryJson {
  LibraryJson._();

  static Map<String, dynamic> encodeItem(LibraryItem item) => {
        'id': item.id,
        'name': item.name,
        'createdAt': item.createdAt.toIso8601String(),
        'elements': SceneElementCodec.encodeList(item.elements),
      };

  static LibraryItem decodeItem(Map<String, dynamic> m) => LibraryItem(
        id: m['id'] as String,
        name: m['name'] as String? ?? 'Item',
        createdAt:
            DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime(2020),
        elements: SceneElementCodec.decodeList(
            (m['elements'] as List?) ?? const []),
      );

  static String encode(List<LibraryItem> items) => jsonEncode({
        'version': 1,
        'items': [for (final i in items) encodeItem(i)],
      });

  static List<LibraryItem> decode(String source) {
    if (source.trim().isEmpty) return const [];
    final root = jsonDecode(source);
    final list = (root is Map ? root['items'] : root) as List? ?? const [];
    return [
      for (final m in list) decodeItem(Map<String, dynamic>.from(m as Map)),
    ];
  }
}

class InMemoryLibraryRepository implements LibraryRepository {
  List<LibraryItem> _items;
  InMemoryLibraryRepository([List<LibraryItem>? initial])
      : _items = List.of(initial ?? const []);

  @override
  Future<List<LibraryItem>> load() async => List.of(_items);

  @override
  Future<void> saveAll(List<LibraryItem> items) async => _items = List.of(items);
}

class FileLibraryRepository implements LibraryRepository {
  final File file;
  FileLibraryRepository(this.file);

  @override
  Future<List<LibraryItem>> load() async {
    if (!await file.exists()) return const [];
    try {
      return LibraryJson.decode(await file.readAsString());
    } catch (_) {
      // A damaged file must not take the whole library screen down. It is kept
      // beside the original name so it can be recovered by hand, and the library
      // starts empty (the next save writes a fresh file).
      try {
        await file.rename('${file.path}.bad');
      } catch (_) {}
      return const [];
    }
  }

  @override
  Future<void> saveAll(List<LibraryItem> items) async {
    await file.parent.create(recursive: true);
    // Atomic-ish write: tmp then rename, matching the .ink storage convention.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(LibraryJson.encode(items), flush: true);
    await tmp.rename(file.path);
  }
}
