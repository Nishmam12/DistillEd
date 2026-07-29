// Presentation model for one row of the Notes list.
//
// Deliberately not an Isar entity: a card mixes notebook metadata with a
// resolved preview (a page thumbnail on disk, or recognised text from the RAG
// chunk index), and the widgets should never have to know where either came
// from. Pure and const-constructible, so the card widgets stay unit-testable.

import 'package:flutter/foundation.dart';

import '../../../../domain/model/scene_element.dart';
import '../../domain/models/notebook.dart';

/// What the right-hand preview of a card renders.
enum NoteType {
  /// The note's own first page, painted live from its scene elements.
  scene,

  /// A rendered page thumbnail fills the preview.
  image,

  /// A snippet of recognised text.
  text,

  /// A snippet whose lines are bullets / checklist items.
  checklist,
}

@immutable
class NoteCardData {
  const NoteCardData({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pages,
    required this.type,
    this.previewScene = const [],
    this.previewImage,
    this.previewText = '',
    this.pinned = false,
    this.folderId,
    this.tags = const [],
  });

  final int id;
  final String title;
  final DateTime createdAt;
  final int pages;
  final NoteType type;

  /// The note's first page, for painting a live miniature.
  final List<SceneElement> previewScene;

  /// Absolute path to a page thumbnail, when one has been rendered.
  final String? previewImage;

  /// Recognised text for the note, used when there is no thumbnail.
  final String previewText;

  final bool pinned;

  /// The folder this note is filed in, or null when unfiled.
  final int? folderId;

  /// Normalised (lowercase) labels, as stored.
  final List<String> tags;

  /// Builds a card from a notebook plus whatever preview could be resolved.
  ///
  /// The type follows the data, best first: the note's own page, then a
  /// rendered thumbnail, then text (bulleted or not). A note with none of those
  /// still renders as [NoteType.text] — the preview falls back to the title,
  /// which every note has.
  /// [pinned] defaults to the notebook's own flag; the named argument stays so
  /// tests can build a pinned card without a notebook fixture.
  factory NoteCardData.fromNotebook(
    Notebook notebook, {
    List<SceneElement> previewScene = const [],
    String? previewImage,
    String previewText = '',
    bool? pinned,
  }) {
    final text = previewText.trim();
    return NoteCardData(
      id: notebook.id,
      title: notebook.title,
      createdAt: notebook.createdAt,
      pages: notebook.pageCount,
      type: switch ((previewScene.isNotEmpty, previewImage != null)) {
        (true, _) => NoteType.scene,
        (_, true) => NoteType.image,
        _ => _looksLikeChecklist(text) ? NoteType.checklist : NoteType.text,
      },
      previewScene: previewScene,
      previewImage: previewImage,
      previewText: text,
      pinned: pinned ?? notebook.pinned,
      folderId: notebook.folderId,
      tags: List.unmodifiable(notebook.tags),
    );
  }

  /// `7/26/21` — the compact form used across the list's metadata.
  String get dateLabel {
    final year = (createdAt.year % 100).toString().padLeft(2, '0');
    return '${createdAt.month}/${createdAt.day}/$year';
  }

  String get pageLabel => '$pages ${pages == 1 ? 'page' : 'pages'}';

  /// The preview snippet as display lines, bullet markers stripped.
  ///
  /// Capped at [max] because the preview area only fits a handful of lines and
  /// a long chunk of OCR text would otherwise be laid out and thrown away.
  List<String> previewLines({int max = 4}) {
    final lines = <String>[];
    for (final raw in previewText.split('\n')) {
      final line = _stripMarker(raw.trim());
      if (line.isEmpty) continue;
      lines.add(line);
      if (lines.length == max) break;
    }
    return lines;
  }

  /// Whether this note should survive the search box's [query].
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return title.toLowerCase().contains(needle) ||
        previewText.toLowerCase().contains(needle);
  }

  static final _markerPattern = RegExp(r'^(?:[-*•·]|\[[ xX]?\]|\d+[.)])\s+');

  static String _stripMarker(String line) =>
      line.replaceFirst(_markerPattern, '').trim();

  static bool _looksLikeChecklist(String text) {
    final lines = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (lines.length < 2) return false;
    final marked = lines.where(_markerPattern.hasMatch).length;
    // A majority of marked lines: one stray dash in a paragraph is not a list.
    return marked * 2 > lines.length;
  }
}
