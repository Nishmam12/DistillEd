// Checks a key the student has just typed, before it is saved: does the
// provider accept it, and which models can it use?
//
// Asking the provider for its model list does both at once, so the student
// ticks models from a list instead of typing an id. A provider with no such
// list falls back to a typed id, checked with one tiny request ([probe]).

import 'package:dio/dio.dart';

import '../../domain/ai_provider.dart';
import '../../domain/catalog/user_connection.dart';
import 'openai_compatible_provider.dart';

sealed class ConnectionTestResult {
  const ConnectionTestResult();
}

/// The key works. [modelIds] are the models it can use, in name order.
class ConnectionOk extends ConnectionTestResult {
  final List<String> modelIds;

  /// The context size of the models whose provider reported one. A model not
  /// in here keeps the conservative default: a prompt budgeted to a window
  /// larger than the real one overflows it.
  final Map<String, int> contextWindows;

  /// The models the provider says can call tools. A provider that does not
  /// say leaves this empty, and the student ticks it themselves.
  final Set<String> toolModels;

  const ConnectionOk(
    this.modelIds, {
    this.contextWindows = const {},
    this.toolModels = const {},
  });
}

/// The provider answered, but offers no list of models. The student types a
/// model id instead, and [ModelConnectionTester.probe] checks it.
class ConnectionNoModelList extends ConnectionTestResult {
  const ConnectionNoModelList();
}

class ConnectionFailed extends ConnectionTestResult {
  /// Safe to show: built here, never copied from the provider's reply.
  final String message;
  const ConnectionFailed(this.message);
}

class ModelConnectionTester {
  final Dio _dio;

  ModelConnectionTester({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: OpenAiCompatibleProvider.connectTimeout,
              receiveTimeout: const Duration(seconds: 20),
              followRedirects: false,
            ),
          );

  /// Asks the provider at [baseUrl] which models [apiKey] can use.
  Future<ConnectionTestResult> listModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final invalid = validateBaseUrl(baseUrl);
    if (invalid != null) return ConnectionFailed(invalid);

    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final host = Uri.parse(base).host;
    try {
      // OpenRouter's model list is public; it does not establish that the
      // supplied key works. Retain the default connection's explicit check.
      if (host == 'openrouter.ai') {
        await _dio.get<Object?>(
          '$base/key',
          options: Options(
            headers: {'Authorization': 'Bearer ${apiKey.trim()}'},
            followRedirects: false,
          ),
        );
      }
      final response = await _dio.get<dynamic>(
        '$base/models',
        options: Options(
          headers: {'Authorization': 'Bearer ${apiKey.trim()}'},
          followRedirects: false,
        ),
      );
      return _parseModelList(response.data) ?? const ConnectionNoModelList();
    } on DioException catch (e) {
      return switch (e.response?.statusCode) {
        401 || 403 => const ConnectionFailed(
          'The provider rejected the key. Check that it was copied in full.',
        ),
        // No such address: the provider simply has no model list.
        404 || 405 => const ConnectionNoModelList(),
        429 => const ConnectionFailed(
          "The provider's limit was reached. Try again in a moment.",
        ),
        null => ConnectionFailed("Couldn't reach $host."),
        final status => ConnectionFailed(
          'The provider answered with an error (HTTP $status).',
        ),
      };
    }
  }

  /// Checks that [modelId] answers, for a provider with no model list.
  Future<ConnectionTestResult> probe({
    required String baseUrl,
    required String apiKey,
    required String modelId,
    required String label,
  }) async {
    final invalid = validateBaseUrl(baseUrl);
    if (invalid != null) return ConnectionFailed(invalid);

    final provider = OpenAiCompatibleProvider.connection(
      baseUrl: baseUrl,
      modelId: modelId,
      displayName: modelId,
      label: label,
      contextWindowTokens: kUnknownModelWindowTokens,
      apiKey: () async => apiKey,
      dio: _dio,
    );
    try {
      await provider
          .generate(
            prompt: 'Hi',
            options: const AiGenerationOptions(maxTokens: 8),
          )
          .drain<void>();
      return ConnectionOk([modelId]);
    } on AiException catch (e) {
      return ConnectionFailed(e.message);
    }
  }

  /// Reads an OpenAI-style model list (`{"data": [{"id": …}]}`), or null when
  /// [data] is not one.
  ///
  /// Beyond the id, two things are picked up when a provider offers them, under
  /// the names providers actually use: the context size (`context_length` or
  /// `context_window`) and whether `tools` is among `supported_parameters`.
  static ConnectionOk? _parseModelList(Object? data) {
    final list = data is Map<String, dynamic> ? data['data'] : data;
    if (list is! List) return null;
    final ids = <String>[];
    final windows = <String, int>{};
    final tools = <String>{};
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final rawId = item['id'];
      if (rawId is! String || rawId.isEmpty) continue;
      final id = rawId.startsWith('models/') ? rawId.substring(7) : rawId;
      if (ids.contains(id)) continue;
      ids.add(id);
      final window =
          item['context_length'] ??
          item['context_window'] ??
          item['max_context_length'];
      if (window is int && window > 0) windows[id] = window;
      final supported = item['supported_parameters'];
      if (supported is List && supported.contains('tools')) tools.add(id);
    }
    ids.sort();
    return ConnectionOk(ids, contextWindows: windows, toolModels: tools);
  }
}
