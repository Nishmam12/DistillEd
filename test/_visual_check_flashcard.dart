// Throwaway visual-check harness — NOT part of the suite, delete after use.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/core/theme/app_theme.dart';
import 'package:inkflow/features/ai/data/flashcards/flashcard_store.dart';
import 'package:inkflow/features/ai/data/llm/device_storage.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/data/llm/model_download_manager.dart';
import 'package:inkflow/features/ai/domain/ai_provider.dart';
import 'package:inkflow/features/ai/domain/features/flashcard_generator.dart';
import 'package:inkflow/features/ai/domain/models/flashcard.dart';
import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/flashcard_notifier.dart';
import 'package:inkflow/features/ai/presentation/flashcards/flashcard_sheet.dart';

class _NoopProvider implements AiProvider {
  @override
  AiCapabilities get capabilities => const AiCapabilities(
      modelId: 'noop', displayName: 'noop', contextWindowTokens: 4096, isLocal: true);
  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) => throw UnimplementedError();
  @override
  Future<List<double>> embed(String text) => throw UnimplementedError();
}

class _NoopStore implements FlashcardStore {
  @override
  Future<void> replaceForPage(int n, int p, List<Flashcard> c) async {}
  @override
  Future<List<Flashcard>> forNotebook(int n) async => const [];
  @override
  Future<List<Flashcard>> forPage(int p) async => const [];
}

class _FakeInstaller implements ModelInstaller {
  @override
  Future<bool> isInstalled(String modelId) async => true;
  @override
  Future<void> install({
    required LlmModelSpec spec,
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> uninstall(String modelId) async {}
}

class _FakeStorage implements DeviceStorage {
  @override
  Future<int> freeBytes() async => 1 << 62;
}

class _FixedFlashcards extends FlashcardNotifier {
  _FixedFlashcards(List<Flashcard> cards)
      : super(
          generator: FlashcardGenerator(provider: _NoopProvider()),
          store: _NoopStore(),
          downloads: ModelDownloadManager(installer: _FakeInstaller(), storage: _FakeStorage()),
        ) {
    state = FlashcardReady(cards, deckName: 'Cell Biology');
  }
}

Flashcard card(String front, String back) => Flashcard(
    front: front, back: back, notebookId: 1, pageId: 1, createdAt: DateTime(2026));

void main() {
  testWidgets('capture flashcard sheet front + back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flashcardNotifierProvider.overrideWith((ref) => _FixedFlashcards([
                card('What is the function of mitochondria?',
                    'It generates most of the cell\'s ATP through aerobic respiration — the "powerhouse of the cell."'),
                card('Define osmosis',
                    'The movement of water molecules across a semipermeable membrane from low to high solute concentration.'),
              ])),
        ],
        child: MaterialApp(
          theme: AppTheme.warmTheme,
          builder: (context, child) => RepaintBoundary(key: boundaryKey, child: child!),
          home: Scaffold(
            backgroundColor: const Color(0xFFF4ECE1),
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showFlashcardSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Future<void> shoot(String name) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await tester.runAsync(() async {
        final f = await File(
                'C:/Users/afnan/AppData/Local/Temp/claude/c--Users-afnan-Desktop-Projects-InkDot/99bb4787-3588-4a88-b0cb-dc231313a6d1/scratchpad/$name.png')
            .create(recursive: true);
        await f.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    await shoot('flashcard_front');

    // Tap the card to flip to the back.
    await tester.tap(find.text('What is the function of mitochondria?'));
    await tester.pumpAndSettle();
    await shoot('flashcard_back');
  });
}
