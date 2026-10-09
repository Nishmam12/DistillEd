// Calls the gateway's `POST /v1/tools/search` (which proxies Exa) — never
// talks to Exa directly, so the API key never reaches the client. Same
// `X-Device-Key` header as `CloudGatewayProvider`, but a genuinely separate
// daily cap server-side (see `server/ai-gateway/app/rate_limit.py`'s
// `SearchRateLimiter`) — a chatty LLM day must not block search access.

import 'package:dio/dio.dart';

import '../untrusted_text.dart';
import 'tool.dart';

class WebSearchTool implements Tool {
  final Dio _dio;
  final String _baseUrl;
  final String _deviceKey;
  final bool Function() _isCloudAllowed;

  WebSearchTool({
    required String baseUrl,
    required String deviceKey,
    Dio? dio,
    bool Function()? isCloudAllowed,
  })  : _baseUrl = baseUrl,
        _deviceKey = deviceKey,
        _isCloudAllowed = isCloudAllowed ?? (() => true),
        _dio = dio ?? Dio();

  @override
  String get name => 'web_search';

  @override
  String get description =>
      'Searches the web for current or specific information your own '
      'knowledge might not cover — recent events, niche facts, or anything '
      'time-sensitive. Returns a handful of titles, URLs, and snippets.';

  @override
  Map<String, dynamic> get parameterSchema => const {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The search query.',
          },
        },
        'required': ['query'],
      };

  @override
  Future<ToolExecutionResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'];
    if (query is! String || query.trim().isEmpty) {
      return const ToolExecutionResult.error(
          'Missing or empty "query" argument.');
    }
    if (!_isCloudAllowed()) {
      return const ToolExecutionResult.error(
          'Cloud AI is turned off in Settings, so web search is unavailable.');
    }
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/v1/tools/search',
        data: {'query': query.trim()},
        options: Options(headers: {'X-Device-Key': _deviceKey}),
      );
      final results = (resp.data?['results'] as List<dynamic>?) ?? const [];
      if (results.isEmpty) {
        return ToolExecutionResult.ok('No web results found for "$query".');
      }
      final formatted = results
          .cast<Map<String, dynamic>>()
          .map((r) => '- ${r['title']} (${r['url']})\n  ${r['snippet']}')
          .join('\n');
      // Web pages are written by strangers: fenced, so the model treats them as
      // material to read, not instructions to follow.
      return ToolExecutionResult.ok(fenceUntrusted(formatted));
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        return const ToolExecutionResult.error(
            'Daily web search limit reached for this device. Try again '
            'tomorrow.');
      }
      if (e.response?.statusCode == 503) {
        return const ToolExecutionResult.error(
            'Web search is not available right now.');
      }
      return ToolExecutionResult.error('Web search failed: ${e.message}');
    }
  }
}
