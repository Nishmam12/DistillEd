// One notebook as one file: the `.margo` format used to back notebooks up and
// to hand one to someone else.
//
// A `.margo` file is a zip:
//   manifest.json   the notebook's settings and every page's elements, in the
//                   same JSON the clipboard uses (SceneElementCodec)
//   notebook.md     a readable copy of the text: open it anywhere, even
//                   without Margo
//   media/<path>    the pictures and PDF pages the elements point at, under
//                   the same relative path they have in the app
//
// Everything here is pure (no files, no database), so the format can be tested
// on its own. Reading notebooks out of the app and back in is
// `backup_library.dart`.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/storage_paths.dart';
import '../../domain/model/scene_element.dart';
import '../persistence/scene_element_codec.dart';

/// A file that is not a `.margo` notebook, or one this build cannot read.
class NotebookArchiveException implements Exception {
  final String message;
  const NotebookArchiveException(this.message);
  @override
  String toString() => 'NotebookArchiveException: $message';
}

@immutable
class NotebookMeta {
  final String title;
  final int backgroundColor;
  final int templateIndex;
  final int layoutMode;

  /// [PageSizeKind] index. 0 (fit screen) for a backup from before page sizes.
  final int pageSize;
  final List<String> tags;
  final DateTime createdAt;

  const NotebookMeta({
    required this.title,
    required this.backgroundColor,
    required this.templateIndex,
    required this.layoutMode,
    this.pageSize = 0,
    required this.tags,
    required this.createdAt,
  });
}

@immutable
class PageSnapshot {
  final List<SceneElement> elements;

  /// What the AI read off the page (handwriting, typed text, PDF text). Goes
  /// into the readable copy; the app reads the page again after a restore.
  final String text;
  final String? importGroupId;
  final String? importSourceName;

  const PageSnapshot({
    required this.elements,
    this.text = '',
    this.importGroupId,
    this.importSourceName,
  });
}

@immutable
class NotebookSnapshot {
  /// The notebook's id where it was saved. Its files live under
  /// `notes/<sourceId>/`, which [remappedTo] moves to the id it gets on restore.
  final int sourceId;
  final NotebookMeta meta;
  final List<PageSnapshot> pages;

  /// File contents by relative path (`notes/12/imports/img_1.png`).
  final Map<String, Uint8List> media;

  const NotebookSnapshot({
    required this.sourceId,
    required this.meta,
    required this.pages,
    required this.media,
  });

  /// The same notebook with its own files moved from `notes/<sourceId>/` to
  /// `notes/<id>/`, for adding it to the app as notebook [id].
  NotebookSnapshot remappedTo(int id) {
    final from = 'notes/$sourceId/';
    final to = 'notes/$id/';
    String move(String path) =>
        path.startsWith(from) ? '$to${path.substring(from.length)}' : path;
    return NotebookSnapshot(
      sourceId: id,
      meta: meta,
      pages: [
        for (final p in pages)
          PageSnapshot(
            text: p.text,
            importGroupId: p.importGroupId,
            importSourceName: p.importSourceName,
            elements: [
              for (final e in p.elements)
                e is ImageElement
                    ? e.copyWith(relativeImagePath: move(e.relativeImagePath))
                    : e,
            ],
          ),
      ],
      media: {for (final m in media.entries) move(m.key): m.value},
    );
  }
}

class NotebookArchive {
  NotebookArchive._();

  static const String format = 'margo-notebook';
  static const int version = 1;
  static const String _manifest = 'manifest.json';
  static const String _markdown = 'notebook.md';
  static const String _mediaDir = 'media/';

