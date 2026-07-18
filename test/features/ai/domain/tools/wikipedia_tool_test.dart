import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/tools/wikipedia_tool.dart';

class _StubResponse {
  final int statusCode;
  final Map<String, dynamic>? json;
  const _StubResponse.ok(this.json) : statusCode = 200;
  const _StubResponse.notFound()
      : statusCode = 404,
        json = null;
}

/// Matches requests by a substring of the URL — enough to distinguish the
/// direct summary lookup from the search fallback without modeling dio's
/// real HTTP status pipeline. Same "hand-written fake at the boundary"
/// pattern as `cloud_gateway_provider_test.dart`'s `_FakeAdapter`.
class _FakeAdapter implements HttpClientAdapter {
  final List<MapEntry<String, _StubResponse>> routes;
  final DioException? alwaysThrow;
  final List<String> requestedUrls = [];

  _FakeAdapter(this.routes, {this.alwaysThrow});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requestedUrls.add(url);
    if (alwaysThrow != null) throw alwaysThrow!;
    for (final route in routes) {
      if (url.contains(route.key)) {
        final stub = route.value;
        if (stub.statusCode >= 400) {
          throw DioException(
            requestOptions: options,
            response:
                Response(requestOptions: options, statusCode: stub.statusCode),
            type: DioExceptionType.badResponse,
          );
        }
        return ResponseBody.fromString(
          jsonEncode(stub.json),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      }
    }
    throw StateError('No fake route matched: $url');
  }

  @override
  void close({bool force = false}) {}
}

WikipediaTool _toolWith(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return WikipediaTool(dio: dio);
}

void main() {
  group('WikipediaTool', () {
    test('a direct title hit returns the extract without a search call',
        () async {
      final adapter = _FakeAdapter(const [
        MapEntry('rest_v1/page/summary', _StubResponse.ok(
            {'extract': 'Ada Lovelace was an English mathematician.'})),
      ]);
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'Ada Lovelace'});

      expect(result.success, isTrue);
      expect(result.content, 'Ada Lovelace was an English mathematician.');
      expect(adapter.requestedUrls, hasLength(1),
          reason: 'a direct hit must not also call the search API');
    });

    test('falls back to search when the direct title 404s', () async {
      final adapter = _FakeAdapter(const [
        MapEntry('rest_v1/page/summary/mitocondria', _StubResponse.notFound()),
        MapEntry(
          'w/api.php',
          _StubResponse.ok({
            'query': {
              'search': [
                {'title': 'Mitochondrion'},
              ],
            },
          }),
        ),
        MapEntry('rest_v1/page/summary/Mitochondrion',
            _StubResponse.ok({'extract': 'The powerhouse of the cell.'})),
      ]);
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'mitocondria'});

      expect(result.success, isTrue);
      expect(result.content, 'The powerhouse of the cell.');
      expect(adapter.requestedUrls, hasLength(3));
    });

    test('no results anywhere is a clear "not found" error, not a crash',
        () async {
      final adapter = _FakeAdapter(const [
        MapEntry('rest_v1/page/summary/qwxyz', _StubResponse.notFound()),
        MapEntry('w/api.php', _StubResponse.ok({
              'query': {'search': []},
            })),
      ]);
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'qwxyz'});

      expect(result.success, isFalse);
      expect(result.content, contains('No Wikipedia article found'));
    });

    test('a network failure is a clear error, not a thrown exception',
        () async {
      final adapter = _FakeAdapter(
        const [],
        alwaysThrow: DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      );
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'anything'});

      expect(result.success, isFalse);
      expect(result.content, contains('Wikipedia lookup failed'));
    });

    test('a missing query argument is a clear error, no network call',
        () async {
      final adapter = _FakeAdapter(const []);
      final tool = _toolWith(adapter);

      final result = await tool.execute({});

      expect(result.success, isFalse);
      expect(adapter.requestedUrls, isEmpty);
    });

    test('a very long extract is truncated', () async {
      final longExtract = 'x' * 5000;
      final adapter = _FakeAdapter([
        MapEntry('rest_v1/page/summary', _StubResponse.ok({'extract': longExtract})),
      ]);
      final tool = _toolWith(adapter);

      final result = await tool.execute({'query': 'anything'});

      expect(result.content.length, lessThan(longExtract.length));
    });
  });
}
