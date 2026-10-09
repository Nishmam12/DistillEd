// Bridges the unified [SceneExporter] (byte/string generation) to the system
// share sheet. One call per format; returns false when there was nothing to
// export. Sharing itself is delegated to the existing [ExportShareService].

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/model/scene_element.dart';
import '../../editor/render/scene_exporter.dart';
import '../../editor/render/scene_image_cache.dart';
import 'export_share_service.dart';

class SceneExportService {
  SceneExportService._();

  /// Loads any referenced images into [cache] and returns its resolver, so
  /// exports render real bitmaps rather than placeholders.
  static Future<ui.Image? Function(String)?> _resolver(
      List<SceneElement> elements, SceneImageCache? cache) async {
    if (cache == null) return null;
    await cache.ensure([
      for (final e in elements)
        if (e is ImageElement) e.relativeImagePath,
    ]);
    return cache.get;
  }

  static Future<bool> sharePng(
    List<SceneElement> elements, {
    String title = 'DistillEd',
    Color background = Colors.white,
    SceneImageCache? imageCache,
  }) async {
    final png = await SceneExporter.toPng(elements,
        background: background,
        imageResolver: await _resolver(elements, imageCache));
    if (png == null) return false;
    await ExportShareService.sharePng(png, title);
    return true;
  }

  static Future<bool> sharePdf(
    List<SceneElement> elements, {
    String title = 'DistillEd',
    Color background = Colors.white,
    SceneImageCache? imageCache,
  }) async {
    final pdf = await SceneExporter.toPdf(elements,
        background: background,
        imageResolver: await _resolver(elements, imageCache));
    if (pdf == null) return false;
    await ExportShareService.sharePdf(pdf, title);
    return true;
  }

  /// Shares every page of a notebook as one PDF. Returns false when the whole
  /// notebook is empty.
  static Future<bool> shareNotebookPdf(
    List<List<SceneElement>> pages, {
    String title = 'DistillEd',
    Color background = Colors.white,
    SceneImageCache? imageCache,
    void Function(int done, int total)? onProgress,
  }) async {
    // One resolver pass over every page's images, so a picture reused across
    // pages is decoded once rather than per page.
    final all = [for (final page in pages) ...page];
    final pdf = await SceneExporter.toNotebookPdf(
      pages,
      background: background,
      imageResolver: await _resolver(all, imageCache),
      onProgress: onProgress,
    );
    if (pdf == null) return false;
    await ExportShareService.sharePdf(pdf, title);
    return true;
  }

  /// Shares the page as an SVG with its pictures embedded, so the file opens
  /// correctly outside the app. A picture whose file cannot be read is drawn as
  /// the canvas placeholder.
  static Future<bool> shareSvg(
    List<SceneElement> elements, {
    String title = 'DistillEd',
    SceneImageCache? imageCache,
  }) async {
    if (elements.isEmpty) return false;
    final svg = SceneExporter.toSvg(
      elements,
      images: await _pictureBytes(elements, imageCache?.baseDir),
    );
    await ExportShareService.shareFile(
      bytes: Uint8List.fromList(utf8.encode(svg)),
      filename: '${title}_${DateTime.now().millisecondsSinceEpoch}.svg',
      mimeType: 'image/svg+xml',
    );
    return true;
  }

  /// The bytes of each picture on the page, read from [baseDir], keyed by the
  /// relative path the element stores. A picture that cannot be read is left out.
  static Future<Map<String, Uint8List>> _pictureBytes(
    List<SceneElement> elements,
    String? baseDir,
  ) async {
    if (baseDir == null) return const {};
    final bytes = <String, Uint8List>{};
    for (final e in elements) {
      if (e is! ImageElement || e.relativeImagePath.isEmpty) continue;
      if (bytes.containsKey(e.relativeImagePath)) continue;
      try {
        bytes[e.relativeImagePath] = await File(
          SceneImageCache.resolvePath(baseDir, e.relativeImagePath),
        ).readAsBytes();
      } catch (_) {
        // Left out: the element is drawn as a placeholder.
      }
    }
    return bytes;
  }
}
