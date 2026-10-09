// Loads and caches the `dart:ui.Image`s referenced by [ImageElement]s, so the
// painter can draw real bitmaps instead of placeholders.
//
// Backed by [RefCountedCache] so each decoded image is disposed exactly once
// (the "Cannot clone a disposed image" class of crash): the cache owns one
// reference per loaded path and disposes everything on [dispose]. Decoding is
// async; [version] bumps on each successful load so painters know to repaint.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../data/persistence/ref_counted_cache.dart';

class SceneImageCache extends ChangeNotifier {
  /// Absolute directory that relative image paths resolve against (the app
  /// documents dir in production; '' in the dev playground, which has no images).
  final String baseDir;
  final Future<Uint8List> Function(String absolutePath) _readBytes;
  final Future<ui.Image> Function(Uint8List bytes) _decode;

  final RefCountedCache<ui.Image> _cache =
      RefCountedCache<ui.Image>((img) => img.dispose());
  // Insertion order doubles as recency: [get] moves a hit to the end, so the
  // first key is the least recently drawn.
  final Map<String, ui.Image> _ready = {};
  final Set<String> _loading = {};
  // Paths that failed to read/decode. Without this, build() would retry them
  // (read + decode) on every frame.
  final Set<String> _failed = {};
  bool _disposed = false;

  /// Decoded bitmaps kept at once. A long PDF would otherwise hold every page
  /// ever shown, at full resolution, until the process dies.
  // ponytail: count-bounded, not byte-bounded; switch to a byte budget if
  // mixed huge/small images make the count a poor proxy.
  static const int maxEntries = 32;
  int _version = 0;

  SceneImageCache({
    required this.baseDir,
    Future<Uint8List> Function(String absolutePath)? readBytes,
    Future<ui.Image> Function(Uint8List bytes)? decode,
  })  : _readBytes = readBytes ?? _defaultReadBytes,
        _decode = decode ?? SceneImageCache.decode;

  /// Increments each time an image finishes loading; used by CustomPainters'
  /// shouldRepaint to refresh once a bitmap becomes available.
  int get version => _version;

  /// The decoded image for [relativePath], or null if not loaded yet.
  ui.Image? get(String relativePath) {
    final image = _ready.remove(relativePath);
    if (image != null) _ready[relativePath] = image; // mark most recent
    return image;
  }

  /// Forgets past failures so the next [ensure] retries them (e.g. a file that
  /// had not finished being written when first read).
  void retryFailed() => _failed.clear();

  /// Ensures every path in [relativePaths] is decoded and cached. Idempotent and
  /// safe to call from build(): in-flight and ready paths are skipped.
  Future<void> ensure(Iterable<String> relativePaths) async {
    for (final p in relativePaths) {
      if (p.isEmpty ||
          _ready.containsKey(p) ||
          _loading.contains(p) ||
          _failed.contains(p)) {
        continue;
      }
      _loading.add(p);
      try {
        final bytes = await _readBytes(resolvePath(baseDir, p));
        final image = await _decode(bytes);
        if (_disposed) {
          image.dispose(); // finished after the cache went away
          continue;
        }
        _ready[p] = _cache.acquire(p, () => image);
        while (_ready.length > maxEntries) {
          final oldest = _ready.keys.first;
          _ready.remove(oldest);
          _cache.release(oldest); // disposes the bitmap
        }
        _version++;
        notifyListeners();
      } catch (_) {
        // Leave unloaded; the painter falls back to a placeholder.
        _failed.add(p);
      } finally {
        _loading.remove(p);
      }
    }
  }

  /// Resolves a stored relative path against [baseDir]. Absolute paths (and
  /// Windows drive paths) are returned unchanged.
  static String resolvePath(String baseDir, String relative) {
    final isAbsolute = relative.startsWith('/') ||
        relative.startsWith('\\') ||
        (relative.length > 1 && relative[1] == ':');
    if (isAbsolute || baseDir.isEmpty) return relative;
    final sep = baseDir.endsWith('/') || baseDir.endsWith('\\') ? '' : '/';
    return '$baseDir$sep$relative';
  }

  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<Uint8List> _defaultReadBytes(String absolutePath) =>
      File(absolutePath).readAsBytes();

  @override
  void dispose() {
    _disposed = true;
    _cache.disposeAll();
    _ready.clear();
    super.dispose();
  }
}
