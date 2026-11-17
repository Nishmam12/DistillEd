// Common contract for anything the AI can call to reach outside its own
// context (Phase 3, Loop 3.4). Cloud-only this loop: only the cloud AI
// provider (`openai_compatible_provider.dart`) implements tool calling;
// on-device Gemma doesn't get it yet.

/// One tool the model may call. [parameterSchema] is a JSON-schema `object`
/// (OpenAI function-calling convention:
/// `{"type":"object","properties":{...},"required":[...]}`).
abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameterSchema;

  /// Runs the tool with the model-supplied [arguments]. Must never throw —
  /// a failure becomes [ToolExecutionResult.error] so the model can tell the
  /// user what went wrong, per the phase spec's "reject with a clear error,
  /// don't silently degrade" rule.
  Future<ToolExecutionResult> execute(Map<String, dynamic> arguments);
}

/// What running a [Tool] produced. [content] is always fed back to the
/// model as the tool's result, whether or not it succeeded — a failed tool
/// still gets a turn to tell the user what happened, rather than the whole
/// request silently erroring out.
class ToolExecutionResult {
  final bool success;
  final String content;

  const ToolExecutionResult.ok(this.content) : success = true;
  const ToolExecutionResult.error(this.content) : success = false;
}

/// The OpenAI-shape function declaration for [tool], as sent to the cloud AI
/// provider (the chat-completions `tools` field — see
/// `openai_compatible_provider.dart`).
/// A free function rather than a `Tool` method: `Tool` stays a pure
/// interface, matching `AiProvider`'s own style of zero concrete members.
Map<String, dynamic> toolSchema(Tool tool) => {
      'type': 'function',
      'function': {
        'name': tool.name,
        'description': tool.description,
        'parameters': tool.parameterSchema,
      },
    };
