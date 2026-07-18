// Client for the Phase 3 FastAPI gateway (`server/ai-gateway/`) — an
// [AiProvider] so the rest of the app never knows a network call happened.
//
// Streams via SSE, matching the gateway's `POST /v1/generate` contract:
// each `data: {"text": "..."}` line is one chunk; a `data: {"error": "..."}`
// line means the gateway's own provider failed mid-stream (any output already
// yielded stays — the caller decides how to mark it incomplete, per the
// phase spec's "don't discard partial output" rule).

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/ai_provider.dart';
import '../../domain/features/researcher.dart' show ToolCallingClient;
import '../../domain/tools/tool.dart';
import '../../domain/tools/tool_generation_event.dart';

/// A per-install anonymous key sent as `X-Device-Key`, used only for the
/// gateway's rate-limit counters — never a user identity. Session-lifetime
/// (regenerated each app launch) rather than persisted: the gateway isn't
/// deployed yet in this phase, so a daily cap that resets per-launch is a
/// harmless simplification, not a real gap. Revisit (persist via
/// SharedPreferences) once the gateway is actually deployed.
///
/// Public (not just this file's own `_sessionDeviceKey` before Loop 3.4) so
/// `WebSearchTool` presents the same device identity to the gateway's
/// search endpoint as this file presents to `/v1/generate` — one session,
/// one identity, even though LLM and search usage are tracked in separate
/// tables server-side.
final String sessionDeviceKey = _randomDeviceKey();

String _randomDeviceKey() {
  final rand = DateTime.now().microsecondsSinceEpoch ^ identityHashCode(Object());
  return 'device-${rand.toRadixString(16)}';
}

class CloudGatewayProvider implements AiProvider, ToolCallingClient {
  final Dio _dio;
  final String _modelTier;
  final AiCapabilities _capabilities;

  /// [baseUrl] e.g. `http://localhost:8000` in dev. [modelTier] is
  /// `cloud-mid` or `cloud-frontier` — one instance per tier, matching the
  /// gateway's `GenerateRequest.model_tier`.
  CloudGatewayProvider({
    required String baseUrl,
    required String modelTier,
    Dio? dio,
  })  : _modelTier = modelTier,
        _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)),
        _capabilities = AiCapabilities(
          modelId: 'cloud-gateway-$modelTier',
          displayName:
              modelTier == 'cloud-frontier' ? 'Cloud (frontier)' : 'Cloud (Gemma)',
          // Gemma 4's 26B/31B both report a 256K context window upstream —
          // see server/ai-gateway/app/config.py.
          contextWindowTokens: 256000,
          approxCostPerCallUsd: modelTier == 'cloud-frontier' ? 0.02 : 0.005,
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
    final cancelToken = CancelToken();
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '/v1/generate',
        data: {
          'model_tier': _modelTier,
          'prompt': prompt,
          if (systemPrompt != null) 'system_prompt': systemPrompt,
          'history': [
            for (final m in history ?? const <AiMessage>[])
              {'role': m.role.name, 'content': m.content},
          ],
          'stream': true,
          'temperature': options?.temperature ?? 0.7,
          if (options?.maxTokens != null) 'max_tokens': options!.maxTokens,
        },
        options: Options(
          headers: {'X-Device-Key': sessionDeviceKey},
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }

    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final decoded = jsonDecode(line.substring(6)) as Map<String, dynamic>;
        final error = decoded['error'] as String?;
        if (error != null) {
          throw AiGenerationException(error);
        }
        final text = decoded['text'] as String?;
        if (text != null) yield text;
      }
    } on DioException catch (e) {
      // A cancelled request (caller stopped listening — e.g. navigated away
      // mid-stream) is expected teardown, not a failure to surface.
      if (!cancelToken.isCancelled) throw _mapError(e);
    } finally {
      if (!cancelToken.isCancelled) cancelToken.cancel();
    }
  }

  /// Tool-calling variant of [generate] (Loop 3.4) — deliberately NOT part
  /// of the [AiProvider] contract: only this provider supports it so far
  /// (on-device Gemma doesn't, this loop — see this file's header), and
  /// `AiProvider.generate`'s `Stream<String>` shape has no way to express
  /// "the model wants to call a tool" anyway. [Researcher] is the only
  /// caller — it owns the call → tool → recall loop; this method is exactly
  /// one gateway round-trip, matching the gateway's stateless-per-call design.
  @override
  Stream<ToolGenerationEvent> generateWithTools({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    required List<Tool> tools,
    AiGenerationOptions? options,
  }) async* {
    final cancelToken = CancelToken();
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '/v1/generate',
        data: {
          'model_tier': _modelTier,
          'prompt': prompt,
          if (systemPrompt != null) 'system_prompt': systemPrompt,
          'history': [
            for (final m in history ?? const <AiMessage>[])
              {
                'role': m.role.name,
                'content': m.content,
                if (m.toolCallId != null) 'tool_call_id': m.toolCallId,
                if (m.toolCalls != null) 'tool_calls': m.toolCalls,
              },
          ],
          'tools': [for (final t in tools) toolSchema(t)],
          'stream': true,
          'temperature': options?.temperature ?? 0.7,
          if (options?.maxTokens != null) 'max_tokens': options!.maxTokens,
        },
        options: Options(
          headers: {'X-Device-Key': sessionDeviceKey},
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }

    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final decoded = jsonDecode(line.substring(6)) as Map<String, dynamic>;
        final error = decoded['error'] as String?;
        if (error != null) {
          throw AiGenerationException(error);
        }
        final text = decoded['text'] as String?;
        if (text != null) {
          yield ToolTextChunk(text);
          continue;
        }
        final toolCall = decoded['tool_call'] as Map<String, dynamic>?;
        if (toolCall != null) {
          yield ToolCallRequested(
            callId: toolCall['call_id'] as String,
            name: toolCall['name'] as String,
            arguments: (toolCall['arguments'] as Map<String, dynamic>?) ?? const {},
          );
        }
      }
    } on DioException catch (e) {
      if (!cancelToken.isCancelled) throw _mapError(e);
    } finally {
      if (!cancelToken.isCancelled) cancelToken.cancel();
    }
  }

  AiException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return AiUnavailableException('Cloud gateway unreachable', cause: e);
      default:
        final status = e.response?.statusCode;
        if (status == 429) {
          return AiUnavailableException(
              'Cloud usage limit reached for today', cause: e);
        }
        return AiGenerationException('Cloud request failed: ${e.message}',
            cause: e);
    }
  }

  @override
  Future<List<double>> embed(String text) async =>
      throw const AiUnsupportedOperationException(
        'CloudGatewayProvider has no embedding endpoint (Phase 2\'s '
        'on-device EmbeddingGemma covers embeddings) — see /v1/embed in the '
        'phase spec, deliberately deferred.',
      );
}
