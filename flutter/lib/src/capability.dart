import 'dart:io' show Platform;

import 'models.dart';

/// Which asset the inline preview should load, if any.
enum InlineKind {
  /// Android: Filament renders the GLB.
  glb,

  /// iOS: SceneKit renders the USDZ.
  usdz,

  /// Nothing renderable on this platform; show the still image.
  poster,

  /// Nothing at all.
  none,
}

enum ArMode { sceneViewer, quickLook, none }

/// What a device can actually do with a model.
///
/// The rules are not symmetric between platforms and getting them wrong yields
/// a blank canvas with no error, so they live in one place:
///
///   * There is no format both platforms read. SceneKit takes USDZ and cannot
///     open glTF; Filament takes GLB and cannot open USDZ. Every model is
///     therefore stored as both, and one of them is produced asynchronously.
///   * The consequence people miss: on iOS a missing USDZ costs the *preview*
///     too, not just the AR button. There is nothing an iPhone can draw.
class Presentation {
  const Presentation({
    required this.inlineKind,
    required this.inlineUrl,
    required this.arMode,
    required this.arSupported,
    required this.arReason,
    required this.blockedOnConversion,
  });

  final InlineKind inlineKind;
  final String? inlineUrl;
  final ArMode arMode;
  final bool arSupported;

  /// Why AR is unavailable, phrased to be shown to a user. Null when it is.
  final String? arReason;

  /// True when the only thing missing is the USDZ conversion — a state that
  /// resolves by itself in a minute or two, and the one case where "check back
  /// shortly" is honest rather than a permanent-looking failure.
  final bool blockedOnConversion;
}

/// Resolves what to render and whether AR can be offered.
///
/// [arAvailable] must come from the platform probe (`ARWorldTrackingConfiguration`
/// on iOS, `ArCoreApk.checkAvailability` on Android). Defaulting it to true
/// puts an AR button on handsets that cannot do AR, where tapping it opens the
/// Play Store instead of the camera.
Presentation resolvePresentation({
  required EmbedModel? model,
  required bool arAvailable,
  bool? isIosOverride,
}) {
  if (model == null) {
    return const Presentation(
      inlineKind: InlineKind.none,
      inlineUrl: null,
      arMode: ArMode.none,
      arSupported: false,
      arReason: 'This dish does not have a 3D model yet.',
      blockedOnConversion: false,
    );
  }

  final isIos = isIosOverride ?? Platform.isIOS;

  if (isIos) {
    if (model.usdzUrl == null) {
      final failed = model.usdzStatus == UsdzStatus.failed;
      return Presentation(
        // Poster, not GLB. SceneKit cannot open a GLB, so there is no mesh.
        inlineKind:
            model.posterUrl == null ? InlineKind.none : InlineKind.poster,
        inlineUrl: model.posterUrl,
        arMode: ArMode.none,
        arSupported: false,
        arReason: failed
            ? 'The AR version of this dish is unavailable.'
            : 'The AR version of this dish is still being prepared.',
        blockedOnConversion: !failed,
      );
    }

    return Presentation(
      inlineKind: InlineKind.usdz,
      inlineUrl: model.usdzUrl,
      arMode: arAvailable ? ArMode.quickLook : ArMode.none,
      arSupported: arAvailable,
      arReason: arAvailable
          ? null
          : 'This device does not support AR. You can still view the dish in 3D.',
      blockedOnConversion: false,
    );
  }

  /* -- Android ------------------------------------------------------------ */

  return Presentation(
    // Filament renders the GLB whether or not ARCore is present — a handset
    // without AR still gets a model it can spin, which is most of the value.
    inlineKind: InlineKind.glb,
    inlineUrl: model.glbUrl,
    arMode: arAvailable ? ArMode.sceneViewer : ArMode.none,
    arSupported: arAvailable,
    arReason: arAvailable
        ? null
        : 'This device does not support AR. You can still view the dish in 3D.',
    blockedOnConversion: false,
  );
}
