package app.armenus.sdk

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Choreographer
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import io.github.sceneview.SceneView
import io.github.sceneview.math.Position
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import java.nio.ByteBuffer
import kotlin.math.cos
import kotlin.math.sin

/**
 * A dish in 3D, with AR where the handset supports it.
 *
 * Filament, through SceneView, for the inline preview. GLB only: Filament has
 * no USDZ importer, the mirror of SceneKit's missing glTF one, and the reason
 * every model in this system is stored in both formats. No ARCore session is
 * created; AR is a handoff to Scene Viewer.
 *
 * The view is a square stage plus a one-line note beneath it, so give it a
 * width and let it size its height. In Jetpack Compose, wrap it in
 * `AndroidView` and call [display] from the `update` block.
 */
class ArmenusModelView @JvmOverloads constructor(
  context: Context,
  attrs: AttributeSet? = null,
) : LinearLayout(context, attrs) {

  /* -- configuration --------------------------------------------------------- */

  var arLabel: String = "View on your table"
    set(value) {
      field = value
      arButton.text = value
    }

  /**
   * Whether a drag rotates the model. Pass false inside a RecyclerView: on a
   * phone the two gesture systems fight, and a card that swallows vertical
   * drags makes the whole feed feel stuck.
   */
  var interactionEnabled: Boolean = true

  /** Background of the AR button. */
  var accentColor: Int = Color.parseColor("#234D3C")
    set(value) {
      field = value
      applyButtonStyle()
    }

  var onModelLoad: (() -> Unit)? = null
  var onModelError: ((String) -> Unit)? = null
  var onEnterAr: ((EmbedItem) -> Unit)? = null

  var item: EmbedItem? = null
    private set

  var presentation: Presentation = resolvePresentation(Platform.ANDROID, null)
    private set

  /* -- views ----------------------------------------------------------------- */

  private val stage = Stage(context)
  private val posterView = ImageView(context)
  private val progress = ProgressBar(context)
  private val arButton = Button(context)
  private val note = TextView(context)
  private var sceneView: SceneView? = null

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  private var modelNode: ModelNode? = null
  private var currentSource: String? = null
  private var posterJob: Job? = null
  private var loadJob: Job? = null

  init {
    orientation = VERTICAL

    stage.background = GradientDrawable().apply {
      setColor(Color.parseColor("#F4F2F3"))
      cornerRadius = dp(14f)
    }
    stage.clipToOutline = true

    posterView.scaleType = ImageView.ScaleType.FIT_CENTER
    stage.addView(posterView, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

    progress.isIndeterminate = true
    progress.visibility = View.GONE
    stage.addView(progress, FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.CENTER))

    arButton.text = arLabel
    arButton.isAllCaps = false
    arButton.setTextColor(Color.WHITE)
    arButton.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
    arButton.minHeight = dp(44f).toInt()
    arButton.minimumHeight = dp(44f).toInt()
    arButton.setPadding(dp(20f).toInt(), 0, dp(20f).toInt(), 0)
    arButton.visibility = View.GONE
    arButton.contentDescription = arLabel
    arButton.setOnClickListener { enterAr() }
    applyButtonStyle()
    stage.addView(
      arButton,
      FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
        bottomMargin = dp(16f).toInt()
      },
    )

    addView(stage, LayoutParams(MATCH_PARENT, WRAP_CONTENT))

    note.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
    note.setTextColor(Color.parseColor("#6B5555"))
    note.gravity = Gravity.CENTER_HORIZONTAL
    note.visibility = View.GONE
    addView(note, LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(10f).toInt() })
  }

  /* -- display --------------------------------------------------------------- */

  /** Shows a dish. Pass null to clear the view. */
  fun display(item: EmbedItem?) {
    this.item = item
    presentation = resolvePresentation(
      platform = Platform.ANDROID,
      model = item?.model,
      arCoreAvailable = ArmenusAr.isAvailable(context),
    )

    // The poster stays mounted beneath the canvas until the mesh reports in,
    // so there is never a blank frame between the two.
    val inline = presentation.inline
    val posterUrl = (inline as? InlineSource.Poster)?.url ?: item?.model?.posterUrl ?: item?.imageUrl
    loadPoster(posterUrl)

    if (inline is InlineSource.Glb && item?.model != null) {
      loadMesh(inline.url, item.model.viewSettings)
    } else {
      clearMesh()
    }

    arButton.visibility = if (presentation.ar.supported) View.VISIBLE else View.GONE
    note.text = presentation.ar.reason
    note.visibility = if (presentation.ar.reason == null) View.GONE else View.VISIBLE
  }

  private fun loadPoster(url: String?) {
    posterJob?.cancel()
    posterView.setImageDrawable(null)
    if (url.isNullOrEmpty()) return
    posterJob = scope.launch {
      val bitmap = runCatching {
        withContext(Dispatchers.IO) {
          URL(url).openStream().use { BitmapFactory.decodeStream(it) }
        }
      }.getOrNull()
      if (bitmap != null) posterView.setImageBitmap(bitmap)
    }
  }

  /* -- mesh ------------------------------------------------------------------ */

  private fun loadMesh(source: String, settings: ModelViewSettings) {
    if (source == currentSource) return
    currentSource = source
    clearScene()
    progress.visibility = View.VISIBLE

    loadJob?.cancel()
    loadJob = scope.launch {
      try {
        // Fetched and read off the main thread. A textured dish is a few MB,
        // and doing it inline drops frames in whatever list the card is
        // scrolling in, the most visible performance mistake on this path.
        val bytes = withContext(Dispatchers.IO) {
          ArmenusModelCache.fileBlocking(context, source).readBytes()
        }
        if (currentSource != source) return@launch

        val view = sceneView ?: SceneView(context).also {
          sceneView = it
          stage.addView(it, 1, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        }

        val instance = view.modelLoader.createModelInstance(ByteBuffer.wrap(bytes))
        val node = ModelNode(
          modelInstance = instance,
          autoAnimate = false,
          // Normalised to a unit bounding box so `cameraOrbit` means the same
          // thing for a coffee cup and a sharing platter. Real-world scale is
          // applied by the AR viewer, not by the preview.
          scaleToUnits = 1.0f,
          centerOrigin = Position(0f, 0f, 0f),
        )
        view.addChildNode(node)
        modelNode = node

        applyCamera(view, CameraOrbit.parse(settings.cameraOrbit))
        if (settings.autoRotate) startSpin() else stopSpin()

        progress.visibility = View.GONE
        onModelLoad?.invoke()
      } catch (error: Throwable) {
        if (error is kotlinx.coroutines.CancellationException) throw error
        progress.visibility = View.GONE
        onModelError?.invoke(error.message ?: "Model failed to load")
      }
    }
  }

  private fun clearMesh() {
    currentSource = null
    loadJob?.cancel()
    clearScene()
    progress.visibility = View.GONE
  }

  private fun clearScene() {
    stopSpin()
    val view = sceneView
    modelNode?.let { node ->
      view?.removeChildNode(node)
      node.destroy()
    }
    modelNode = null
  }

  private fun applyCamera(view: SceneView, orbit: CameraOrbit) {
    // Spherical to Cartesian, matching model-viewer's convention so that one
    // `cameraOrbit` string frames a dish identically on web, iOS and Android.
    val theta = Math.toRadians(orbit.theta)
    val phi = Math.toRadians(orbit.phi)
    val distance = orbit.radius * 2.6

    view.cameraNode.position = Position(
      x = (distance * sin(phi) * sin(theta)).toFloat(),
      y = (distance * cos(phi)).toFloat(),
      z = (distance * sin(phi) * cos(theta)).toFloat(),
    )
    view.cameraNode.lookAt(targetWorldPosition = Position(0f, 0f, 0f), smooth = false)
  }

  /* -- spin ------------------------------------------------------------------ */

  private var spinCallback: Choreographer.FrameCallback? = null

  private fun startSpin() {
    stopSpin()
    val node = modelNode ?: return
    var last = 0L

    // Driven by Choreographer rather than a fixed timer, so the rotation is
    // tied to actual frame delivery. A timer keeps firing while the view is
    // off screen or the device is throttling, which burns battery and makes
    // the spin jump when it comes back.
    val callback = object : Choreographer.FrameCallback {
      override fun doFrame(frameTimeNanos: Long) {
        if (last != 0L) {
          val delta = (frameTimeNanos - last) / 1_000_000_000f
          // One revolution every 18 seconds, matching the web and iOS viewers.
          node.rotation = node.rotation.copy(y = node.rotation.y + delta * (360f / 18f))
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

  /* -- AR -------------------------------------------------------------------- */

  private fun enterAr() {
    val current = item ?: return
    val glb = current.model?.glbUrl ?: return
    onEnterAr?.invoke(current)
    // Life-size and fixed: the model is already scaled to the dish's real
    // dimensions, which is the whole question being asked.
    if (!ArmenusAr.launch(context, glb, title = current.name, allowScaling = false)) {
      onModelError?.invoke("Scene Viewer could not be launched")
    }
  }

  /* -- lifecycle ------------------------------------------------------------- */

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    // Filament holds native GPU resources that the GC will not reclaim, so an
    // undestroyed SceneView per scrolled-past card leaks until the app dies.
    // Call `display(item)` again after re-attaching, as a RecyclerView binder does.
    stopSpin()
    scope.coroutineContext.cancelChildren()
    clearScene()
    sceneView?.let { view ->
      stage.removeView(view)
      view.destroy()
    }
    sceneView = null
    currentSource = null
  }

  /* -- helpers --------------------------------------------------------------- */

  private fun applyButtonStyle() {
    arButton.background = GradientDrawable().apply {
      setColor(accentColor)
      cornerRadius = dp(999f)
    }
    arButton.stateListAnimator = null
  }

  private fun dp(value: Float): Float =
    TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics)

  /**
   * The square canvas. When interaction is off it lets touches fall through
   * to the enclosing list instead of the renderer's own gesture handling,
   * while still delivering taps to the AR button.
   */
  private inner class Stage(context: Context) : FrameLayout(context) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
      val width = MeasureSpec.getSize(widthMeasureSpec)
      val square = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY)
      super.onMeasure(square, square)
    }

    override fun onInterceptTouchEvent(event: MotionEvent): Boolean {
      if (interactionEnabled) return false
      val onButton = arButton.visibility == View.VISIBLE &&
        event.x >= arButton.left && event.x <= arButton.right &&
        event.y >= arButton.top && event.y <= arButton.bottom
      return !onButton
    }

    override fun onTouchEvent(event: MotionEvent): Boolean = false
  }

  private companion object {
    const val MATCH_PARENT = LayoutParams.MATCH_PARENT
    const val WRAP_CONTENT = LayoutParams.WRAP_CONTENT
  }
}
