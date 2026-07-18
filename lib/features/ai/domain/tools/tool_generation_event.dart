// Events streamed by `CloudGatewayProvider.generateWithTools` (Loop 3.4) —
// distinct from the plain `AiProvider.generate` contract's `Stream<String>`
// because a tool-aware call can ask the caller to run something and come
// back, which a bare text stream can't express.

sealed class ToolGenerationEvent {
  const ToolGenerationEvent();
}

class ToolTextChunk extends ToolGenerationEvent {
  final String text;
  const ToolTextChunk(this.text);
}

/// The model wants to call a tool. Multiple of these may arrive for one
/// turn (parallel tool calls) before the stream ends — the caller collects
/// all of them, runs each, and sends all results back together.
class ToolCallRequested extends ToolGenerationEvent {
  final String callId;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCallRequested({
    required this.callId,
    required this.name,
    required this.arguments,
  });
}
