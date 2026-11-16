// A cloud model reached with the student's OWN key, straight from the device.
//
// Speaks the OpenAI chat-completions format, which OpenRouter, Groq, Mistral,
// DeepSeek and others all accept, so one adapter covers every connection a
// student can add. Requests go from this device to the provider and nowhere
// else: Margo's gateway never sees the key or the text.
//
// Three rules shape the file:
//   • Nothing is sent while cloud AI is off. [isCloudAllowed] is asked before
//     every request, the same floor `CloudGatewayProvider` stands on.
//   • The key is read at call time, and never appears in an address, a log or
//     an error. What a provider says in a failure body is not repeated either:
//     several of them echo the key back in "incorrect key" messages, and every
//     AiException can end up in the error log a student shares.
//   • It does not use `gatewayDio`. That client pins the gateway's certificate
//     and trusts no other; this one talks to public hosts and uses the
//     platform's ordinary trusted roots.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/ai_provider.dart';
import '../../domain/features/researcher.dart' show ToolCallingClient;
import '../../domain/tools/tool.dart';
import '../../domain/tools/tool_generation_event.dart';

class OpenAiCompatibleProvider implements AiProvider, ToolCallingClient {
  /// How long to wait for the provider to accept a connection.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// The longest gap allowed between two pieces of a reply.
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// A tool call's arguments are refused past this many characters, the same
  /// bound the gateway applies (`MAX_TOOL_ARGUMENT_CHARS`): a model that never
  /// closes its JSON must not grow a string without end.
  static const int maxToolArgumentChars = 8000;

  final String _chatUrl;
  final String _host;
  final String _modelId;
  final String _label;
  final AiCapabilities _capabilities;
  final Future<String?> Function() _apiKey;
  final bool Function() _isCloudAllowed;
  final Dio _dio;

  // Providers disagree on two request fields. Rather than keep a table that
  // goes stale, a refusal naming one of them is answered by asking again the
  // other way, and the answer is remembered for this connection.
  String _maxTokensField = 'max_tokens';
  bool _sendTemperature = true;

