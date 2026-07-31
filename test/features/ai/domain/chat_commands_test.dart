import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/chat_commands.dart';

void main() {
  group('/cloud', () {
    test('on and its synonyms enable', () {
      for (final input in ['/cloud on', '/cloud enable', '/cloud yes']) {
        expect(parseChatCommand(input), isA<CloudModelCommand>(), reason: input);
        expect((parseChatCommand(input)! as CloudModelCommand).enable, isTrue,
            reason: input);
      }
    });

    test('off and its synonyms disable', () {
      for (final input in ['/cloud off', '/cloud disable', '/cloud no']) {
        expect((parseChatCommand(input)! as CloudModelCommand).enable, isFalse,
            reason: input);
      }
    });

    test('is case- and whitespace-insensitive', () {
      expect(
          (parseChatCommand('  /CLOUD   On  ')! as CloudModelCommand).enable,
          isTrue);
    });

    test('a bare /cloud reports the state rather than guessing', () {
      expect((parseChatCommand('/cloud')! as CloudModelCommand).enable, isNull);
    });

    test('an unrecognised argument is not silently read as on or off', () {
      expect(parseChatCommand('/cloud maybe'), isA<UnknownSlashCommand>());
    });
  });

  group('unknown slash commands', () {
    test('are recognised as commands so they are not asked as questions', () {
      // Sending "/clod on" to the model would produce a confident answer about
      // nothing, which is worse than saying the command isn't known.
      expect(parseChatCommand('/clod on'), isA<UnknownSlashCommand>());
      expect(parseChatCommand('/help'), isA<UnknownSlashCommand>());
    });
  });

  group('natural phrasing', () {
    test('common ways of asking for the cloud model', () {
      for (final input in [
        'use the cloud model',
        'Use the cloud model.',
        'switch to the cloud model',
        'turn on cloud AI',
        'enable cloud',
      ]) {
        final command = parseChatCommand(input);
        expect(command, isA<CloudModelCommand>(), reason: input);
        expect((command! as CloudModelCommand).enable, isTrue, reason: input);
      }
    });

    test('common ways of asking for the local model', () {
      for (final input in [
        'use the local model',
        'Switch to local model',
        'turn off cloud AI',
        'go local',
      ]) {
        expect((parseChatCommand(input)! as CloudModelCommand).enable, isFalse,
            reason: input);
      }
    });
  });

  group('real questions are never eaten', () {
    // The failure that matters. A question swallowed by the command parser
    // disappears with a settings confirmation in its place, and the student has
    // no way to tell what happened.
    const questions = [
      'What did I write about cloud computing?',
      'How does cloud storage differ from local storage?',
      'Explain the local model of computation',
      'What are cumulus clouds made of?',
      'Should I use the cloud model of distributed systems in my essay?',
      'When did I note that we should switch to local variables?',
      'cloud',
      'local',
    ];

    for (final question in questions) {
      test('"$question" reaches the model', () {
        expect(parseChatCommand(question), isNull);
      });
    }
  });

  test('blank input is not a command', () {
    expect(parseChatCommand(''), isNull);
    expect(parseChatCommand('   '), isNull);
  });

  group('confirmation wording', () {
    test('turning it off says everything stays on the device', () {
      final message = cloudCommandConfirmation(
          enabled: false, privacyAsksEachTime: true);
      expect(message, contains('off'));
      expect(message, contains('on your device'));
    });

    test('turning it on under askEachTime still promises a confirmation', () {
      // Enabling the opt-in is NOT consent to send. Saying only "cloud AI is
      // on" would leave the student expecting their notes to go out silently.
      final message =
          cloudCommandConfirmation(enabled: true, privacyAsksEachTime: true);
      expect(message, contains('asked before anything is sent'));
    });

    test('turning it on with cloud pre-authorised does not over-promise', () {
      final message =
          cloudCommandConfirmation(enabled: true, privacyAsksEachTime: false);
      expect(message, isNot(contains('asked before')));
    });

    test('the state report names the command that changes it', () {
      expect(cloudStateReport(enabled: true), contains('/cloud off'));
      expect(cloudStateReport(enabled: false), contains('/cloud on'));
    });
  });
}
