// Cloud LLM tier — ABSTRACTION ONLY for now (locked decision #5).
//
// The interface mirrors the OpenAI-compatible chat-completions shape so a real
// provider can slot in later without touching callers. The only implementation
// in this build is a no-op stub: no provider integration, no API keys, no
// billing. Note content can only ever reach this path when the user has
// explicitly enabled cloud AI in settings (default OFF).

/// One chat turn, OpenAI-compatible ('system' | 'user' | 'assistant').
class ChatMessage {
  final String role;
  final String content;
  const ChatMessage({required this.role, required this.content});

  const ChatMessage.system(String content) : this(role: 'system', content: content);
  const ChatMessage.user(String content) : this(role: 'user', content: content);
}

/// Thrown when the cloud tier cannot serve a request (always, for the stub).
class CloudUnavailableException implements Exception {
  final String message;
  CloudUnavailableException(
      [this.message = 'Cloud summarization is not available in this build.']);

  @override
  String toString() => 'CloudUnavailableException: $message';
}

abstract class CloudLlmClient {
  /// Runs a chat completion and returns the assistant message content.
  Future<String> chatCompletion({
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
  });
}

/// No-op stub — the summarization flow catches [CloudUnavailableException]
/// and falls back to the local model.
class StubCloudLlmClient implements CloudLlmClient {
  @override
  Future<String> chatCompletion({
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
  }) async {
    throw CloudUnavailableException();
  }
}
