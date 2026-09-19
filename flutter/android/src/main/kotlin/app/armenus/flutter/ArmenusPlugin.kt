package app.armenus.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import java.util.concurrent.Executors

/**
 * Flutter entry point: the AR channel and the platform-view factory.
 *
 * Mirrors the React Native SDK deliberately — same cache, same Scene Viewer
 * intent, same Filament preview — so a partner shipping both apps gets one
 * behaviour rather than two that drift.
 */
class ArmenusPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private val io = Executors.newFixedThreadPool(2)

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "app.armenus/ar")
    channel.setMethodCallHandler(this)

    binding.platformViewRegistry.registerViewFactory(
      "app.armenus/model-view",
      ArmenusModelViewFactory(binding.binaryMessenger, StandardMessageCodec.INSTANCE),
    )
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isArAvailable" -> isArAvailable(result)
      "prefetch" -> prefetch(call.argument<String>("url"), result)
      "presentAr" -> presentAr(call, result)
      "cacheSize" -> io.execute {
        result.success(ArmenusModelCache.totalBytes(context).toInt())
      }
      "clearCache" -> io.execute {
        ArmenusModelCache.clear(context)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  /** Checks whether the system Scene Viewer can handle the AR handoff. */
  private fun isArAvailable(result: MethodChannel.Result) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://arvr.google.com/scene-viewer/1.0")).apply {
      setPackage("com.google.ar.core")
    }
    val available = runCatching {
      intent.resolveActivity(context.packageManager) != null
    }.getOrDefault(false)
    result.success(available)
  }

  private fun prefetch(url: String?, result: MethodChannel.Result) {
    if (url.isNullOrEmpty()) {
      result.error("bad_args", "url is required", null)
      return
    }
    io.execute {
      try {
        result.success(ArmenusModelCache.file(context, url).absolutePath)
      } catch (error: Throwable) {
        result.error("prefetch_failed", error.message, null)
      }
    }
  }

  private fun presentAr(call: MethodCall, result: MethodChannel.Result) {
    val url = call.argument<String>("url")
    if (url.isNullOrEmpty()) {
      result.error("bad_args", "url is required", null)
      return
    }
    val title = call.argument<String>("title") ?: ""
    val allowScaling = call.argument<Boolean>("allowScaling") ?: false

    val current = activity
    if (current == null) {
      result.error("no_activity", "No activity to launch AR from", null)
      return
    }

    /*
     * Scene Viewer gets the REMOTE url, not the cached file: it runs in its
     * own process with no access to our app-private cache directory, so a
     * file:// path opens a blank viewer. It keeps its own cache and is usually
     * already warm from the inline preview having fetched the same URL.
     */
    val intent = Intent(Intent.ACTION_VIEW).apply {
      data = Uri.parse(
        "https://arvr.google.com/scene-viewer/1.0" +
          "?file=${Uri.encode(url)}" +
          "&mode=ar_preferred" +
          "&resizable=$allowScaling" +
          if (title.isNotEmpty()) "&title=${Uri.encode(title)}" else "",
      )
      // Explicit package: stops a chooser appearing, and stops a browser
      // claiming the https URL and rendering an error page.
      setPackage("com.google.ar.core")
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    try {
      current.startActivity(intent)
      /*
       * Resolved on launch, not dismissal. Scene Viewer is a separate activity
       * in a separate process and reports nothing back, so there is no
       * completion to await — holding the result open would leave the caller's
       * spinner running until the app died.
       */
      result.success(null)
    } catch (error: Throwable) {
      result.error("ar_unavailable", "Scene Viewer could not be launched", null)
    }
  }
}
