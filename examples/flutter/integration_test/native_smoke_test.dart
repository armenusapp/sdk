import 'dart:io';

import 'package:armenus/armenus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native cache, capability probe, rendering and model replacement',
    (tester) async {
      final extension = Platform.isIOS ? 'usdz' : 'glb';
      final bytes = await rootBundle.load('assets/triangle.$extension');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType(
          'model',
          Platform.isIOS ? 'vnd.usdz+zip' : 'gltf-binary',
        );
        request.response.add(bytes.buffer.asUint8List());
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final url = 'http://127.0.0.1:${server.port}/triangle.$extension';
      await ArmenusAr.clearCache();
      expect(await ArmenusAr.cacheSize(), 0);
      expect(await ArmenusAr.isArAvailable(), isA<bool>());
      final path = await ArmenusAr.prefetch(url);
      expect(path, isNotNull);
      expect(await File(path!).length(), bytes.lengthInBytes);
      expect(await ArmenusAr.prefetch(url), path);
      expect(requests, 1, reason: 'The second prefetch must reuse the cache');
      expect(await ArmenusAr.cacheSize(), greaterThan(0));

      final errors = <String>[];
      EmbedItem item(String id) => EmbedItem(
        id: id,
        slug: id,
        externalRef: null,
        name: 'Native test model',
        description: null,
        priceCents: 100,
        tags: const [],
        imageUrl: null,
        isAvailable: true,
        merchant: const EmbedMerchant(
          id: 'restaurant',
          slug: 'restaurant',
          name: 'Test restaurant',
          currency: 'USD',
          locale: 'en',
        ),
        model: EmbedModel(
          id: id,
          glbUrl: '$url?model=$id',
          usdzUrl: '$url?model=$id',
          usdzStatus: UsdzStatus.ready,
          posterUrl: null,
          physicalSizeM: .2,
          glbBytes: bytes.lengthInBytes,
          viewSettings: ModelViewSettings.fromJson({'autoRotate': false}),
        ),
      );
      for (final id in ['first', 'second']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 250,
                child: ArmenusModel(item: item(id), onError: errors.add),
              ),
            ),
          ),
        );
        for (var i = 0; i < 600; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }
        expect(errors, isEmpty, reason: 'The native model loader must succeed');
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'The native onModelLoad event must reach Dart',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await ArmenusAr.clearCache();
      expect(await ArmenusAr.cacheSize(), 0);
    },
  );
}
