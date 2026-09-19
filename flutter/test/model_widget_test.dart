import 'package:armenus/armenus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

EmbedItem dish(String id) => EmbedItem(
      id: id,
      slug: id,
      externalRef: null,
      name: id,
      description: null,
      priceCents: 100,
      tags: const [],
      imageUrl: null,
      isAvailable: true,
      merchant: const EmbedMerchant(
        id: 'r',
        slug: 'r',
        name: 'Restaurant',
        currency: 'USD',
        locale: 'en',
      ),
      model: EmbedModel(
        id: id,
        glbUrl: 'https://example.com/$id.glb',
        usdzUrl: 'https://example.com/$id.usdz',
        usdzStatus: UsdzStatus.ready,
        posterUrl: null,
        physicalSizeM: .25,
        glbBytes: null,
        viewSettings: ModelViewSettings.fromJson({}),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('app.armenus/ar'),
      (call) async => false,
    );
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('app.armenus/ar'),
      null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('recycled cards recreate the native view for the new dish', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    Widget app(String id) => MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, child: ArmenusModel(item: dish(id))),
          ),
        );
    await tester.pumpWidget(app('first'));
    await tester.pump();
    await tester.pumpWidget(app('second'));
    await tester.pump();
    final creates = calls.where((c) => c.method == 'create').toList();
    expect(creates, hasLength(2));
    final args = creates.last.arguments as Map;
    final params = const StandardMessageCodec().decodeMessage(
      ByteData.sublistView(args['params'] as Uint8List),
    ) as Map;
    expect(params['source'], 'https://example.com/second.usdz');
    expect(calls.any((c) => c.method == 'dispose'), true);
    expect(find.byType(FilledButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('missing native AR support safely shows the non-AR state', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('app.armenus/ar'),
      null,
    );
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(width: 200, child: ArmenusModel(item: null)))));
    await tester.pump();
    expect(
      find.text('This dish does not have a 3D model yet.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
