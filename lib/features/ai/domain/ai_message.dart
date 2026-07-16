// Provider-agnostic chat message for multi-turn AI context.
//
// Part of the Phase 0 AI provider abstraction (see `ai_provider.dart`). Every AI
// backend — on-device Gemma, cloud Gemma, or a frontier API — consumes and
// produces these, so a history assembled once can be replayed against whichever
// provider the Phase 3 router selects.

/// Who authored an [AiMessage] in a conversation.
///
/// Append-only: the names are persisted (see [AiMessage.toMap]) and may be
/// stored as part of Phase 2 learning memory, so never rename or reorder.
/// Phase 3 tool-calling will add a `tool` role and richer payloads as an
/// additive change; existing values must keep their meaning.
enum AiRole { system, user, assistant }

/// A single turn in an AI conversation: a [role] and its text [content].
///
/// Immutable value object. Content is plain text in Phase 0; structured
/// tool-call payloads are a later, additive concern.
class AiMessage {
  final AiRole role;
  final String content;

  const AiMessage({required this.role, required this.content});

  /// System / instruction message.
  const AiMessage.system(this.content) : role = AiRole.system;

  /// End-user turn.
  const AiMessage.user(this.content) : role = AiRole.user;

  /// Model turn.
  const AiMessage.assistant(this.content) : role = AiRole.assistant;

  AiMessage copyWith({AiRole? role, String? content}) => AiMessage(
        role: role ?? this.role,
        content: content ?? this.content,
      );

  /// For persistence (Phase 2 learning memory) and provider serialization.
  Map<String, dynamic> toMap() => {'role': role.name, 'content': content};

  factory AiMessage.fromMap(Map<String, dynamic> map) => AiMessage(
        role: AiRole.values.byName(map['role'] as String),
        content: map['content'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiMessage && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);

  @override
  String toString() => 'AiMessage(${role.name}: $content)';
}
