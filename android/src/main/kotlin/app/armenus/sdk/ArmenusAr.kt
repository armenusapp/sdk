package app.armenus.sdk

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.File
import java.net.URLEncoder

/**
 * AR placement, via Scene Viewer.
 *
 * No ARCore rendering code, on purpose. Scene Viewer is Google's own AR
 * viewer, already installed on every Play-services device, and it does plane
 * detection, real-world scale, shadows and the placement gestures users know
 * from Search. Building an ARCore/Filament placement flow instead would be a
 * large amount of code to land somewhere worse and inconsistent with the rest
 * of the platform.
 *
 * A consequence worth stating: this library never links the ARCore SDK and
 * never requests the camera permission. Scene Viewer holds it.
 */
object ArmenusAr {
  private const val SCENE_VIEWER_PACKAGE = "com.google.ar.core"
  private const val SCENE_VIEWER_URL = "https://arvr.google.com/scene-viewer/1.0"

  /**
   * Whether Scene Viewer can be launched on this handset.
   *
   * Resolved through the `<queries>` entry in the library manifest, so it
   * answers "is the AR viewer installed" without linking ARCore. On a device
   * without ARCore support Scene Viewer itself falls back to a 3D-only view,
   * so a true here never sends anyone to the Play Store.
   */
  fun isAvailable(context: Context): Boolean {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(SCENE_VIEWER_URL)).apply {
      setPackage(SCENE_VIEWER_PACKAGE)
    }
    return runCatching { intent.resolveActivity(context.packageManager) != null }.getOrDefault(false)
  }

  /** Warms the inline-preview cache for a dish about to scroll into view. */
  suspend fun prefetch(context: Context, glbUrl: String): File =
    ArmenusModelCache.file(context, glbUrl)

  /**
   * Opens the dish in Scene Viewer. Returns true when the viewer was launched.
   *
   * Scene Viewer is handed the remote URL, not the cached file: it runs in its
   * own process with no access to this app's cache directory, and it keeps a
   * cache of its own.
   *
   * @param allowScaling Whether the user may pinch-scale the model. Defaults
   *   to false, and that default is the point: the model is already scaled to
   *   the dish's real dimensions, which is the question a diner is asking.
   */
  fun launch(
    context: Context,
    glbUrl: String,
    title: String? = null,
    allowScaling: Boolean = false,
  ): Boolean {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(sceneViewerUrl(glbUrl, title, allowScaling))).apply {
      // Targeting the package explicitly stops the chooser appearing and stops
      // a browser claiming the https URL and rendering an error page.
      setPackage(SCENE_VIEWER_PACKAGE)
      if (context !is Activity) addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return try {
      context.startActivity(intent)
      true
    } catch (_: ActivityNotFoundException) {
      false
    }
  }

  /**
   * The Scene Viewer URL for a model. Pure, so the encoding can be unit
   * tested off-device; [launch] is the only caller that turns it into an
   * intent.
   */
  fun sceneViewerUrl(glbUrl: String, title: String? = null, allowScaling: Boolean = false): String {
    val params = buildString {
      append("file=").append(encode(glbUrl))
      append("&mode=ar_preferred")
      append("&resizable=").append(allowScaling)
      if (!title.isNullOrEmpty()) append("&title=").append(encode(title))
    }
    return "$SCENE_VIEWER_URL?$params"
  }

  private fun encode(value: String): String = URLEncoder.encode(value, "UTF-8").replace("+", "%20")
}
