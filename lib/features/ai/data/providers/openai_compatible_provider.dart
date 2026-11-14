// Client for any OpenAI-compatible chat completions API, called with the
// user's own key (OpenRouter, Gemini, OpenAI, a self-hosted server...). An
// [AiProvider] so the rest of the app never knows a network call happened.
//
// Streams via SSE: each `data: {...}` line is one OpenAI chunk, `data: [DONE]`
// ends the reply, and a `data: {"error": ...}` line means the provider failed
// mid-stream (output already yielded stays; the caller decides how to mark it
// incomplete).
//
// The API key travels only in the per-request `Authorization` header. It is
// never put in an exception message or cause: errors carry a short summary,
// never the DioException (whose requestOptions hold the headers).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/ai_provider.dart';
import '../../domain/features/researcher.dart' show ToolCallingClient;
import '../../domain/image_transcriber.dart';
import '../../domain/tools/tool.dart';
import '../../domain/tools/tool_generation_event.dart';
import 'cloud_presets.dart';

/// One entry of a provider's `/models` list.
class CloudModel {
  const CloudModel({required this.id, this.contextLength});
  final String id;
  final int? contextLength;
}

/// [OpenAiCompatibleProvider.listModels] failed. [keyRejected] is true when the
/// provider refused the key (401/403), so the UI can ask for another one.
class CloudModelListException implements Exception {
  const CloudModelListException(this.message, {required this.keyRejected});
  final String message;
  final bool keyRejected;
  @override
  String toString() => 'CloudModelListException: $message';
}

