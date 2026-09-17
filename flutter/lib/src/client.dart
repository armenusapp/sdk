import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'models.dart';

/// A failure from the Armenus API, carrying its machine-readable code.
///
/// Integrators branch on *why* far more often than they read a message: a
/// revoked key and a dish with no model are both "no 3D appeared", and they
/// call for opposite responses.
class ArmenusException implements Exception {
  ArmenusException(this.status, this.code, this.message);

  /// HTTP status, or 0 when the request never reached the API.
  final int status;
  final String code;
  final String message;

  /// True when retrying could plausibly work.
  bool get isRetryable => status == 0 || status == 429 || status >= 500;

  /// True when the key itself is the problem — worth logging loudly, since
  /// every dish will fail rather than just this one.
  bool get isAuthError => status == 401 || status == 403;

  @override
  String toString() => 'ArmenusException($status $code): $message';
}

/// Read-only client for the Armenus embed API.
///
/// Takes a publishable key, which is public by construction — it ships inside
/// your app bundle and anyone can read it out. Its safety comes from scope, not
/// secrecy: read-only, confined to your merchants, quota-limited and revocable.
/// Never put a secret `ak_` key here.
class ArmenusClient {
  ArmenusClient({
    required this.publishableKey,
    this.baseUrl = 'https://api.armenus.app/v1',
    this.timeout = const Duration(seconds: 8),
    this.retries = 2,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client() {
    if (!publishableKey.startsWith('pk_')) {
      /*
       * Thrown at construction, not on first request. The common integration
       * mistake is pasting the secret key into app code — it would work, which
       * is exactly the problem, and it would keep working into production.
       */
      throw ArgumentError(
        publishableKey.startsWith('ak_')
            ? 'That is a secret API key. Never ship an ak_ key in an app — use a publishable pk_ key.'
            : 'A publishable key (pk_...) is required.',
      );
    }
  }

  final String publishableKey;
  final String baseUrl;
  final Duration timeout;
  final int retries;
  final http.Client _http;

  /// What this key can see. Call once at startup so a revoked or mistyped key
  /// fails loudly rather than presenting as an empty catalogue.
  Future<EmbedConfig> config() async =>
      EmbedConfig.fromJson(await _get('/embed/config'));

  /// One dish, by Armenus id.
  Future<EmbedItem> item(String itemId) async =>
      EmbedItem.fromJson(await _get('/embed/items/${Uri.encodeComponent(itemId)}'));

  /// One dish, by your own identifier — so you never have to store ours.
  Future<EmbedItem> itemByRef(String merchantId, String externalRef) async =>
      EmbedItem.fromJson(await _get(
        '/embed/merchants/${Uri.encodeComponent(merchantId)}'
        '/items/by-ref/${Uri.encodeComponent(externalRef)}',
      ));

  /// Every dish on a merchant.
  Future<List<EmbedItem>> items(
    String merchantId, {
    bool? withModel,
    int? limit,
    int? offset,
  }) async {
    final query = <String, String>{
      if (withModel == true) 'withModel': 'true',
      if (limit != null) 'limit': '$limit',
      if (offset != null) 'offset': '$offset',
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final json = await _get(
      '/embed/merchants/${Uri.encodeComponent(merchantId)}/items$suffix',
    );
    return (json['items'] as List)
        .map((i) => EmbedItem.fromJson((i as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Several dishes at once. A grid needs twenty models, and twenty round
  /// trips from a phone on restaurant wifi is the difference between a grid
  /// that pops in and one that trickles. Capped at 50 by the API.
  Future<List<EmbedItem>> itemsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final json = await _get('/embed/items?ids=${ids.map(Uri.encodeComponent).join(',')}');
    return (json['items'] as List)
        .map((i) => EmbedItem.fromJson((i as Map).cast<String, dynamic>()))
        .toList();
  }

  void close() => _http.close();

  /* -- transport ---------------------------------------------------------- */

  Future<Map<String, dynamic>> _get(String path) async {
    ArmenusException? last;

    for (var attempt = 0; attempt < max(1, retries); attempt++) {
      try {
        final response = await _http.get(
          Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path'),
          headers: {
            'authorization': 'Bearer $publishableKey',
            'accept': 'application/json',
          },
        ).timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return (jsonDecode(response.body) as Map).cast<String, dynamic>();
        }

        // The API always sends a JSON error body, but a proxy or captive
        // portal in between may not — so parsing it must never be the thing
        // that produces the error the caller sees.
        String code = 'http_error';
        String message = 'Request failed with status ${response.statusCode}';
        try {
          final body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
          code = body['error'] as String? ?? code;
          message = body['message'] as String? ?? message;
        } catch (_) {}

        throw ArmenusException(response.statusCode, code, message);
      } on ArmenusException catch (error) {
        if (!error.isRetryable) rethrow;
        last = error;
      } catch (error) {
        last = ArmenusException(0, 'network_error', error.toString());
      }

      if (attempt < max(1, retries) - 1) {
        // Exponential and jittered. Without jitter, a restaurant full of
        // phones that all failed on one blip retries in lockstep and
        // reproduces it.
        final backoff = 200 * (1 << attempt);
        await Future<void>.delayed(
          Duration(milliseconds: backoff + Random().nextInt(backoff)),
        );
      }
    }

    throw last ?? ArmenusException(0, 'network_error', 'Request failed');
  }
}
