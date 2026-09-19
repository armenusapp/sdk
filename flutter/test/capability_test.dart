import 'package:armenus/armenus.dart';
import 'package:flutter_test/flutter_test.dart';

EmbedModel model({String? usdz, UsdzStatus status = UsdzStatus.pending}) =>
    EmbedModel(
      id: 'model',
      glbUrl: 'https://example.com/model.glb',
      usdzUrl: usdz,
      usdzStatus: status,
      posterUrl: 'https://example.com/poster.webp',
      physicalSizeM: .25,
      glbBytes: 100,
      viewSettings: ModelViewSettings.fromJson({}),
    );

void main() {
  test('iOS waits for USDZ instead of passing GLB to SceneKit', () {
    final result = resolvePresentation(
      model: model(),
      arAvailable: true,
      isIosOverride: true,
    );
    expect(result.inlineKind, InlineKind.poster);
    expect(result.arSupported, false);
    expect(result.blockedOnConversion, true);
  });
  test('failed conversion is not described as still processing', () {
    final result = resolvePresentation(
      model: model(status: UsdzStatus.failed),
      arAvailable: true,
      isIosOverride: true,
    );
    expect(result.blockedOnConversion, false);
    expect(result.arReason, contains('unavailable'));
  });
  test('iOS keeps 3D available on a device without AR', () {
    final result = resolvePresentation(
      model: model(usdz: 'https://example.com/model.usdz'),
      arAvailable: false,
      isIosOverride: true,
    );
    expect(result.inlineKind, InlineKind.usdz);
    expect(result.arSupported, false);
  });
  test('Android renders GLB without ARCore', () {
    final result = resolvePresentation(
      model: model(),
      arAvailable: false,
      isIosOverride: false,
    );
    expect(result.inlineKind, InlineKind.glb);
    expect(result.arSupported, false);
  });
  test('supported platforms select the matching AR viewer', () {
    expect(
      resolvePresentation(
        model: model(),
        arAvailable: true,
        isIosOverride: false,
      ).arMode,
      ArMode.sceneViewer,
    );
    expect(
      resolvePresentation(
        model: model(usdz: 'https://example.com/model.usdz'),
        arAvailable: true,
        isIosOverride: true,
      ).arMode,
      ArMode.quickLook,
    );
  });
  test('a dish without a model has no AR action', () {
    expect(
      resolvePresentation(model: null, arAvailable: true).arSupported,
      false,
    );
  });
  test('camera angles accept radians and default invalid values', () {
    final settings = ModelViewSettings.fromJson({
      'cameraOrbit': '3.141592653589793rad invalid auto',
    });
    expect(settings.orbitDegrees(0, 0), closeTo(180, .0001));
    expect(settings.orbitDegrees(1, 75), 75);
  });
}
