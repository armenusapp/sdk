package app.armenus.flutter

import android.content.Context
import android.view.Choreographer
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MessageCodec
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.github.sceneview.SceneView
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.cos
import kotlin.math.sin

class ArmenusModelViewFactory(
  private val messenger: BinaryMessenger,
  codec: MessageCodec<Any>,
) : PlatformViewFactory(codec) {

  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = (args as? Map<String, Any?>) ?: emptyMap()
    return ArmenusFlutterModelView(context, messenger, viewId, params)
  }
}

/**
 * Inline 3D preview, rendered by Filament through SceneView.
 *
 * GLB only — Filament has no USDZ importer, the mirror of SceneKit's missing
 * glTF one, which is why every model in this system is stored as both.
 *
 * No ARCore session is created here. This is a plain view that draws a mesh;
 * AR is a separate handoff to Scene Viewer.
 */
class ArmenusFlutterModelView(
  context: Context,
  messenger: BinaryMessenger,
  viewId: Int,
  params: Map<String, Any?>,
) : PlatformView {

  private val sceneView = SceneView(context)
  private val channel = MethodChannel(messenger, "app.armenus/model-view/$viewId")
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private var modelNode: ModelNode? = null
  private var spinCallback: Choreographer.FrameCallback? = null

  private val cameraOrbitTheta = (params["cameraOrbitTheta"] as? Number)?.toDouble() ?: 0.0
  private val cameraOrbitPhi = (params["cameraOrbitPhi"] as? Number)?.toDouble() ?: 75.0
  private val autoRotate = params["autoRotate"] as? Boolean ?: true

  init {
    val source = params["source"] as? String ?: ""
    if (source.isNotEmpty()) load(source, context)
  }

  override fun getView(): View = sceneView

  private fun load(source: String, context: Context) {
    scope.launch {
      try {
        /*
         * Fetched and parsed off the main thread. A textured dish is a few MB
         * and Filament's glTF parse is not cheap — doing it inline drops
         * frames in whatever list the card is scrolling in, which is the most
         * visible performance mistake available on this path.
         */
        val bytes = withContext(Dispatchers.IO) {
          val file = if (source.startsWith("http")) {
            ArmenusModelCache.file(context, source)
          } else {
            File(source)
          }
          file.readBytes()
        }

        val instance = sceneView.modelLoader.createModelInstance(ByteBuffer.wrap(bytes))
        val node = ModelNode(modelInstance = instance).apply {
          // Normalised to a unit cube so camera distance means the same thing
          // for an espresso cup and a sharing platter. Real-world scale is the
          // AR viewer's job, not the preview's.
          scaleToUnitCube()
          centerOrigin()
        }

        sceneView.addChildNode(node)
        modelNode = node
        applyCamera()
        if (autoRotate) startSpin()

        channel.invokeMethod("onModelLoad", null)
      } catch (error: Throwable) {
        channel.invokeMethod(
          "onModelError",
          mapOf("message" to (error.message ?: "Model failed to load")),
        )
      }
    }
  }

  private fun applyCamera() {
    // Spherical to Cartesian, matching model-viewer's convention so one
    // `cameraOrbit` string frames the dish identically on every platform.
    val theta = Math.toRadians(cameraOrbitTheta)
    val phi = Math.toRadians(cameraOrbitPhi)
    val distance = 2.73

    sceneView.cameraNode.position = io.github.sceneview.math.Position(
      x = (distance * sin(phi) * sin(theta)).toFloat(),
      y = (distance * cos(phi)).toFloat(),
      z = (distance * sin(phi) * cos(theta)).toFloat(),
    )
    sceneView.cameraNode.lookAt(io.github.sceneview.math.Position(0f, 0f, 0f))
  }

  private fun startSpin() {
    val node = modelNode ?: return
    var last = 0L

    /*
     * Driven by Choreographer rather than a timer, so rotation is tied to
     * actual frame delivery. A timer keeps firing while the view is off screen
     * or the device is throttling — burning battery, and making the spin jump
     * when it comes back.
     */
    val callback = object : Choreographer.FrameCallback {
      override fun doFrame(frameTimeNanos: Long) {
        if (last != 0L) {
          val delta = (frameTimeNanos - last) / 1_000_000_000f
          // One revolution every 18 seconds, matching web and iOS.
          node.rotation = node.rotation.copy(y = node.rotation.y + delta * (360f / 18f))
        }
        last = frameTimeNanos
        if (spinCallback === this) Choreographer.getInstance().postFrameCallback(this)
      }
    }
    spinCallback = callback
    Choreographer.getInstance().postFrameCallback(callback)
  }

  override fun dispose() {
    // Filament holds native GPU resources the GC will not reclaim, so an
    // undestroyed SceneView per scrolled-past card leaks until the app dies.
    spinCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
    spinCallback = null
    channel.setMethodCallHandler(null)
    scope.cancel()
    sceneView.destroy()
  }
}
