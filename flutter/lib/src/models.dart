/// Wire types for the Armenus embed API.
///
/// Hand-written rather than generated, for the same reason the TypeScript SDK
/// writes its own: a package installed by other people should not make them
/// take a code-generation step, or a JSON-serialisation dependency, to read
/// six response shapes we control.

library;

/// USDZ readiness. Gates iOS entirely — see [EmbedModel.usdzUrl].
enum UsdzStatus { pending, processing, ready, failed }

UsdzStatus _usdzStatusFrom(String? value) => switch (value) {
      'processing' => UsdzStatus.processing,
      'ready' => UsdzStatus.ready,
      'failed' => UsdzStatus.failed,
      _ => UsdzStatus.pending,
    };

/// Camera framing, set per dish by the restaurant.
class ModelViewSettings {
  const ModelViewSettings({
    required this.cameraOrbit,
    required this.cameraTarget,
    required this.fieldOfView,
    required this.exposure,
    required this.shadowIntensity,
    required this.autoRotate,
    required this.arScale,
  });

  /// "theta phi radius", e.g. "0deg 75deg 105%". model-viewer's format, kept
  /// verbatim so one setting frames the dish identically on every platform.
  final String cameraOrbit;
  final String cameraTarget;
  final String fieldOfView;
  final double exposure;
  final double shadowIntensity;
  final bool autoRotate;

  /// Multiplier applied before AR placement. Distinct from
  /// [EmbedModel.physicalSizeM]: that is how big the dish is, this is a
  /// correction the restaurant applied on top. Both apply.
  final double arScale;

  factory ModelViewSettings.fromJson(Map<String, dynamic> json) =>
      ModelViewSettings(
        cameraOrbit: json['cameraOrbit'] as String? ?? '0deg 75deg 105%',
        cameraTarget: json['cameraTarget'] as String? ?? 'auto auto auto',
        fieldOfView: json['fieldOfView'] as String? ?? 'auto',
        exposure: (json['exposure'] as num?)?.toDouble() ?? 1,
        shadowIntensity: (json['shadowIntensity'] as num?)?.toDouble() ?? 1,
        autoRotate: json['autoRotate'] as bool? ?? true,
        arScale: (json['arScale'] as num?)?.toDouble() ?? 1,
      );

  /// One angle out of the orbit string, in degrees.
  ///
  /// Parsed here rather than stored twice, so the native renderers (which take
  /// numbers) cannot drift from the web one (which takes the string).
  double orbitDegrees(int index, double fallback) {
    final parts = cameraOrbit.trim().split(RegExp(r'\s+'));
    if (index >= parts.length) return fallback;
    final part = parts[index];
    final value = double.tryParse(part.replaceAll(RegExp(r'[a-z%]+$'), ''));
    if (value == null) return fallback;
    // Radians are legal in the format and are not the unit returned.
    return part.endsWith('rad') ? value * 180 / 3.141592653589793 : value;
  }
}

class EmbedModel {
  const EmbedModel({
    required this.id,
    required this.glbUrl,
    required this.usdzUrl,
    required this.usdzStatus,
    required this.posterUrl,
    required this.physicalSizeM,
    required this.glbBytes,
    required this.viewSettings,
  });

  final String id;

  /// Android inline (Filament) and Scene Viewer AR.
  final String glbUrl;

  /// iOS inline (SceneKit) and Quick Look AR. Null until conversion finishes.
  ///
  /// On iOS this gates the preview as well as AR: SceneKit cannot open a GLB,
  /// so an iPhone with no USDZ has nothing to draw and falls back to
  /// [posterUrl].
  final String? usdzUrl;
  final UsdzStatus usdzStatus;
  final String? posterUrl;

  /// Longest side in metres. Required for AR placement at a believable size.
  final double physicalSizeM;
  final int? glbBytes;
  final ModelViewSettings viewSettings;

  factory EmbedModel.fromJson(Map<String, dynamic> json) => EmbedModel(
        id: json['id'] as String,
        glbUrl: json['glbUrl'] as String,
        usdzUrl: json['usdzUrl'] as String?,
        usdzStatus: _usdzStatusFrom(json['usdzStatus'] as String?),
        posterUrl: json['posterUrl'] as String?,
        physicalSizeM: (json['physicalSizeM'] as num?)?.toDouble() ?? 0.25,
        glbBytes: (json['glbBytes'] as num?)?.toInt(),
        viewSettings: ModelViewSettings.fromJson(
          (json['viewSettings'] as Map).cast<String, dynamic>(),
        ),
      );
}

class EmbedMerchant {
  const EmbedMerchant({
    required this.id,
    required this.slug,
    required this.name,
    required this.currency,
    required this.locale,
  });

  final String id;
  final String slug;
  final String name;
  final String currency;
  final String locale;

  factory EmbedMerchant.fromJson(Map<String, dynamic> json) => EmbedMerchant(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        locale: json['locale'] as String,
      );
}

class EmbedItem {
  const EmbedItem({
    required this.id,
    required this.slug,
    required this.externalRef,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.tags,
    required this.imageUrl,
    required this.isAvailable,
    required this.merchant,
    required this.model,
  });

  final String id;
  final String slug;

  /// Your own identifier for this dish, when you set one.
  final String? externalRef;
  final String name;
  final String? description;
  final int priceCents;
  final List<String> tags;
  final String? imageUrl;
  final bool isAvailable;
  final EmbedMerchant merchant;

  /// Null when the dish has no model, or one that is not ready yet.
  final EmbedModel? model;

  factory EmbedItem.fromJson(Map<String, dynamic> json) => EmbedItem(
        id: json['id'] as String,
        slug: json['slug'] as String,
        externalRef: json['externalRef'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        priceCents: (json['priceCents'] as num).toInt(),
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        imageUrl: json['imageUrl'] as String?,
        isAvailable: json['isAvailable'] as bool? ?? true,
        merchant: EmbedMerchant.fromJson(
          (json['merchant'] as Map).cast<String, dynamic>(),
        ),
        model: json['model'] == null
            ? null
            : EmbedModel.fromJson(
                (json['model'] as Map).cast<String, dynamic>()),
      );
}

class EmbedConfig {
  const EmbedConfig({
    required this.scope,
    required this.ownerName,
    required this.merchants,
  });

  final String scope;
  final String ownerName;
  final List<EmbedMerchant> merchants;

  factory EmbedConfig.fromJson(Map<String, dynamic> json) => EmbedConfig(
        scope: json['scope'] as String,
        ownerName: json['ownerName'] as String,
        merchants: (json['merchants'] as List)
            .map((m) =>
                EmbedMerchant.fromJson((m as Map).cast<String, dynamic>()))
            .toList(),
      );
}
