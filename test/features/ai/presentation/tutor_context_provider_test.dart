import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:margo/core/providers/secret_store.dart';
import 'package:margo/core/providers/settings_provider.dart';
import 'package:margo/features/ai/data/memory/learning_memory_repository.dart';
import 'package:margo/features/ai/domain/context_engine/page_context.dart';
import 'package:margo/features/ai/domain/features/explainer.dart';
import 'package:margo/features/ai/domain/memory/concept_mastery.dart';
import 'package:margo/features/ai/domain/memory/learning_preferences.dart';
import 'package:margo/features/ai/domain/tutor/tutor_prompt.dart';
import 'package:margo/features/ai/presentation/ai_providers.dart';
import 'package:margo/features/ai/presentation/tutor_context_provider.dart';

class _Memory implements LearningMemoryRepository {
  _Memory({
    this.weak = const [],
    this.onlySeen = const [],
    this.preferences = LearningPreferences.empty,
    this.fail = false,
  });

  List<String> weak;

  /// Concepts the student has met on a page and never been tested on.
  final List<String> onlySeen;
  final LearningPreferences preferences;
  final bool fail;
  final askedNotebooks = <int>[];

  @override
  Future<List<ConceptMastery>> weakConcepts(int notebookId) async {
    askedNotebooks.add(notebookId);
    if (fail) throw StateError('isar closed');
    ConceptMastery seen(String name) => ConceptMastery.firstSeen(
          conceptName: name,
          notebookId: notebookId,
          at: DateTime(2026, 11, 17),
        );
    return [
      for (final name in onlySeen) seen(name),
      for (final name in weak) seen(name).copyWith(timesMissedInQuiz: 1),
    ];
  }

  @override
  Future<LearningPreferences> loadPreferences() async {
    if (fail) throw StateError('isar closed');
    return preferences;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _container(_Memory memory) async {
  final container = ProviderContainer(overrides: [
    learningMemoryProvider.overrideWithValue(memory),
    secretStoreProvider.overrideWithValue(InMemorySecretStore()),
  ]);
  addTearDown(container.dispose);
  container.read(settingsProvider);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a student with no history gets the plain context', () async {
    final container = await _container(_Memory());
    final context = await container.read(tutorContextProvider(7).future);
    expect(context.style, TeachingStyle.explain);
    expect(context.profile.isEmpty, isTrue);
  });

  test('the profile is read from learning memory for that notebook', () async {
    final memory = _Memory(
      weak: ['entropy', 'Gibbs free energy'],
      preferences: const LearningPreferences(
        preferredDifficulty: KnowledgeLevel.advanced,
        preferredExplainMode: ExplainMode.visual,
      ),
    );
    final container = await _container(memory);

    final context = await container.read(tutorContextProvider(7).future);

    expect(memory.askedNotebooks, [7]);
    expect(context.profile.level, KnowledgeLevel.advanced);
    expect(context.profile.preferredMode, ExplainMode.visual);
    expect(context.profile.weakConcepts, ['entropy', 'Gibbs free energy']);
  });

  test('a concept the student has only seen is not called shaky', () async {
    // `weakConcepts` counts every concept below "practiced", which includes
    // one that merely appeared on a page. Telling a model the student is
    // struggling with it would be a guess.
    final container = await _container(
      _Memory(onlySeen: ['osmosis', 'diffusion'], weak: ['entropy']),
    );
    final context = await container.read(tutorContextProvider(1).future);
    expect(context.profile.weakConcepts, ['entropy']);
  });

  test('only the weakest five concepts are carried', () async {
    final container = await _container(
      _Memory(weak: ['a', 'b', 'c', 'd', 'e', 'f', 'g']),
    );
    final context = await container.read(tutorContextProvider(1).future);
    expect(context.profile.weakConcepts, ['a', 'b', 'c', 'd', 'e']);
  });

  test('a quiz finished between two questions shows up in the second',
      () async {
    final memory = _Memory(weak: ['entropy']);
    final container = await _container(memory);
    final first = await container.read(tutorContextProvider(1).future);
    expect(first.profile.weakConcepts, ['entropy']);

    memory.weak = ['entropy', 'enthalpy'];
    await Future<void>.delayed(Duration.zero);
    final second = await container.read(tutorContextProvider(1).future);

    expect(second.profile.weakConcepts, ['entropy', 'enthalpy']);
  });

  test('the style comes from the setting', () async {
    final container = await _container(_Memory());
    await container
        .read(settingsProvider.notifier)
        .setTeachingStyle(TeachingStyle.guide);

    final context = await container.read(tutorContextProvider(1).future);

    expect(context.style, TeachingStyle.guide);
  });

  test('learning memory failing costs the profile, not the answer', () async {
    final container = await _container(_Memory(fail: true));
    await container
        .read(settingsProvider.notifier)
        .setTeachingStyle(TeachingStyle.guide);

    final context = await container.read(tutorContextProvider(1).future);

    expect(context.style, TeachingStyle.guide);
    expect(context.profile, same(LearnerProfile.none));
  });
}
