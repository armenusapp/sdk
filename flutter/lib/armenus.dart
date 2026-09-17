/// Render restaurant dishes in 3D and place them on a real table in AR.
///
/// Native on both platforms: SceneKit and AR Quick Look on iOS, Filament and
/// Scene Viewer on Android. No WebView.
library armenus;

export 'src/armenus_ar.dart' show ArmenusAr;
export 'src/armenus_model.dart' show ArmenusModel;
export 'src/capability.dart'
    show ArMode, InlineKind, Presentation, resolvePresentation;
export 'src/client.dart' show ArmenusClient, ArmenusException;
export 'src/models.dart'
    show EmbedConfig, EmbedItem, EmbedMerchant, EmbedModel, ModelViewSettings, UsdzStatus;
