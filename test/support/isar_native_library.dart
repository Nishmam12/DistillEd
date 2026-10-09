// Tests that open a real Isar database need the native core. The
// isar_community_flutter_libs package ships a copy for each platform, and this
// finds the one for the platform the tests run on.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

/// The path of the Isar core library for this platform, or null when it cannot
/// be found (a test then skips, and says why).
///
/// `flutter test` does not give the test isolate a package resolver, so the
/// location is read from `.dart_tool/package_config.json` directly.
Future<String?> isarNativeLibrary() async {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  final entry = packages
      .cast<Map>()
      .where((p) => p['name'] == 'isar_community_flutter_libs');
  if (entry.isEmpty) return null;
  final rootUri = Uri.parse(entry.first['rootUri'] as String);
  final root = rootUri.isAbsolute
      ? File.fromUri(rootUri).path
      : File.fromUri(config.parent.uri.resolveUri(rootUri)).path;
  final candidate = switch (Abi.current()) {
    Abi.linuxX64 => '$root/linux/libisar.so',
    Abi.windowsX64 => '$root/windows/isar.dll',
    Abi.macosX64 || Abi.macosArm64 => '$root/macos/libisar.dylib',
    _ => null,
  };
  return candidate != null && File(candidate).existsSync() ? candidate : null;
}

/// Points Isar at [library], as returned by [isarNativeLibrary].
Future<void> initIsarForTests(String library) =>
    Isar.initializeIsarCore(libraries: {Abi.current(): library});
