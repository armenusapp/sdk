import 'package:flutter/services.dart';

/// The platform channel: AR handoff and the mesh cache.
///
/// Opens Apple's built-in Quick Look viewer on iOS and Google's Scene Viewer
/// on Android. The SDK downloads and caches model files for these viewers.
class ArmenusAr {
  static const MethodChannel _channel = MethodChannel('app.armenus/ar');

  /// Whether this handset can do AR at all.
  ///
  /// Checks AR world-tracking support on iOS. On Android, checks whether
  /// Scene Viewer can open; the viewer can fall back to 3D without AR.
  static Future<bool> isArAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isArAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      // A failed probe is a "no". An AR button on a handset that cannot do AR
      // sends the user to the Play Store, which reads as a broken app.
      return false;
    }
  }

  /// Downloads a model and returns a local path, from cache when possible.
  ///
  /// Worth calling before the AR button is visible. Quick Look will not read a
  /// remote URL, so the download happens either way — only its timing is
  /// yours to choose, and choosing early is the difference between a button
  /// that opens instantly and one that stalls while the user wonders whether
  /// the tap registered.
  static Future<String?> prefetch(String url) async {
    try {
      return await _channel.invokeMethod<String>('prefetch', {'url': url});
    } on PlatformException {
      return null;
    }
  }

  /// Presents the system AR viewer.
  ///
  /// [url] is a USDZ on iOS and a GLB on Android — the platforms read
  /// different formats, and `resolvePresentation` is what decides which.
  ///
  /// [allowScaling] defaults to false because the model is already scaled to
  /// the dish's real size, which is the entire question the diner is asking.
  /// Letting them pinch it turns the answer back into a guess.
  static Future<void> presentAr({
    required String url,
    required String title,
    bool allowScaling = false,
  }) =>
      _channel.invokeMethod<void>('presentAr', {
        'url': url,
        'title': title,
        'allowScaling': allowScaling,
      });

  /// Bytes currently held on disk, so a host app can show and manage it.
  static Future<int> cacheSize() async =>
      await _channel.invokeMethod<int>('cacheSize') ?? 0;

  static Future<void> clearCache() => _channel.invokeMethod<void>('clearCache');
}