class OpenAiCompatibleProvider
    implements AiProvider, ToolCallingClient, ImageTranscriber {
  /// Used when the provider's model list gave no context length.
  static const int defaultContextWindowTokens = 32000;

  /// A cloud figure read must finish within this long, so a hung provider
  /// falls back to the local read quickly instead of stalling a summary.
  static const Duration visionTimeout = Duration(seconds: 90);

  /// The longest silence allowed between two stream chunks. Reasoning models
  /// can think for a minute or more before the first token.
  static const Duration streamIdleTimeout = Duration(seconds: 180);

  /// Streamed tool arguments past this many code points are refused rather
  /// than buffered without bound.
  static const int maxToolArgumentChars = 8000;

  /// Largest picture [transcribeImage] will upload.
  static const int maxImageBytes = 8 * 1024 * 1024;

  final Dio _dio;
  final String _root;
  final String _key;
  final String _model;
  final AiCapabilities _capabilities;
  final bool Function() _isCloudAllowed;

  /// [isCloudAllowed] is asked before every request, so no caller can reach the
  /// network while the user has cloud AI off. It is read per call, never cached.
  /// [baseUrl] is the API root, e.g. `https://openrouter.ai/api/v1`; requests
  /// always go to absolute URLs under it, even with an injected [dio].
  OpenAiCompatibleProvider({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String presetId,
    int? contextWindowTokens,
    bool Function()? isCloudAllowed,
    Dio? dio,
  })  : _root = baseUrl,
        _key = apiKey,
        _model = model,
        _isCloudAllowed = isCloudAllowed ?? (() => true),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 60),
              // The gap between stream chunks, not the whole reply.
              receiveTimeout: streamIdleTimeout,
              // A redirect could carry the Authorization header to another
              // host. These APIs do not redirect, so none is followed.
              followRedirects: false,
            )),
        _capabilities = AiCapabilities(
          modelId: 'cloud-$presetId-$model',
          displayName: model,
          contextWindowTokens:
              contextWindowTokens != null && contextWindowTokens > 0
                  ? contextWindowTokens
                  : defaultContextWindowTokens,
        );

  @override
  AiCapabilities get capabilities => _capabilities;

  String _endpoint(String path) => _endpointFor(_root, path);

  static String _endpointFor(String baseUrl, String path) =>
      normalizeCloudBaseUrl(baseUrl) + path;

  static Map<String, String> _auth(String apiKey) =>
      {'Authorization': 'Bearer $apiKey'};

  void _requireCloudAllowed() {
    if (!_isCloudAllowed()) {
      throw const AiUnavailableException(
          'Cloud AI is turned off in Settings, so nothing was sent.');
    }
  }

  List<Map<String, dynamic>> _messages({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required bool withToolFields,
  }) =>
      [
        if (systemPrompt != null && systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        for (final m in history ?? const <AiMessage>[])
          {
            'role': m.role.name,
            'content': m.content,
            if (withToolFields &&
                m.role == AiRole.tool &&
                m.toolCallId != null)
              'tool_call_id': m.toolCallId,
            if (withToolFields &&
                m.role == AiRole.assistant &&
                m.toolCalls != null)
              'tool_calls': m.toolCalls,
          },
        if (prompt.isNotEmpty) {'role': 'user', 'content': prompt},
      ];

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) async* {
    await for (final choice in _streamChoices(
      messages: _messages(
          prompt: prompt,
          systemPrompt: systemPrompt,
          history: history,
          withToolFields: false),
      options: options,
      forTools: false,
    )) {
      final delta = choice['delta'];
      final content = delta is Map ? delta['content'] : null;
      if (content is String && content.isNotEmpty) yield content;
    }
  }

  /// Tool-calling variant of [generate], deliberately NOT part of the
  /// [AiProvider] contract (a `Stream<String>` cannot say "the model wants to
  /// call a tool"). [Researcher] owns the call, tool, recall loop; this method
  /// is exactly one round-trip. Tool calls stream in fragments keyed by
  /// `index` and are emitted, whole, once the stream ends.
  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
    AiGenerationOptions? options,
  }) async* {
    final slots = <int, _ToolCallSlot>{}; // insertion (first-seen) order
    String? finishReason;
    await for (final choice in _streamChoices(
      messages: _messages(
          prompt: prompt,
          systemPrompt: systemPrompt,
          history: history,
          withToolFields: true),
      tools: tools,
      options: options,
      forTools: true,
    )) {
      final reason = choice['finish_reason'];
      if (reason is String) finishReason = reason;
      final delta = choice['delta'];
      if (delta is! Map) continue;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        yield ToolTextChunk(content);
      }
      final calls = delta['tool_calls'];
      if (calls is! List) continue;
      for (var i = 0; i < calls.length; i++) {
        final tc = calls[i];
        if (tc is! Map) continue;
        final index = tc['index'];
        // A provider that omits `index` gets the fragment's list position.
        final slot = slots.putIfAbsent(
            index is num ? index.toInt() : i, _ToolCallSlot.new);
        final id = tc['id'];
        if (id is String && id.isNotEmpty) slot.id = id;
        final fn = tc['function'];
        if (fn is! Map) continue;
        final name = fn['name'];
        if (name is String && name.isNotEmpty) slot.name = name;
        final args = fn['arguments'];
        if (args is String && args.isNotEmpty) {
          slot.arguments.write(args);
          slot.argumentRunes += args.runes.length;
          if (slot.argumentRunes > maxToolArgumentChars) {
            throw const AiGenerationException(
                'Tool call arguments are too large.');
          }
        }
      }
    }

    for (final slot in slots.values) {
      if (slot.id.isEmpty || slot.name.isEmpty) {
        throw const AiGenerationException(
            'Model produced an incomplete tool call.');
      }
      final raw = slot.arguments.toString();
      final Object? decoded;
      try {
        decoded = jsonDecode(raw.isEmpty ? '{}' : raw);
      } on FormatException {
        throw AiGenerationException(finishReason == 'length'
            ? 'The reply was cut off before the tool call finished.'
            : 'Model produced a malformed tool call.');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const AiGenerationException(
            'Model produced a malformed tool call.');
      }
      yield ToolCallRequested(
          callId: slot.id, name: slot.name, arguments: decoded);
    }
  }

  /// One streamed chat completion: yields `choices[0]` of each SSE chunk,
  /// raising mid-stream `error` events as [AiGenerationException].
  Stream<Map<String, dynamic>> _streamChoices({
    required List<Map<String, dynamic>> messages,
    List<Tool>? tools,
    AiGenerationOptions? options,
    required bool forTools,
  }) async* {
    _requireCloudAllowed();
    final cancelToken = CancelToken();
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        _endpoint('/chat/completions'),
        data: {
          'model': _model,
          'messages': messages,
          'stream': true,
          'temperature': options?.temperature ?? 0.7,
          if (options?.maxTokens != null) 'max_tokens': options!.maxTokens,
          if (tools != null && tools.isNotEmpty) ...{
            'tools': [for (final t in tools) toolSchema(t)],
            'tool_choice': 'auto',
          },
        },
        options: Options(
          headers: _auth(_key),
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw await _mapError(e, forTools: forTools);
    }

    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    var sawData = false;
    try {
      await for (final line in lines) {
        // Blank lines and `:` comments (OpenRouter's keep-alive) carry nothing.
        if (!line.startsWith('data:')) continue;
        sawData = true;
        final payload = line.substring(5).trimLeft();
        if (payload == '[DONE]') break;
        final chunk = _decodeChunk(payload);
        final error = chunk['error'];
        if (error != null) {
          final detail = error is Map && error['message'] is String
              ? error['message'] as String
              : error is String
                  ? error
                  : null;
          // Never echo the key back to the user, even if a provider does.
          final scrubbed = detail == null
              ? null
              : _key.isEmpty
                  ? detail
                  : detail.replaceAll(_key, '…');
          throw AiGenerationException(scrubbed == null
              ? 'The AI provider stopped the reply.'
              : 'The AI provider stopped the reply: '
                  '${String.fromCharCodes(scrubbed.runes.take(200))}');
        }
        final choices = chunk['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is Map<String, dynamic>) yield choice;
      }
      // A 200 with no SSE lines at all (a captive portal's HTML page, or a
      // server that ignored stream: true) is not an empty reply.
      if (!sawData) {
        throw const AiGenerationException(
            'Malformed response from the AI provider.');
      }
    } on AiException {
      rethrow;
    } on DioException catch (e) {
      // We cancelled (the consumer stopped listening): teardown, not failure.
      if (cancelToken.isCancelled) return;
      throw await _mapError(e, forTools: forTools);
    } on FormatException {
      // Bytes that are not UTF-8, from the wire.
      throw const AiGenerationException(
          'Malformed response from the AI provider.');
    } catch (e) {
      // A dropped connection surfaces as a raw dart:io error, not a
      // DioException. Map it, so the caller's on-device fallback still runs.
      if (cancelToken.isCancelled) return;
      throw AiUnavailableException('AI provider unreachable',
          cause: e.runtimeType.toString());
    } finally {
      cancelToken.cancel();
    }
  }

  /// A truncated or non-JSON `data:` line (a proxy error page, a cut stream)
  /// becomes an [AiException] so the caller's on-device fallback still fires.
  static Map<String, dynamic> _decodeChunk(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Falls through to the same error.
    }
    throw const AiGenerationException(
        'Malformed response from the AI provider.');
  }

  /// Cloud figure analysis, the escalation target for a diagram the on-device
  /// VLM read poorly (see [FigureAnalyzer]). Not streamed: the caller parses
  /// one JSON object, so a partial reply is useless. [randomSeed] is accepted
  /// for contract compatibility and ignored (not every provider takes a seed).
  @override
  Future<String> transcribeImage(
    Uint8List imageBytes, {
    required String prompt,
    double temperature = 0.0,
    int maxOutputTokens = 1024,
    int? randomSeed,
  }) async {
    _requireCloudAllowed();
    if (imageBytes.length > maxImageBytes) {
      throw const AiGenerationException(
          'The picture is too large to send to the cloud.');
    }
    final cancelToken = CancelToken();
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio
          .post<Map<String, dynamic>>(
            _endpoint('/chat/completions'),
            data: {
              'model': _model,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      // Everything reaching here is a PNG: page renders come
                      // from SceneExporter.toPng, and imports are re-encoded.
                      'image_url': {
                        'url': 'data:image/png;base64,${base64Encode(imageBytes)}',
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
              'temperature': temperature,
              'max_tokens': maxOutputTokens,
              'stream': false,
            },
            // Longer than visionTimeout, so that limit fires first and gives
            // the timed-out message rather than a generic unreachable one.
            options: Options(
              headers: _auth(_key),
              receiveTimeout: const Duration(seconds: 120),
            ),
            cancelToken: cancelToken,
          )
          .timeout(visionTimeout);
    } on DioException catch (e) {
      throw await _mapError(e, forTools: false);
    } on TimeoutException {
      cancelToken.cancel();
      throw AiUnavailableException(
          'Cloud figure analysis timed out after ${visionTimeout.inSeconds}s.');
    }

    const noText =
        AiGenerationException('AI provider returned no text for the image.');
    final body = response.data;
    if (body == null || body['error'] != null) throw noText;
    final choices = body['choices'];
    final choice = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = choice is Map ? choice['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.isEmpty) throw noText;
    return content;
  }

  /// The models the key can use, sorted by id. Throws
  /// [CloudModelListException], never with the key or the body in it.
  static Future<List<CloudModel>> listModels({
    required String baseUrl,
    required String apiKey,
    Dio? dio,
  }) async {
    final client = dio ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          followRedirects: false, // Same reason as the chat client.
        ));
    try {
      return await _listModelsWith(client, baseUrl, apiKey);
    } finally {
      // Close only the client made here; an injected one belongs to the caller.
      if (dio == null) client.close();
    }
  }

  static Future<List<CloudModel>> _listModelsWith(
    Dio client,
    String baseUrl,
    String apiKey,
  ) async {
    const failed = CloudModelListException('Could not load the model list.',
        keyRejected: false);
    // OpenRouter answers /models to anyone, even with a wrong key, so the key
    // is checked on an endpoint that does verify it first.
    if (Uri.tryParse(baseUrl)?.host == 'openrouter.ai') {
      try {
        await client.get<Object?>(
          _endpointFor(baseUrl, '/key'),
          options: Options(headers: _auth(apiKey)),
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          throw const CloudModelListException(
              'Your AI API key was rejected.',
              keyRejected: true);
        }
        throw failed;
      } catch (_) {
        throw failed;
      }
    }
    final Object? data;
    try {
      final response = await client.get<Object?>(
        _endpointFor(baseUrl, '/models'),
        options: Options(headers: _auth(apiKey)),
      );
      data = response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const CloudModelListException('Your AI API key was rejected.',
            keyRejected: true);
      }
      throw failed;
    } catch (_) {
      throw failed;
    }

    // Most return {"data": [...]}; Together returns the bare list.
    final entries = data is Map && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : throw failed;
    final byId = <String, CloudModel>{};
    for (final entry in entries) {
      if (entry is! Map || entry['id'] is! String) continue;
      var id = entry['id'] as String;
      if (id.startsWith('models/')) id = id.substring(7); // Gemini
      // Each provider names the window differently: Groq says context_window,
      // Mistral max_context_length.
      final ctx = entry['context_length'] ??
          entry['context_window'] ??
          entry['max_context_length'];
      byId.putIfAbsent(
          id,
          () => CloudModel(
              id: id, contextLength: ctx is num && ctx > 0 ? ctx.toInt() : null));
    }
    return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<AiException> _mapError(DioException e,
      {required bool forTools}) async {
    final status = e.response?.statusCode;
    // Never the DioException itself: its requestOptions carry the key.
    final summary =
        status == null ? e.type.name : '${e.type.name} HTTP $status';
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return AiUnavailableException('AI provider unreachable',
            cause: summary);
      default:
        break;
    }
    if (forTools &&
        (status == 400 || status == 404) &&
        (await _bodySnippet(e.response?.data))
            .toLowerCase()
            .contains('tool')) {
      return AiGenerationException(
          "The model '$_model' does not support tools, so Research cannot run.",
          cause: summary);
    }
    switch (status) {
      case 401:
      case 403:
        return AiUnavailableException(
            'Your AI API key was rejected. Check it in Settings.',
            cause: summary);
      case 402:
        return AiUnavailableException(
            'Your AI provider account is out of credit.',
            cause: summary);
      case 429:
        return AiUnavailableException(
            'Your AI provider is rate-limiting you. Try again shortly.',
            cause: summary);
      case 404:
        return AiGenerationException(
            "The model '$_model' was not found at this provider.",
            cause: summary);
    }
    // Not `e.message`: Dio's default text is a multi-paragraph essay.
    return AiGenerationException(
        status == null
            ? 'AI provider request failed.'
            : 'AI provider request failed (HTTP $status).',
        cause: summary);
  }

  /// The first 2 KiB of an error response body, only ever searched for a
  /// word, never shown. Any failure reads as ''.
  static Future<String> _bodySnippet(Object? data) async {
    if (data is! ResponseBody) return '';
    try {
      return await Future(() async {
        final bytes = <int>[];
        await for (final chunk in data.stream) {
          bytes.addAll(chunk);
          if (bytes.length >= 2048) break;
        }
        return utf8.decode(bytes.take(2048).toList(), allowMalformed: true);
      }).timeout(const Duration(seconds: 3));
    } catch (_) {
      return '';
    }
  }
}

class _ToolCallSlot {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
  int argumentRunes = 0;
}
