package app.armenus.sdk

import android.content.Context
import android.view.MotionEvent
import android.view.Choreographer
import android.widget.FrameLayout
import io.github.sceneview.SceneView
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.cos
import kotlin.math.sin

/**
 * Inline 3D preview on Android.
 *
 * Filament, through SceneView. GLB only — Filament has no USDZ importer, which
 * is the mirror of SceneKit's missing glTF one and the reason every model in
 * this system is stored in both formats.
 *
 * No ARCore session is created. This is a plain view that draws a mesh; AR is
 * a separate handoff to Scene Viewer.
 */
class ArmenusModelView(context: Context) : FrameLayout(context) {

  private val sceneView = SceneView(context)
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private var modelNode: ModelNode? = null
  private var currentSource: String? = null
  private var loadJob: Job? = null
  private var disposed = false

  var onModelLoad: (() -> Unit)? = null
  var onModelError: ((String) -> Unit)? = null

  /* -- props -------------------------------------------------------------- */

  var cameraOrbitTheta: Double = 0.0
    set(value) { field = value; applyCamera() }

  var cameraOrbitPhi: Double = 75.0
    set(value) { field = value; applyCamera() }

  var cameraDistance: Double = 1.05
    set(value) { field = value; applyCamera() }

  var autoRotate: Boolean = true
    set(value) {
      field = value
      if (value) startSpin() else stopSpin()
    }

  var interactionEnabled: Boolean = true

  init {
    addView(sceneView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
  }

  fun setSource(source: String) {
    if (source.isEmpty() || source == currentSource) return
    currentSource = source

    loadJob?.cancel()
    stopSpin()
    modelNode?.let { sceneView.removeChildNode(it); it.destroy() }
    modelNode = null
    loadJob = scope.launch {
      try {
        /*
         * Fetch and parse off the main thread. A textured dish is a few MB and
         * Filament's glTF parse is not cheap — doing it inline drops frames in
         * whatever list the card is scrolling in, which is the most visible
         * performance mistake available on this path.
         */
        val buffer = withContext(Dispatchers.IO) {
          val file = if (source.startsWith("http")) {
            ArmenusModelCache.file(context, source)
          } else {
            java.io.File(source)
          }
          ArmenusGlb.prepare(file.readBytes())
        }

        if (disposed || currentSource != source) return@launch
        val instance = sceneView.modelLoader.createModelInstance(
          java.nio.ByteBuffer.wrap(buffer),
        )
        val node = ModelNode(
          modelInstance = instance,
          autoAnimate = false,
          scaleToUnits = 1.0f,
          centerOrigin = io.github.sceneview.math.Position(0f, 0f, 0f),
        )

        sceneView.addChildNode(node)
        modelNode = node
        applyCamera()
        if (autoRotate) startSpin()
        onModelLoad?.invoke()
      } catch (error: CancellationException) {
        throw error
      } catch (error: Throwable) {
        onModelError?.invoke(error.message ?: "Model failed to load")
      }
    }
  }

  /* -- framing ------------------------------------------------------------ */

  private fun applyCamera() {
    // Spherical to Cartesian, matching model-viewer's convention so that one
    // `cameraOrbit` string frames a dish identically on web, iOS and Android.
    val theta = Math.toRadians(cameraOrbitTheta)
    val phi = Math.toRadians(cameraOrbitPhi)
    val distance = cameraDistance * 2.6

    sceneView.cameraNode.position = io.github.sceneview.math.Position(
      x = (distance * sin(phi) * sin(theta)).toFloat(),
      y = (distance * cos(phi)).toFloat(),
      z = (distance * sin(phi) * cos(theta)).toFloat(),
    )
    sceneView.cameraNode.lookAt(io.github.sceneview.math.Position(0f, 0f, 0f))
  }

  /* -- spin --------------------------------------------------------------- */

  private var spinCallback: Choreographer.FrameCallback? = null

  private fun startSpin() {
    stopSpin()
    val node = modelNode ?: return
    var last = 0L

    /*
     * Driven by Choreographer rather than a fixed timer, so the rotation is
     * tied to actual frame delivery. A timer keeps firing while the view is
     * off screen or the device is throttling, which burns battery and makes
     * the spin jump when it comes back.
     */
    val callback = object : Choreographer.FrameCallback {
      override fun doFrame(frameTimeNanos: Long) {
        if (last != 0L) {
          val delta = (frameTimeNanos - last) / 1_000_000_000f
          // One revolution every 18 seconds, matching the web and iOS viewers.
          node.rotation = node.rotation.copy(
            y = node.rotation.y + delta * (360f / 18f),
          )
        }
        last = frameTimeNanos
        if (spinCallback === this) Choreographer.getInstance().postFrameCallback(this)
      }
    }
    spinCallback = callback
    Choreographer.getInstance().postFrameCallback(callback)
  }

  private fun stopSpin() {
    spinCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
    spinCallback = null
  }

  override fun onInterceptTouchEvent(event: MotionEvent): Boolean = !interactionEnabled

  override fun onTouchEvent(event: MotionEvent): Boolean = false

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    if (!disposed && autoRotate) startSpin()
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    // React Native can temporarily detach a view while recycling a list.
    stopSpin()
  }

  fun dispose() {
    if (disposed) return
    disposed = true
    stopSpin()
    scope.cancel()
    modelNode?.let { sceneView.removeChildNode(it); it.destroy() }
    modelNode = null
    sceneView.destroy()
  }
}
