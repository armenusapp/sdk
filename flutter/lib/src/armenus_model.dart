import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'armenus_ar.dart';
import 'capability.dart';
import 'models.dart';

/// A dish in 3D, with AR where the handset supports it.
///
/// Fully native on both platforms. The preview is a platform view hosting
/// SceneKit (iOS) or Filament (Android); AR hands off to the system viewer.
/// No WebView is involved — a WebView here would mean a second renderer, its
/// own process, JavaScript-bridged touch handling and a visible pop-in, and
/// would buy nothing, because both platforms already expose AR natively.
class ArmenusModel extends StatefulWidget {
  const ArmenusModel({
    super.key,
    required this.item,
    this.arLabel = 'View on your table',
    this.interactionEnabled = true,
    this.aspectRatio = 1,
    this.onEnterAr,
    this.onError,
  });

  /// The dish to render. Null renders the loading state.
  final EmbedItem? item;
  final String arLabel;

  /// Whether a drag rotates the model.
  ///
  /// Pass false inside a ListView. On a phone the gesture arenas fight, and a
  /// card that swallows vertical drags makes the whole feed feel stuck — a
  /// worse trade than losing the spin on a card being scrolled past.
  final bool interactionEnabled;
  final double aspectRatio;
  final void Function(EmbedItem item)? onEnterAr;
  final void Function(String message)? onError;

  @override
  State<ArmenusModel> createState() => _ArmenusModelState();
}

class _ArmenusModelState extends State<ArmenusModel> {
  bool _arAvailable = false;
  bool _loaded = false;
  bool _failed = false;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    ArmenusAr.isArAvailable().then((available) {
      if (mounted) setState(() => _arAvailable = available);
    });
  }

  @override
  void didUpdateWidget(ArmenusModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.model?.id != widget.item?.model?.id ||
        oldWidget.item?.model?.glbUrl != widget.item?.model?.glbUrl ||
        oldWidget.item?.model?.usdzUrl != widget.item?.model?.usdzUrl) {
      // A recycled card now showing a different dish must not keep the old
      // one's load state, or the poster never reappears while the new mesh
      // downloads.
      _loaded = false;
      _failed = false;
    }
  }

  Presentation get _presentation => resolvePresentation(
        model: widget.item?.model,
        arAvailable: _arAvailable,
        isIosOverride: defaultTargetPlatform == TargetPlatform.iOS,
      );

  Future<void> _enterAr() async {
    final item = widget.item;
    if (item == null || _presenting) return;

    final url = defaultTargetPlatform == TargetPlatform.iOS
        ? item.model?.usdzUrl
        : item.model?.glbUrl;
    if (url == null) return;

    setState(() => _presenting = true);
    widget.onEnterAr?.call(item);

    try {
      await ArmenusAr.presentAr(
        url: url,
        title: item.name,
        // Life-size and fixed: the mesh is already scaled to the real dish.
        allowScaling: false,
      );
    } on PlatformException catch (error) {
      widget.onError?.call(error.message ?? 'AR could not be opened');
    } finally {
      if (mounted) setState(() => _presenting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation;
    final settings = widget.item?.model?.viewSettings;
    final renderable = presentation.inlineKind == InlineKind.glb ||
        presentation.inlineKind == InlineKind.usdz;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFF4F2F3)),
                if (renderable && !_failed && settings != null)
                  _NativeModelView(
                    // Native creation parameters are read once. Recreate the
                    // view when its model or display settings change.
                    key: ValueKey((
                      presentation.inlineUrl,
                      settings.cameraOrbit,
                      settings.exposure,
                      settings.shadowIntensity,
                      settings.autoRotate,
                      widget.interactionEnabled,
                    )),
                    source: presentation.inlineUrl!,
                    settings: settings,
                    interactionEnabled: widget.interactionEnabled,
                    onLoad: () {
                      if (mounted) setState(() => _loaded = true);
                    },
                    onError: (message) {
                      if (mounted) setState(() => _failed = true);
                      widget.onError?.call(message);
                    },
                  ),

                // The poster stays mounted beneath the canvas until the mesh
                // reports in, so there is never a blank frame between them.
                if (!_loaded || !renderable || _failed)
                  _Poster(
                    url: presentation.inlineKind == InlineKind.poster
                        ? presentation.inlineUrl
                        : widget.item?.model?.posterUrl ??
                            widget.item?.imageUrl,
                    spinning: renderable && !_failed && !_loaded,
                  ),

                if (presentation.arSupported)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FilledButton(
                        onPressed: _presenting ? null : _enterAr,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          // 44dp minimum touch target.
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(widget.arLabel),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (presentation.arReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              presentation.arReason!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B5555)),
            ),
          ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.spinning});

  final String? url;
  final bool spinning;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          if (url != null) Image.network(url!, fit: BoxFit.contain),
          if (spinning) const Center(child: CircularProgressIndicator()),
        ],
      );
}

/// The platform view itself.
///
/// Hybrid composition on Android (`PlatformViewLink` with
/// `AndroidViewSurface`), which is what lets a Filament surface composite
/// correctly with Flutter widgets drawn above it — the AR button here sits on
/// top of the canvas, and virtual-display mode gets that wrong.
class _NativeModelView extends StatefulWidget {
  const _NativeModelView({
    super.key,
    required this.source,
    required this.settings,
    required this.interactionEnabled,
    required this.onLoad,
    required this.onError,
  });

  final String source;
  final ModelViewSettings settings;
  final bool interactionEnabled;
  final VoidCallback onLoad;
  final void Function(String message) onError;

  @override
  State<_NativeModelView> createState() => _NativeModelViewState();
}

class _NativeModelViewState extends State<_NativeModelView> {
  static const String _viewType = 'app.armenus/model-view';
  MethodChannel? _channel;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Map<String, dynamic> get _params => {
        'source': widget.source,
        'cameraOrbitTheta': widget.settings.orbitDegrees(0, 0),
        'cameraOrbitPhi': widget.settings.orbitDegrees(1, 75),
        'exposure': widget.settings.exposure,
        'shadowIntensity': widget.settings.shadowIntensity,
        'autoRotate': widget.settings.autoRotate,
        'interactionEnabled': widget.interactionEnabled,
      };

  void _wireChannel(int id) {
    if (!mounted) return;
    _channel = MethodChannel('app.armenus/model-view/$id');
    _channel!.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'onModelLoad':
          widget.onLoad();
        case 'onModelError':
          widget.onError(
            (call.arguments as Map?)?['message'] as String? ?? 'Load failed',
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: _viewType,
        creationParams: _params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _wireChannel,
      );
    }

    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: widget.interactionEnabled
            ? const <Factory<OneSequenceGestureRecognizer>>{}
            // With no recognisers claimed, vertical drags fall through to the
            // enclosing scrollable — which is what a card in a feed wants.
            : const <Factory<OneSequenceGestureRecognizer>>{},
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: _params,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener(
          params.onPlatformViewCreated,
        );
        controller.addOnPlatformViewCreatedListener(_wireChannel);
        return controller..create();
      },
    );
  }
}
