package app.armenus.sdk

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp

/**
 * Bridges [ArmenusModelView] to React Native.
 *
 * Prop names match `ArmenusModelViewNativeComponent.ts` exactly; codegen pairs
 * them by string, so a rename on one side silently stops the prop arriving
 * rather than failing to build.
 */
class ArmenusModelViewManager : SimpleViewManager<ArmenusModelView>() {

  override fun getName() = NAME

  override fun createViewInstance(context: ThemedReactContext) =
    ArmenusModelView(context).apply {
      onModelLoad = { emit(context, id, "onModelLoad", null) }
      onModelError = { message ->
        emit(
          context,
          id,
          "onModelError",
          com.facebook.react.bridge.Arguments.createMap().apply {
            putString("message", message)
          },
        )
      }
    }

  @ReactProp(name = "source")
  fun setSource(view: ArmenusModelView, value: String?) {
    view.setSource(value ?: "")
  }

  @ReactProp(name = "posterUrl")
  fun setPosterUrl(view: ArmenusModelView, value: String?) {
    // The poster is drawn by the JS layer, which already has an <Image> above
    // the canvas. Accepted and ignored so the prop contract stays identical
    // across platforms rather than being conditionally present.
  }

  @ReactProp(name = "cameraOrbitTheta", defaultDouble = 0.0)
  fun setCameraOrbitTheta(view: ArmenusModelView, value: Double) {
    view.cameraOrbitTheta = value
  }

  @ReactProp(name = "cameraOrbitPhi", defaultDouble = 75.0)
  fun setCameraOrbitPhi(view: ArmenusModelView, value: Double) {
    view.cameraOrbitPhi = value
  }

  @ReactProp(name = "cameraDistance", defaultDouble = 1.05)
  fun setCameraDistance(view: ArmenusModelView, value: Double) {
    view.cameraDistance = value
  }

  @ReactProp(name = "exposure", defaultDouble = 1.0)
  fun setExposure(view: ArmenusModelView, value: Double) {
    // SceneView applies image-based lighting from its environment, so exposure
    // is handled by the IBL rather than as a per-view multiplier.
  }

  @ReactProp(name = "shadowIntensity", defaultDouble = 1.0)
  fun setShadowIntensity(view: ArmenusModelView, value: Double) {
    // Reserved: SceneView's default lighting already casts a contact shadow.
  }

  @ReactProp(name = "autoRotate", defaultBoolean = true)
  fun setAutoRotate(view: ArmenusModelView, value: Boolean) {
    view.autoRotate = value
  }

  @ReactProp(name = "interactionEnabled", defaultBoolean = true)
  fun setInteractionEnabled(view: ArmenusModelView, value: Boolean) {
    view.interactionEnabled = value
  }

  override fun onDropViewInstance(view: ArmenusModelView) {
    view.dispose()
    super.onDropViewInstance(view)
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    MapBuilder.builder<String, Any>()
      .put("onModelLoad", MapBuilder.of("registrationName", "onModelLoad"))
      .put("onModelError", MapBuilder.of("registrationName", "onModelError"))
      .build()

  private fun emit(
    context: ThemedReactContext,
    viewId: Int,
    event: String,
    payload: com.facebook.react.bridge.WritableMap?,
  ) {
    context.reactApplicationContext
      .getJSModule(com.facebook.react.uimanager.events.RCTEventEmitter::class.java)
      ?.receiveEvent(viewId, event, payload)
  }

  companion object {
    const val NAME = "ArmenusModelView"
  }
}