  /// The `.margo` bytes for [snapshot].
  static Uint8List encode(NotebookSnapshot snapshot) {
    final archive = Archive()
      ..add(ArchiveFile.string(_manifest, jsonEncode(_manifestOf(snapshot))))
      ..add(ArchiveFile.string(_markdown, markdown(snapshot)));
    for (final m in snapshot.media.entries) {
      archive.add(ArchiveFile.bytes('$_mediaDir${m.key}', m.value));
    }
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  /// Reads a `.margo` file. Media whose path would land anywhere but inside
  /// the notebook's own folder is dropped: the file may come from anyone.
  ///
  /// Throws [NotebookArchiveException] when [bytes] is not a notebook.
  static NotebookSnapshot decode(Uint8List bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const NotebookArchiveException('Not a Margo notebook file.');
    }
    final manifestFile = zip.findFile(_manifest);
    if (manifestFile == null) {
      throw const NotebookArchiveException('Not a Margo notebook file.');
    }

    final Map<String, dynamic> m;
    try {
      m = jsonDecode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      throw const NotebookArchiveException('This notebook file is damaged.');
    }
    if (m['format'] != format) {
      throw const NotebookArchiveException('Not a Margo notebook file.');
    }
    if ((m['version'] as num? ?? 0) > version) {
      throw const NotebookArchiveException(
          'This notebook was saved by a newer Margo. Update the app to open it.');
    }

    try {
      final sourceId = (m['sourceId'] as num).toInt();
      final nb = m['notebook'] as Map<String, dynamic>;
      final own = 'notes/$sourceId/';
      final media = <String, Uint8List>{};
      for (final f in zip.files) {
        if (!f.isFile || !f.name.startsWith(_mediaDir)) continue;
        final rel = f.name.substring(_mediaDir.length);
        if (!rel.startsWith(own) || !StoragePaths.isSafeRelativePath(rel)) {
          continue;
        }
        media[rel] = Uint8List.fromList(f.content as List<int>);
      }

      return NotebookSnapshot(
        sourceId: sourceId,
        meta: NotebookMeta(
          title: nb['title'] as String? ?? 'Restored notebook',
          backgroundColor: (nb['backgroundColor'] as num? ?? 0xFFFFFFFF).toInt(),
          templateIndex: (nb['templateIndex'] as num? ?? 0).toInt(),
          layoutMode: (nb['layoutMode'] as num? ?? 0).toInt(),
          pageSize: (nb['pageSize'] as num? ?? 0).toInt(),
          tags: [for (final t in nb['tags'] as List? ?? const []) '$t'],
          createdAt: DateTime.tryParse(nb['createdAt'] as String? ?? '') ??
              DateTime.now(),
        ),
        pages: [
          for (final p in m['pages'] as List)
            PageSnapshot(
              text: (p as Map<String, dynamic>)['text'] as String? ?? '',
              importGroupId: p['importGroupId'] as String?,
              importSourceName: p['importSourceName'] as String?,
              elements:
                  SceneElementCodec.decodeList(p['elements'] as List? ?? const []),
            ),
        ],
        media: media,
      );
    } on NotebookArchiveException {
      rethrow;
    } catch (_) {
      throw const NotebookArchiveException('This notebook file is damaged.');
    }
  }

  /// A readable copy of what the notebook says, page by page.
  static String markdown(NotebookSnapshot s) {
    final b = StringBuffer('# ${s.meta.title}\n\n');
    if (s.meta.tags.isNotEmpty) {
      b.writeln(s.meta.tags.map((t) => '#$t').join(' '));
      b.writeln();
    }
    for (var i = 0; i < s.pages.length; i++) {
      final p = s.pages[i];
      b.writeln('## Page ${i + 1}');
      if (p.importSourceName != null) b.writeln('_From ${p.importSourceName}_');
      b.writeln();
      b.writeln(p.text.trim().isEmpty
          ? '_No text has been read from this page yet._'
          : p.text.trim());
      b.writeln();
    }
    return b.toString();
  }

  /// Changes whenever anything in the notebook does, and only then: what the
  /// backup compares to decide whether a notebook needs writing again.
  static String fingerprint(NotebookSnapshot s) {
    final media = [
      for (final m in s.media.entries) '${m.key}:${m.value.length}',
    ]..sort();
    final input = jsonEncode({'m': _manifestOf(s), 'media': media});
    return sha1.convert(utf8.encode(input)).toString();
  }

  static Map<String, Object?> _manifestOf(NotebookSnapshot s) => {
        'format': format,
        'version': version,
        'sourceId': s.sourceId,
        'notebook': {
          'title': s.meta.title,
          'backgroundColor': s.meta.backgroundColor,
          'templateIndex': s.meta.templateIndex,
          'layoutMode': s.meta.layoutMode,
          'pageSize': s.meta.pageSize,
          'tags': s.meta.tags,
          'createdAt': s.meta.createdAt.toIso8601String(),
        },
        'pages': [
          for (final p in s.pages)
            {
              'text': p.text,
              'importGroupId': ?p.importGroupId,
              'importSourceName': ?p.importSourceName,
              'elements': SceneElementCodec.encodeList(p.elements),
            },
        ],
      };
}
