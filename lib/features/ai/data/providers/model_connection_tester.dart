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
  const ConnectionOk(this.modelIds);
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
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: OpenAiCompatibleProvider.connectTimeout,
              receiveTimeout: const Duration(seconds: 20),
            ));

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
      final response = await _dio.get<dynamic>(
        '$base/models',
        options: Options(headers: {'Authorization': 'Bearer ${apiKey.trim()}'}),
      );
      final ids = _modelIds(response.data);
      return ids == null ? const ConnectionNoModelList() : ConnectionOk(ids);
    } on DioException catch (e) {
      return switch (e.response?.statusCode) {
        401 || 403 => const ConnectionFailed(
            'The provider rejected the key. Check that it was copied in full.'),
        // No such address: the provider simply has no model list.
        404 || 405 => const ConnectionNoModelList(),
        429 => const ConnectionFailed(
            "The provider's limit was reached. Try again in a moment."),
        null => ConnectionFailed("Couldn't reach $host."),
        final status =>
          ConnectionFailed('The provider answered with an error (HTTP $status).'),
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

    final provider = OpenAiCompatibleProvider(
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

  /// The ids in an OpenAI-style model list (`{"data": [{"id": …}]}`), or null
  /// when [data] is not one.
  static List<String>? _modelIds(Object? data) {
    final list = data is Map<String, dynamic> ? data['data'] : data;
    if (list is! List) return null;
    final ids = <String>[
      for (final item in list)
        if (item is Map<String, dynamic> && item['id'] is String)
          item['id'] as String,
    ]..sort();
    return ids;
  }
}
