package app.armenus.sdk

/*
 * What a given device can actually do with a given model.
 *
 * A direct port of `resolvePresentation()` from `@armenus/sdk-core`, kept as
 * a pure function for the same reason: the rules are non-obvious in ways that
 * produce dead buttons and blank canvases when guessed at.
 *
 *   • There is no cross-platform AR API. WebXR, Scene Viewer and AR Quick Look
 *     are mutually exclusive; a device supports at most one.
 *   • There is no cross-platform model format. Scene Viewer and Filament read
 *     GLB and cannot read USDZ; Quick Look and SceneKit are the reverse.
 */

enum class Platform { IOS, ANDROID, WEB_OTHER }

enum class ArMode(val wire: String) {
  /** In-page immersive session. Chrome and Edge on Android. */
  WEBXR("webxr"),
  /** Android's system AR app, launched by intent. GLB. */
  SCENE_VIEWER("scene-viewer"),
  /** iOS and iPadOS system AR. USDZ only. */
  QUICK_LOOK("quick-look"),
  NONE("none"),
}

/** Which asset the inline (non-AR) preview should load, if any. */
sealed class InlineSource {
  /** The URL to load, when there is one. */
  abstract val url: String?

  data class Glb(override val url: String) : InlineSource()
  data class Usdz(override val url: String) : InlineSource()
  /** No renderable mesh for this platform; show the still image. */
  data class Poster(override val url: String) : InlineSource()
  /** Nothing at all to show. The caller renders its own empty state. */
  data object None : InlineSource() {
    override val url: String? get() = null
  }
}

data class ArAvailability(
  val mode: ArMode,
  /** True when the user can actually place this model in their room. */
  val supported: Boolean,
  /** Why not, written to be shown to a user. Null when supported. */
  val reason: String?,
  /**
   * True when the only thing missing is the USDZ conversion, a state that
   * resolves by itself in a minute or two. Separated from every other
   * unsupported case because it is the one where "check back shortly" is
   * honest rather than a permanent-looking failure.
   */
  val blockedOnConversion: Boolean,
) {
  companion object {
    fun unsupported(reason: String) = ArAvailability(ArMode.NONE, false, reason, false)
    fun supported(mode: ArMode) = ArAvailability(mode, true, null, false)
  }
}

data class Presentation(val inline: InlineSource, val ar: ArAvailability)

/**
 * Resolves what to render and whether AR is offerable.
 *
 * @param platform Apps pass [Platform.ANDROID]. The other cases exist so the
 *   rules stay identical to the web and iOS SDKs and can be tested side by side.
 * @param arCoreAvailable Android only: whether Scene Viewer / ARCore is
 *   available on this handset. Probe it with [ArmenusAr.isAvailable]. Defaulting
 *   it to true would put an AR button on every budget phone without ARCore,
 *   where tapping it opens the Play Store instead of the camera.
 */
fun resolvePresentation(
  platform: Platform,
  model: EmbedModel?,
  arCoreAvailable: Boolean = false,
  hasWebXr: Boolean = false,
  isMobileWeb: Boolean = false,
): Presentation {
  if (model == null) {
    return Presentation(
      InlineSource.None,
      ArAvailability.unsupported("This dish does not have a 3D model yet."),
    )
  }

  val poster: InlineSource = model.posterUrl?.let { InlineSource.Poster(it) } ?: InlineSource.None

  return when (platform) {
    Platform.IOS -> {
      val usdz = model.usdzUrl
      if (usdz == null) {
        // The wide gate: SceneKit cannot open a GLB, so with no USDZ an iPhone
        // has no mesh to draw at all.
        if (model.usdzStatus == UsdzStatus.FAILED) {
          Presentation(poster, ArAvailability.unsupported("The AR version of this dish is unavailable."))
        } else {
          Presentation(
            poster,
            ArAvailability(
              mode = ArMode.NONE,
              supported = false,
              reason = "The AR version of this dish is still being prepared.",
              blockedOnConversion = true,
            ),
          )
        }
      } else {
        Presentation(InlineSource.Usdz(usdz), ArAvailability.supported(ArMode.QUICK_LOOK))
      }
    }

    Platform.ANDROID -> Presentation(
      // Filament renders the GLB regardless of ARCore: a handset with no AR
      // support still gets a model it can spin, which is most of the value.
      InlineSource.Glb(model.glbUrl),
      if (arCoreAvailable) {
        ArAvailability.supported(ArMode.SCENE_VIEWER)
      } else {
        ArAvailability.unsupported("This device does not support AR. You can still view the dish in 3D.")
      },
    )

    Platform.WEB_OTHER -> {
      val inline = InlineSource.Glb(model.glbUrl)
      when {
        hasWebXr -> Presentation(inline, ArAvailability.supported(ArMode.WEBXR))
        !isMobileWeb -> Presentation(
          inline,
          ArAvailability.unsupported("Scan the QR code with your phone to view this dish in AR."),
        )
        else -> Presentation(
          inline,
          ArAvailability.unsupported(
            "This browser does not support AR. Open the page in Chrome or Safari to place the dish on your table.",
          ),
        )
      }
    }
  }
}

/**
 * Parsed camera framing from a model-viewer `camera-orbit` string.
 *
 * The wire format is model-viewer's (`"0deg 75deg 105%"`) because the same
 * framing drives the web SDK verbatim. Native renderers take numbers, so it is
 * parsed here rather than stored twice and allowed to disagree.
 */
data class CameraOrbit(
  /** Azimuth in degrees. */
  val theta: Double = 0.0,
  /** Polar angle in degrees; 90 is level with the dish. */
  val phi: Double = 75.0,
  /** Distance multiplier; 1.0 frames the model, 1.05 leaves a small margin. */
  val radius: Double = 1.05,
) {
  companion object {
    fun parse(orbit: String): CameraOrbit {
      val parts = orbit.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
      return CameraOrbit(
        theta = degrees(parts.getOrNull(0), 0.0),
        phi = degrees(parts.getOrNull(1), 75.0),
        radius = radius(parts.getOrNull(2), 1.05),
      )
    }

    private fun number(part: String): Double? =
      part.takeWhile { it.isDigit() || it == '.' || it == '-' || it == '+' }.toDoubleOrNull()

    private fun degrees(part: String?, fallback: Double): Double {
      val value = part?.let(::number) ?: return fallback
      // Radians are legal in the format too, and are not the unit we return.
      return if (part.endsWith("rad")) Math.toDegrees(value) else value
    }

    private fun radius(part: String?, fallback: Double): Double {
      val value = part?.let(::number) ?: return fallback
      // "105%" means 1.05 times the framing distance; "auto" keeps the default.
      return if (part.endsWith("%")) value / 100 else value
    }
  }
}
