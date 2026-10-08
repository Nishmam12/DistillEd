// The dry run's copy of the active embedding model (docs/TECH_MIGRATION_PLAN.md,
// phase 4.5). Debug builds only: nothing ships this.
//
// A rollout to a model whose files are already on the device needs no download,
// so a dry run can switch between two models with no network. The copy holds the
// active model's bytes under the copy's names. Its id is its own, so its chunks
// are kept apart from the active model's, and its vectors are the same.

import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../llm/gemma_adapter.dart';
import 'embedder_adapter.dart';
import 'embedder_spec.dart';

Future<void>? _installing;

/// Registers a copy of the active model's files as the dry-run copy's.
///
/// The bytes are copied into the folder the plugin would download to, and
/// registered from there, so the installed check and the runtime both find them.
/// A call made while one runs joins it, so two presses never copy at once.
Future<void> installDryRunCopy() =>
    _installing ??= _install().whenComplete(() => _installing = null);

Future<void> _install() async {
  if (!kDebugMode) throw StateError('the dry-run copy is a debug tool');
  const source = EmbedderSpec.active;
  const copy = EmbedderSpec.dryRunCopy;
  final installer = EdgeAiEmbedderInstaller();
  if (!await installer.isInstalled(source)) {
    throw StateError('install ${source.displayName} before copying it');
  }
  if (await installer.isInstalled(copy)) return;

  await GemmaBootstrap.ensureInitialized();
  final modelPath = await FlutterEdgeAi.getModelPath(copy.modelFilename);
  final tokenizerPath =
      await FlutterEdgeAi.getModelPath(copy.tokenizerFilename);
  await File(await FlutterEdgeAi.getModelPath(source.modelFilename))
      .copy(modelPath);
  await File(await FlutterEdgeAi.getModelPath(source.tokenizerFilename))
      .copy(tokenizerPath);
  await FlutterEdgeAi.installEmbedder()
      .modelFromFile(modelPath, filename: copy.modelFilename)
      .tokenizerFromFile(tokenizerPath, filename: copy.tokenizerFilename)
      .install();
}
