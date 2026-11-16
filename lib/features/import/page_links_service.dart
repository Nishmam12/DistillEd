// The links and contents entries kept for an imported PDF page picture.
//
// Read from the sidecar the import wrote (`StoragePaths.pdfLinksSidecar`) and
// nothing else: the PDF is not kept, so a page imported before links were kept
// simply has none. Never reads or recognises a picture.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_paths.dart';
import '../../domain/model/page_links.dart';
import '../../editor/state/scene_controller.dart' show appDocsPathProvider;

class PageLinksService {
  PageLinksService({required this.docsDir});

  final String docsDir;
  final Map<String, PageLinks> _cache = {};

  /// Links and contents entries of the picture at [relativeImagePath]; none
  /// when there is no file. Never throws.
  Future<PageLinks> linksFor(String relativeImagePath) async {
    final hit = _cache[relativeImagePath];
    if (hit != null) return hit;
    if (!StoragePaths.isSafeRelativePath(relativeImagePath)) {
      return PageLinks.empty;
    }
    final file =
        File(StoragePaths.pdfLinksSidecar('$docsDir/$relativeImagePath'));
    PageLinks links;
    try {
      links = await file.exists()
          ? PageLinks.decode(await file.readAsString())
          : PageLinks.empty;
    } catch (_) {
      links = PageLinks.empty;
    }
    _cache[relativeImagePath] = links;
    if (_cache.length > 128) _cache.remove(_cache.keys.first);
    return links;
  }
}

final pageLinksServiceProvider = Provider<PageLinksService>(
    (ref) => PageLinksService(docsDir: ref.watch(appDocsPathProvider)));
