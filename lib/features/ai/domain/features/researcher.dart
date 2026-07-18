// "Research" (Phase 3, Loop 3.4): answer a free-form question, letting the
// model reach outside the notes when it needs to — Calculator, Wikipedia,
// Web Search. The opposite of `notes_qa.dart`'s "Ask your notes": that
// feature refuses to answer from anything but the notes; this one exists
// precisely for questions the notes can't cover. Cloud-only this loop (see
// `cloud_gateway_provider.dart`'s `generateWithTools` header).
//
// Owns the call → tool-call → execute → recall loop client-side, since the
// gateway stays stateless/one-shot per call by design (phase spec §1) — each
// `generateWithTools` call here is exactly one gateway round-trip.

import 'dart:async';
import 'dart:convert';

import '../ai_message.dart';
import '../tools/tool.dart';
import '../tools/tool_generation_event.dart';

sealed class ResearchEvent {
  const ResearchEvent();
}

class ResearchTextChunk extends ResearchEvent {
  final String text;
  const ResearchTextChunk(this.text);
}

/// A tool finished running — lets the UI show "used: Calculator".
class ResearchToolUsed extends ResearchEvent {
  final String toolName;
  const ResearchToolUsed(this.toolName);
}

/// The narrow surface `Researcher` needs from `CloudGatewayProvider` —
/// declared here rather than depending on the concrete class, so tests can
/// fake it without a real `Dio`/HTTP stack.
abstract class ToolCallingClient {
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
  });
}

class Researcher {
  /// Bounds cost/latency on a pathological back-and-forth — three full
  /// tool-use rounds is generous for "first useful subset" tasks (a
  /// calculator + a couple of lookups), with one more call afterward still
  /// allowed so the model can synthesize a final answer from what it found.
  static const int maxToolHops = 3;

  final ToolCallingClient _client;
  final List<Tool> _tools;

  const Researcher({required ToolCallingClient client, required List<Tool> tools})
      : _client = client,
        _tools = tools;

  static const String systemPrompt =
      'You are a research assistant inside a note-taking app. Answer the '
      "user's question directly and concisely. Use the available tools when "
      'they would make your answer more accurate or current: use the '
      'calculator instead of computing arithmetic yourself, look up facts '
      'you are unsure of, and search the web for anything recent, specific, '
      'or outside your own knowledge. If no tool is needed, just answer.';

  Stream<ResearchEvent> research(String question) async* {
    final history = <AiMessage>[];
    var prompt = question;
    var hop = 0;

    while (true) {
      final textBuffer = StringBuffer();
      final calls = <ToolCallRequested>[];

      await for (final event in _client.generateWithTools(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history.isEmpty ? null : List.of(history),
        tools: _tools,
      )) {
        switch (event) {
          case ToolTextChunk(:final text):
            textBuffer.write(text);
            yield ResearchTextChunk(text);
          case ToolCallRequested():
            calls.add(event);
        }
      }

      // The prompt just sent becomes a completed turn before anything else
      // is appended, so a later hop's history stays in the right order.
      if (prompt.isNotEmpty) history.add(AiMessage.user(prompt));

      if (calls.isEmpty) return; // a plain text answer — done

      if (hop >= maxToolHops) {
        yield const ResearchTextChunk(
            '\n\n(Stopped after several tool calls without a final answer.)');
        return;
      }

      history.add(AiMessage(
        role: AiRole.assistant,
        content: textBuffer.toString(),
        toolCalls: [
          for (final call in calls)
            {
              'id': call.callId,
              'type': 'function',
              'function': {
                'name': call.name,
                'arguments': jsonEncode(call.arguments),
              },
            },
        ],
      ));

      for (final call in calls) {
        final result = await _runTool(call);
        yield ResearchToolUsed(call.name);
        history.add(AiMessage(
          role: AiRole.tool,
          content: result.content,
          toolCallId: call.callId,
        ));
      }

      // The next call's "new" content is already in `history` (the tool
      // results just appended) — nothing further from the user to send.
      prompt = '';
      hop++;
    }
  }

  Future<ToolExecutionResult> _runTool(ToolCallRequested call) async {
    for (final tool in _tools) {
      if (tool.name == call.name) return tool.execute(call.arguments);
    }
    return ToolExecutionResult.error('Unknown tool "${call.name}".');
  }
}
