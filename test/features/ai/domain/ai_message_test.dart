import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/domain/ai_message.dart';

void main() {
  group('AiMessage', () {
    test('convenience constructors set the matching role', () {
      expect(const AiMessage.system('s').role, AiRole.system);
      expect(const AiMessage.user('u').role, AiRole.user);
      expect(const AiMessage.assistant('a').role, AiRole.assistant);
      expect(const AiMessage.user('hello').content, 'hello');
    });

    test('equality is by role and content', () {
      expect(
        const AiMessage.user('hi'),
        const AiMessage(role: AiRole.user, content: 'hi'),
      );
      expect(
        const AiMessage.user('hi'),
        isNot(const AiMessage.assistant('hi')),
      );
      expect(
        const AiMessage.user('hi'),
        isNot(const AiMessage.user('bye')),
      );
    });

    test('copyWith overrides only the given field', () {
      const original = AiMessage.user('draft');
      final edited = original.copyWith(content: 'final');
      expect(edited.role, AiRole.user);
      expect(edited.content, 'final');
      expect(original.content, 'draft'); // untouched
    });

    test('round-trips through map form', () {
      const message = AiMessage.assistant('the answer is 42');
      final restored = AiMessage.fromMap(message.toMap());
      expect(restored, message);
      // Role is persisted by name, not index, so reordering the enum is safe.
      expect(message.toMap()['role'], 'assistant');
    });

    group('tool role (Loop 3.4)', () {
      test('a tool-role message carries its callId and round-trips', () {
        const message = AiMessage(
          role: AiRole.tool,
          content: '4',
          toolCallId: 'call_1',
        );
        expect(message.role, AiRole.tool);

        final restored = AiMessage.fromMap(message.toMap());
        expect(restored.toolCallId, 'call_1');
        expect(restored, message);
      });

      test('an assistant message carries its toolCalls and round-trips', () {
        const message = AiMessage(
          role: AiRole.assistant,
          content: '',
          toolCalls: [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {'name': 'calculator', 'arguments': '{}'},
            },
          ],
        );

        final restored = AiMessage.fromMap(message.toMap());
        expect(restored.toolCalls, hasLength(1));
        expect(restored.toolCalls!.first['id'], 'call_1');
      });

      test('toMap omits tool fields entirely when unset', () {
        const message = AiMessage.user('plain question');
        expect(message.toMap().containsKey('toolCallId'), isFalse);
        expect(message.toMap().containsKey('toolCalls'), isFalse);
      });
    });
  });
}
