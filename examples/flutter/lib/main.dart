import 'package:armenus/armenus.dart';
import 'package:flutter/material.dart';

import 'dish_screen.dart';
import 'menu_screen.dart';

/// Armenus Flutter example.
///
/// Native rendering on both platforms — SceneKit on iOS, Filament on Android —
/// with AR handed to the system viewer. No WebView anywhere.
///
/// The key is read from --dart-define so the example can point at your data:
///
///   flutter run --dart-define=ARMENUS_KEY=pk_live_...
const armenusKey = String.fromEnvironment('ARMENUS_KEY');
const armenusBaseUrl = String.fromEnvironment('ARMENUS_BASE_URL');
const armenusMerchantId = String.fromEnvironment('ARMENUS_MERCHANT_ID');

void main() => runApp(const ArmenusExample());

class ArmenusExample extends StatefulWidget {
  const ArmenusExample({super.key});

  @override
  State<ArmenusExample> createState() => _ArmenusExampleState();
}

class _ArmenusExampleState extends State<ArmenusExample> {
  ArmenusClient? _client;
  String? _setupError;

  @override
  void initState() {
    super.initState();
    if (armenusKey.isEmpty) {
      _setupError =
          'Pass a publishable key:\n\n'
          'flutter run --dart-define=ARMENUS_KEY=pk_live_...';
      return;
    }
    // The constructor throws on a secret `ak_` key rather than letting it
    // work — which it otherwise would, all the way into production.
    _client = ArmenusClient(
      publishableKey: armenusKey,
      baseUrl: armenusBaseUrl.isEmpty
          ? 'https://api.armenus.app/v1'
          : armenusBaseUrl,
    );
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Armenus example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC0392B)),
        scaffoldBackgroundColor: const Color(0xFFFAF8F4),
      ),
      home: _setupError != null
          ? _Setup(message: _setupError!)
          : MenuScreen(
              client: _client!,
              merchantId: armenusMerchantId.isEmpty ? null : armenusMerchantId,
              onSelect: (item) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DishScreen(item: item),
                ),
              ),
            ),
    );
  }
}

class _Setup extends StatelessWidget {
  const _Setup({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
