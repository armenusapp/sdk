import 'dart:convert';

import 'package:armenus/armenus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('rejects secret keys before making a request', () {
    expect(
      () => ArmenusClient(publishableKey: 'ak_secret'),
      throwsArgumentError,
    );
  });

  test(
    'loads restaurants with authorization and a normalized base URL',
    () async {
      final client = ArmenusClient(
        publishableKey: 'pk_test',
        baseUrl: 'https://example.com/v1/',
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://example.com/v1/embed/config');
          expect(request.headers['authorization'], 'Bearer pk_test');
          return http.Response(
            jsonEncode({
              'scope': 'merchant',
              'ownerName': 'Restaurant',
              'merchants': [
                {
                  'id': 'restaurant-1',
                  'slug': 'restaurant',
                  'name': 'Restaurant',
                  'currency': 'USD',
                  'locale': 'en',
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      expect((await client.config()).merchants.single.id, 'restaurant-1');
    },
  );

  test('encodes restaurant IDs and list filters', () async {
    final client = ArmenusClient(
      publishableKey: 'pk_test',
      httpClient: MockClient((request) async {
        expect(request.url.pathSegments, [
          'v1',
          'embed',
          'merchants',
          'a/b',
          'items',
        ]);
        expect(request.url.queryParameters, {
          'withModel': 'true',
          'limit': '5',
          'offset': '10',
        });
        return http.Response('{"items":[]}', 200);
      }),
    );
    addTearDown(client.close);
    expect(
      await client.items('a/b', withModel: true, limit: 5, offset: 10),
      isEmpty,
    );
  });

  test('does not request an empty batch', () async {
    final client = ArmenusClient(
      publishableKey: 'pk_test',
      httpClient: MockClient((_) async {
        fail('An empty batch should not make a request');
      }),
    );
    addTearDown(client.close);
    expect(await client.itemsByIds([]), isEmpty);
  });

  test('does not retry revoked keys and preserves the API error', () async {
    var calls = 0;
    final client = ArmenusClient(
      publishableKey: 'pk_test',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(
          '{"error":"key_revoked","message":"Key revoked"}',
          403,
        );
      }),
    );
    addTearDown(client.close);
    await expectLater(
      client.config(),
      throwsA(
        isA<ArmenusException>()
            .having((e) => e.code, 'code', 'key_revoked')
            .having((e) => e.isAuthError, 'isAuthError', true),
      ),
    );
    expect(calls, 1);
  });

  test('retries a temporary server failure', () async {
    var calls = 0;
    final client = ArmenusClient(
      publishableKey: 'pk_test',
      httpClient: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('Unavailable', 503)
            : http.Response('{"items":[]}', 200);
      }),
    );
    addTearDown(client.close);
    expect(await client.items('restaurant'), isEmpty);
    expect(calls, 2);
  });

  test('reports transport errors as retryable SDK exceptions', () async {
    final client = ArmenusClient(
      publishableKey: 'pk_test',
      retries: 1,
      httpClient: MockClient(
        (_) async => throw http.ClientException('Offline'),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      client.config(),
      throwsA(
        isA<ArmenusException>()
            .having((e) => e.code, 'code', 'network_error')
            .having((e) => e.isRetryable, 'isRetryable', true),
      ),
    );
  });
}
