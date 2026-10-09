// Opening the Ask surface is the moment the student is about to type a question,
// which is exactly when the on-device model should start loading: the 3.6–17 s
// cold start then overlaps the typing instead of following the Enter key.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/presentation/ai_providers.dart';
import 'package:inkflow/features/ai/presentation/sidebar/ai_ask_view.dart';
import 'package:inkflow/features/ai/presentation/widgets/ai_scope_picker.dart';

void main() {
  const key = (notebookId: 1, pageId: 7);

  testWidgets('opening the Ask surface warms the on-device model, once',
      (tester) async {
    var warmups = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          localModelWarmerProvider.overrideWithValue(() => warmups++),
          pageImportGroupProvider(key).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiAskView(pageKey: key, onInsertNote: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(warmups, 1);
  });
}
