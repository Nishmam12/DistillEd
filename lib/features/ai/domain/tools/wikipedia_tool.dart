// Looks up a short summary for a topic via Wikipedia's public REST API — no
// API key, no cost. Still a network call, so it only ever runs from the
// cloud-routed Research flow (see `researcher.dart`), behind the same
// confirm-cloud gate as any other network tool.

import 'package:dio/dio.dart';

import 'tool.dart';

class WikipediaTool implements Tool {
  static const _summaryBase =
      'https://en.wikipedia.org/api/rest_v1/page/summary';
  static const _searchBase = 'https://en.wikipedia.org/w/api.php';
  static const _maxExtractChars = 1200;

  final Dio _dio;

  WikipediaTool({Dio? dio}) : _dio = dio ?? Dio();

  @override
  String get name => 'wikipedia';

  @override
  String get description =>
      'Looks up a short summary of a topic on Wikipedia. Use this for '
      'factual/encyclopedic questions (people, places, concepts, history) '
      'your own knowledge might be outdated or unsure about.';

  @override
  Map<String, dynamic> get parameterSchema => const {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The topic to look up, e.g. "Ada Lovelace".',
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
    final trimmed = query.trim();
    try {
      final direct = await _trySummary(trimmed);
      final extract = direct ?? await _searchThenSummary(trimmed);
      if (extract == null || extract.trim().isEmpty) {
        return ToolExecutionResult.error(
            'No Wikipedia article found for "$trimmed".');
      }
      return ToolExecutionResult.ok(_truncate(extract));
    } on DioException catch (e) {
      return ToolExecutionResult.error('Wikipedia lookup failed: ${e.message}');
    }
  }

  /// Direct title lookup — cheap, one call, works whenever [title] is
  /// already a real page title. Returns null (not an error) on a 404 so the
  /// caller falls back to search instead of failing outright.
  Future<String?> _trySummary(String title) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '$_summaryBase/${Uri.encodeComponent(title)}',
      );
      return resp.data?['extract'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Resolves [query] to a real title via Wikipedia's search API, then
  /// fetches that title's summary — the fallback when [query] isn't itself
  /// an exact page title.
  Future<String?> _searchThenSummary(String query) async {
    final searchResp = await _dio.get<Map<String, dynamic>>(
      _searchBase,
      queryParameters: {
        'action': 'query',
        'list': 'search',
        'srsearch': query,
        'format': 'json',
        'srlimit': 1,
      },
    );
    final results =
        (searchResp.data?['query']?['search'] as List<dynamic>?) ?? const [];
    if (results.isEmpty) return null;
    final title = (results.first as Map<String, dynamic>)['title'] as String?;
    if (title == null) return null;
    return _trySummary(title);
  }

  String _truncate(String extract) => extract.length > _maxExtractChars
      ? '${extract.substring(0, _maxExtractChars)}...'
      : extract;
}
