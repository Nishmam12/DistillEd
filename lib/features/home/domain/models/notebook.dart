// Isar collection representing a notebook with metadata.

import 'package:isar/isar.dart';

part 'notebook.g.dart';

@collection
class Notebook {
  Id id = Isar.autoIncrement;

  late String title;

  late DateTime createdAt;

  late DateTime modifiedAt;

  @Index()
  int pageCount = 1;

  int backgroundColor = 0xFFFFFFFF;

  /// Index into [TemplateType.values] for this notebook's paper/page style.
  /// Defaults to 0 (TemplateType.blank).
  int templateIndex = 0;

  /// Canvas layout mode: 0 = infinite whiteboard (free pan/zoom),
  /// 1 = single page (bounded, zoom limited to 50–300%). Defaults to infinite.
  int layoutMode = 0;

  /// Pinned notes lead the home list under every sort order.
  @Index()
  bool pinned = false;

  /// The folder this notebook sits in, or null for "no folder".
  ///
  /// A nullable id rather than a link so an unfiled note costs nothing and a
  /// folder can be deleted without rewriting the notes inside it.
  @Index()
  int? folderId;

  /// Free-form labels, lowercased on write so filtering is case-insensitive
  /// without needing a second normalised column.
  ///
  /// Tags suit the capture-first-organise-later workflow: unlike folders they
  /// can be applied retroactively without moving anything.
  @Index(type: IndexType.value)
  List<String> tags = [];

  /// When this notebook was moved to the trash, or null while it is live.
  ///
  /// Soft delete: deleting from the home screen only stamps this field, so the
  /// notebook and every page, element and image it owns stay on disk and can be
  /// restored. The permanent delete runs from the Trash screen, or
  /// automatically once the retention window has passed.
  ///
  /// Indexed because every home-screen load filters on it.
  @Index()
  DateTime? deletedAt;

  /// Convenience for the many call sites that only care whether it is live.
  @ignore
  bool get isInTrash => deletedAt != null;
}
