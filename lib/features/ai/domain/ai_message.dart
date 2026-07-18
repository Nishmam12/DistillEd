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
/// [tool] was added additively in Phase 3 Loop 3.4 — existing values keep
/// their meaning.
enum AiRole { system, user, assistant, tool }

/// A single turn in an AI conversation: a [role] and its text [content].
///
/// Immutable value object. Content is plain text for every pre-Loop-3.4
/// caller. [toolCallId] / [toolCalls] are the Loop 3.4 tool round-trip's
/// only structured payload, used ONLY within a single in-memory
/// `Researcher.research()` exchange (never persisted) — see that file.
class AiMessage {
  final AiRole role;
  final String content;

  /// Set on a [AiRole.tool] turn: which prior call this answers. Mirrors the
  /// OpenAI-shape `tool_call_id` field the gateway forwards to the model.
  final String? toolCallId;

  /// Set on an [AiRole.assistant] turn that requested tool call(s) — carried
  /// forward verbatim (OpenAI shape: `[{"id","type","function":{"name",
  /// "arguments"}}]`) so a follow-up request's history stays a valid
  /// conversation the model can make sense of.
  final List<Map<String, dynamic>>? toolCalls;

  const AiMessage({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCalls,
  });

  /// System / instruction message.
  const AiMessage.system(this.content)
      : role = AiRole.system,
        toolCallId = null,
        toolCalls = null;

  /// End-user turn.
  const AiMessage.user(this.content)
      : role = AiRole.user,
        toolCallId = null,
        toolCalls = null;

  /// Model turn.
  const AiMessage.assistant(this.content)
      : role = AiRole.assistant,
        toolCallId = null,
        toolCalls = null;

  AiMessage copyWith({
    AiRole? role,
    String? content,
    String? toolCallId,
    List<Map<String, dynamic>>? toolCalls,
  }) =>
      AiMessage(
        role: role ?? this.role,
        content: content ?? this.content,
        toolCallId: toolCallId ?? this.toolCallId,
        toolCalls: toolCalls ?? this.toolCalls,
      );

  /// For persistence (Phase 2 learning memory) and provider serialization.
  Map<String, dynamic> toMap() => {
        'role': role.name,
        'content': content,
        if (toolCallId != null) 'toolCallId': toolCallId,
        if (toolCalls != null) 'toolCalls': toolCalls,
      };

  factory AiMessage.fromMap(Map<String, dynamic> map) => AiMessage(
        role: AiRole.values.byName(map['role'] as String),
        content: map['content'] as String,
        toolCallId: map['toolCallId'] as String?,
        toolCalls: (map['toolCalls'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiMessage &&
          other.role == role &&
          other.content == content &&
          other.toolCallId == toolCallId;

  @override
  int get hashCode => Object.hash(role, content, toolCallId);

  @override
  String toString() => 'AiMessage(${role.name}: $content)';
}
