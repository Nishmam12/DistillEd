import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/tools/web_search_tool.dart';

class _FakeAdapter implements HttpClientAdapter {
  final String? jsonBody;
  final int statusCode;
  final DioException? throwsError;
  RequestOptions? lastOptions;

  _FakeAdapter({this.jsonBody, this.statusCode = 200, this.throwsError});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (throwsError != null) throw throwsError!;
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: statusCode),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      jsonBody!,
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

WebSearchTool _toolWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake-gateway'))
    ..httpClientAdapter = adapter;
  return WebSearchTool(
    baseUrl: 'http://fake-gateway',
    deviceKey: 'test-device',
    dio: dio,
  );
}

void main() {
  group('WebSearchTool', () {
    test('formats results with title, url, and snippet', () async {
      final adapter = _FakeAdapter(jsonBody: jsonEncode({
        'results': [
          {
            'title': 'Ada Lovelace',
            'url': 'https://en.wikipedia.org/wiki/Ada_Lovelace',
            'snippet': 'English mathematician and writer.',
          },
        ],
      }));
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'ada lovelace'});

      expect(result.success, isTrue);
      expect(result.content, contains('Ada Lovelace'));
      expect(result.content, contains('https://en.wikipedia.org/wiki/Ada_Lovelace'));
      expect(result.content, contains('English mathematician and writer.'));
    });

    test('sends the device key header and the query in the body', () async {
      final adapter = _FakeAdapter(jsonBody: jsonEncode({'results': []}));
      final tool = _toolWith(adapter);

      await tool.execute({'query': 'test query'});

      final sent = adapter.lastOptions!;
      expect(sent.path, contains('/v1/tools/search'));
      expect(sent.headers['X-Device-Key'], 'test-device');
      expect((sent.data as Map)['query'], 'test query');
    });

    test('an empty result set is a successful "no results" answer', () async {
      final adapter = _FakeAdapter(jsonBody: jsonEncode({'results': []}));
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'something obscure'});

      expect(result.success, isTrue);
      expect(result.content, contains('No web results found'));
    });

    test('a 429 maps to the daily-limit error, not a thrown exception',
        () async {
      final adapter = _FakeAdapter(statusCode: 429);
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'anything'});

      expect(result.success, isFalse);
      expect(result.content, contains('Daily'));
    });

    test('a 503 maps to the unconfigured error', () async {
      final adapter = _FakeAdapter(statusCode: 503);
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'anything'});

      expect(result.success, isFalse);
      expect(result.content, contains('not available'));
    });

    test('a connection failure is a clear error, not a thrown exception',
        () async {
      final adapter = _FakeAdapter(
        throwsError: DioException(
          requestOptions: RequestOptions(path: '/v1/tools/search'),
          type: DioExceptionType.connectionError,
        ),
      );
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'anything'});

      expect(result.success, isFalse);
      expect(result.content, contains('Web search failed'));
    });

    test('a missing query argument is a clear error, no network call',
        () async {
      final adapter = _FakeAdapter();
      final tool = _toolWith(adapter);

      final result = await tool.execute({});

      expect(result.success, isFalse);
      expect(adapter.lastOptions, isNull);
    });
  });
}
