// Isar collection representing a notebook with metadata.

import 'package:isar_community/isar.dart';

import '../../../../domain/model/page_size.dart';

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
  /// 1 = single page (bounded, zoom limited to 50–300%), 2 = continuous
  /// (pages stacked top to bottom, scrolled through). Defaults to infinite.
  /// Append only: an older build treats anything but 1 as infinite.
  int layoutMode = 0;

  /// Index into [PageSizeKind.values]: the paper the pages are laid out on in
  /// the page layouts. 0 = fit screen, which is what every notebook made
  /// before real sizes keeps; new notebooks start at A4 (set on creation).
  /// Added 2026-11-14; an older build ignores it.
  int pageSize = 0;

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

  /// Hidden (Phase 6 note lock): kept out of the notes list, search, links,
  /// previews and cloud calls, and opened only after the device's fingerprint
  /// or screen lock. Not encrypted; the interface says "hidden", never
  /// "encrypted". Additive; an older build shows the note as usual.
  bool hidden = false;

  /// Convenience for the many call sites that only care whether it is live.
  @ignore
  bool get isInTrash => deletedAt != null;
}
