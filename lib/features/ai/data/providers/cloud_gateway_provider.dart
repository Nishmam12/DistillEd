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

/// A per-install anonymous key sent as `X-Device-Key`, used only for the
/// gateway's rate-limit counter — never a user identity. Session-lifetime
/// (regenerated each app launch) rather than persisted: the gateway isn't
/// deployed yet in this phase, so a daily cap that resets per-launch is a
/// harmless simplification, not a real gap. Revisit (persist via
/// SharedPreferences) once the gateway is actually deployed.
final String _sessionDeviceKey = _randomDeviceKey();

String _randomDeviceKey() {
  final rand = DateTime.now().microsecondsSinceEpoch ^ identityHashCode(Object());
  return 'device-${rand.toRadixString(16)}';
}

class CloudGatewayProvider implements AiProvider {
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
          headers: {'X-Device-Key': _sessionDeviceKey},
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
