package app.armenus.sdk

import android.content.Intent
import android.net.Uri
import com.google.ar.core.ArCoreApk
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import java.util.concurrent.Executors

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
 * A consequence worth stating: this module never links the ARCore SDK for
 * rendering and never requests the camera permission. Scene Viewer holds it.
 */
class ArmenusArModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName() = NAME

  private val io = Executors.newFixedThreadPool(2)

  /**
   * Whether this handset can do AR.
   *
   * `ArCoreApk.checkAvailability` covers both questions that matter — is the
   * device on Google's supported list, and is ARCore actually installed. A
   * version check answers neither, and an AR button on an unsupported handset
   * opens the Play Store instead of the camera, which reads as a broken app.
   *
   * The transient states resolve asynchronously, so this polls briefly rather
   * than reporting "no" for a device that is merely still deciding.
   */
  @ReactMethod
  fun isArAvailable(promise: Promise) {
    try {
      val availability = ArCoreApk.getInstance().checkAvailability(reactContext)
      if (availability.isTransient) {
        io.execute {
          var state = availability
          var waited = 0
          while (state.isTransient && waited < 2_000) {
            Thread.sleep(200)
            waited += 200
            state = ArCoreApk.getInstance().checkAvailability(reactContext)
          }
          promise.resolve(state.isSupported)
        }
      } else {
        promise.resolve(availability.isSupported)
      }
    } catch (error: Throwable) {
      // A device without Play services throws rather than reporting false.
      promise.resolve(false)
    }
  }

  @ReactMethod
  fun prefetch(url: String, promise: Promise) {
    io.execute {
      try {
        promise.resolve(ArmenusModelCache.file(reactContext, url).absolutePath)
      } catch (error: Throwable) {
        promise.reject("prefetch_failed", error.message, error)
      }
    }
  }

  @ReactMethod
  fun presentAr(options: ReadableMap, promise: Promise) {
    val url = options.getString("url")
    if (url.isNullOrEmpty()) {
      promise.reject("bad_args", "url is required")
      return
    }
    val title = options.getString("title") ?: ""
    val allowScaling = if (options.hasKey("allowScaling")) {
      options.getBoolean("allowScaling")
    } else {
      false
    }

    val activity = currentActivity
    if (activity == null) {
      promise.reject("no_activity", "No activity to launch AR from")
      return
    }

    /*
     * Scene Viewer is handed the REMOTE url, not the cached file.
     *
     * It runs in its own process and has no access to our app-private cache
     * directory, so a `file://` path here fails with a blank viewer. Passing a
     * `content://` URI through a FileProvider would work but requires granting
     * a cross-process read permission per launch for no benefit — Scene Viewer
     * maintains its own cache and is generally already warm from the inline
     * preview having fetched the same URL.
     */
    val intent = Intent(Intent.ACTION_VIEW).apply {
      data = Uri.parse(
        "https://arvr.google.com/scene-viewer/1.0" +
          "?file=${Uri.encode(url)}" +
          "&mode=ar_preferred" +
          "&resizable=$allowScaling" +
          if (title.isNotEmpty()) "&title=${Uri.encode(title)}" else "",
      )
      // Targeting the package explicitly stops the chooser appearing and stops
      // a browser claiming the https URL and rendering an error page.
      setPackage("com.google.ar.core")
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    try {
      activity.startActivity(intent)
      /*
       * Resolved on launch rather than on dismissal. Scene Viewer is a separate
       * activity in a separate process and reports nothing back when the user
       * leaves it — there is no completion to await, and holding the promise
       * open would leave the caller's spinner running until the app died.
       */
      promise.resolve(null)
    } catch (error: Throwable) {
      promise.reject("ar_unavailable", "Scene Viewer could not be launched", error)
    }
  }

  @ReactMethod
  fun cacheSize(promise: Promise) {
    io.execute { promise.resolve(ArmenusModelCache.totalBytes(reactContext).toDouble()) }
  }

  @ReactMethod
  fun clearCache(promise: Promise) {
    io.execute {
      ArmenusModelCache.clear(reactContext)
      promise.resolve(null)
    }
  }

  companion object {
    const val NAME = "ArmenusAr"
  }
}