  /// [label] is what the student called the connection; it is what errors name.
  /// [apiKey] is read before every request, so a replaced key takes effect at
  /// once. [dio] is for tests.
  OpenAiCompatibleProvider({
    required String baseUrl,
    required String modelId,
    required String displayName,
    required String label,
    required int contextWindowTokens,
    required Future<String?> Function() apiKey,
    bool Function()? isCloudAllowed,
    Dio? dio,
  })  : _chatUrl =
            '${baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/chat/completions',
        _host = Uri.tryParse(baseUrl.trim())?.host ?? baseUrl,
        _modelId = modelId,
        _label = label,
        _apiKey = apiKey,
        _isCloudAllowed = isCloudAllowed ?? (() => true),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: connectTimeout,
              receiveTimeout: receiveTimeout,
            )),
        _capabilities = AiCapabilities(
          modelId: 'user-$modelId',
          displayName: displayName,
          contextWindowTokens: contextWindowTokens,
        );

  @override
  AiCapabilities get capabilities => _capabilities;

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    await for (final event in _events(
      prompt: prompt,
      systemPrompt: systemPrompt,
      history: history,
      options: options,
    )) {
      if (event is ToolTextChunk) yield event.text;
    }
  }

  /// One round trip that may end in the model asking for a tool. The caller
  /// (`Researcher`) runs the tool and calls again with the result in [history]
  /// and an empty [prompt].
  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
    AiGenerationOptions? options,
  }) =>
      _events(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
        options: options,
        tools: tools,
      );

  Stream<ToolGenerationEvent> _events({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
    List<Tool> tools = const [],
  }) async* {
    if (!_isCloudAllowed()) {
      throw const AiUnavailableException(
          'Cloud AI is turned off in Settings, so nothing was sent.');
    }
    final key = (await _apiKey())?.trim();
    if (key == null || key.isEmpty) {
      throw AiUnavailableException(
          '$_label has no saved key. Add it again in Settings.');
    }

    final cancelToken = CancelToken();
    final response = await _post(
      key,
      cancelToken,
      messages: _messages(prompt, systemPrompt, history),
      options: options,
      tools: tools,
    );

    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // Keyed by the fragment's `index`: a call's id and name come on its first
    // fragment only, and its arguments arrive in pieces that are not valid JSON
    // until the last one.
    final pending = <int, _PendingCall>{};

    try {
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;

        final event = _decode(data);
        if (event['error'] != null) {
          throw AiGenerationException('$_label failed part-way through.');
        }
        final choices = event['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final delta = (choices.first as Map<String, dynamic>)['delta'];
        if (delta is! Map<String, dynamic>) continue;

        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          yield ToolTextChunk(content);
        }
        final toolCalls = delta['tool_calls'];
        if (toolCalls is List) {
          for (final fragment in toolCalls) {
            _accumulate(pending, fragment);
          }
        }
      }
    } on DioException catch (e) {
      // Cancelled means the caller stopped listening, which is not a failure.
      if (!cancelToken.isCancelled) throw await _mapError(e);
    } on TypeError {
      throw AiGenerationException('Malformed response from $_label.');
    } finally {
      if (!cancelToken.isCancelled) cancelToken.cancel();
    }

    for (final index in pending.keys.toList()..sort()) {
      yield pending[index]!.finish(_label);
    }
  }

  /// Posts the request, asking again once per field a provider refuses.
  Future<Response<ResponseBody>> _post(
    String key,
    CancelToken cancelToken, {
    required List<Map<String, dynamic>> messages,
    required AiGenerationOptions? options,
    required List<Tool> tools,
  }) async {
    // At most one retry per adjustable field, then the refusal stands.
    for (var attempt = 0; ; attempt++) {
      try {
        return await _dio.post<ResponseBody>(
          _chatUrl,
          data: _body(messages, options, tools),
          options: Options(
            headers: {'Authorization': 'Bearer $key'},
            responseType: ResponseType.stream,
          ),
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        if (attempt < 2 && await _adaptTo(e, options)) continue;
        throw await _mapError(e);
      }
    }
  }

  Map<String, dynamic> _body(
    List<Map<String, dynamic>> messages,
    AiGenerationOptions? options,
    List<Tool> tools,
  ) =>
      {
        'model': _modelId,
        'stream': true,
        'messages': messages,
        if (_sendTemperature) 'temperature': options?.temperature ?? 0.7,
        if (options?.maxTokens != null) _maxTokensField: options!.maxTokens,
        if (options?.topP != null) 'top_p': options!.topP,
        if (options != null && options.stopSequences.isNotEmpty)
          'stop': options.stopSequences,
        if (tools.isNotEmpty) ...{
          'tools': [for (final tool in tools) toolSchema(tool)],
          'tool_choice': 'auto',
        },
      };

  List<Map<String, dynamic>> _messages(
    String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
  ) =>
      [
        if (systemPrompt != null && systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        for (final turn in history ?? const <AiMessage>[])
          // The one system prompt is [systemPrompt]; a system turn in the
          // middle of a conversation is not replayed.
          if (turn.role != AiRole.system)
            {
              'role': turn.role.name,
              'content': turn.content,
              if (turn.toolCalls != null) 'tool_calls': turn.toolCalls,
              if (turn.toolCallId != null) 'tool_call_id': turn.toolCallId,
            },
        // After a tool result there is nothing new from the user, and an empty
        // user turn at the end is not a valid conversation.
        if (prompt.isNotEmpty) {'role': 'user', 'content': prompt},
      ];

  /// True when [e] is a refusal of a field this can send differently, and the
  /// request should be made again.
  Future<bool> _adaptTo(DioException e, AiGenerationOptions? options) async {
    if (e.response?.statusCode != 400) return false;
    final detail = (await _errorBody(e)).toLowerCase();
    if (_maxTokensField == 'max_tokens' &&
        options?.maxTokens != null &&
        detail.contains('max_tokens')) {
      _maxTokensField = 'max_completion_tokens';
      return true;
    }
    if (_sendTemperature && detail.contains('temperature')) {
      _sendTemperature = false;
      return true;
    }
    return false;
  }

  /// The start of a failure's body, for [_adaptTo] only. It is never shown or
  /// logged: providers put the key in it.
  Future<String> _errorBody(DioException e) async {
    final data = e.response?.data;
    try {
      if (data is ResponseBody) {
        final text = await utf8.decodeStream(data.stream.cast<List<int>>());
        return text.length > 2000 ? text.substring(0, 2000) : text;
      }
      if (data is String) return data;
      if (data is Map) return jsonEncode(data);
    } catch (_) {
      // An unreadable body just means no adjustment is made.
    }
    return '';
  }

  void _accumulate(Map<int, _PendingCall> pending, Object? fragment) {
    if (fragment is! Map<String, dynamic>) return;
    final index = fragment['index'] as int? ?? 0;
    final call = pending.putIfAbsent(index, _PendingCall.new);
    final id = fragment['id'];
    if (id is String && id.isNotEmpty) call.id = id;
    final function = fragment['function'];
    if (function is Map<String, dynamic>) {
      final name = function['name'];
      if (name is String && name.isNotEmpty) call.name = name;
      final arguments = function['arguments'];
      if (arguments is String) {
        call.arguments.write(arguments);
        if (call.arguments.length > maxToolArgumentChars) {
          throw AiGenerationException(
              '$_label asked for a tool with too much input.');
        }
      }
    }
  }

  Map<String, dynamic> _decode(String data) {
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } on FormatException {
      throw AiGenerationException('Malformed response from $_label.');
    } on TypeError {
      throw AiGenerationException('Malformed response from $_label.');
    }
  }

  /// Turns a transport failure into what the student is told. Deliberately
  /// built from the status code alone; see the file header.
  Future<AiException> _mapError(DioException e) async {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return AiUnavailableException("Couldn't reach $_host.");
      default:
        return switch (e.response?.statusCode) {
          401 || 403 => AiUnavailableException(
              '$_label rejected the key. Check it in Settings.'),
          402 =>
            AiUnavailableException('Your $_label account is out of credit.'),
          404 => AiGenerationException(
              '$_label has no model called $_modelId.'),
          429 => AiUnavailableException(
              "$_label's limit was reached. Try again in a moment."),
          null => AiUnavailableException("Couldn't reach $_host."),
          final status =>
            AiGenerationException('$_label: request failed (HTTP $status).'),
        };
    }
  }
}

/// A tool call still arriving.
class _PendingCall {
  String? id;
  String? name;
  final StringBuffer arguments = StringBuffer();

  ToolCallRequested finish(String label) {
    final callId = id;
    final callName = name;
    if (callId == null || callName == null) {
      throw AiGenerationException('$label sent an incomplete tool request.');
    }
    final raw = arguments.toString();
    final Object? decoded;
    try {
      decoded = raw.isEmpty ? const <String, dynamic>{} : jsonDecode(raw);
    } on FormatException {
      throw AiGenerationException('$label sent a malformed tool request.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw AiGenerationException('$label sent a malformed tool request.');
    }
    return ToolCallRequested(
      callId: callId,
      name: callName,
      arguments: decoded,
    );
  }
}
