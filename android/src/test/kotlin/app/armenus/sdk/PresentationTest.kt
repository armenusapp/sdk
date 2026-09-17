package app.armenus.sdk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PresentationTest {
  private fun model(usdz: String?, status: UsdzStatus, poster: String? = "https://cdn.example/poster.webp") = EmbedModel(
    id = "m1",
    glbUrl = "https://cdn.example/dish.glb",
    usdzUrl = usdz,
    usdzStatus = status,
    posterUrl = poster,
    physicalSizeM = 0.3,
    glbBytes = 1_000_000,
    viewSettings = ModelViewSettings("0deg 75deg 105%", "auto auto auto", "auto", 1.0, 1.0, true, 1.0),
  )

  @Test
  fun noModelHasNothingToShow() {
    val result = resolvePresentation(Platform.ANDROID, null)
    assertEquals(InlineSource.None, result.inline)
    assertFalse(result.ar.supported)
    assertFalse(result.ar.blockedOnConversion)
    assertNotNull(result.ar.reason)
  }

  @Test
  fun androidRendersGlbRegardlessOfArCore() {
    val ready = model(usdz = null, status = UsdzStatus.PENDING)
    val withoutAr = resolvePresentation(Platform.ANDROID, ready, arCoreAvailable = false)
    assertEquals(InlineSource.Glb("https://cdn.example/dish.glb"), withoutAr.inline)
    assertFalse(withoutAr.ar.supported)
    assertNotNull(withoutAr.ar.reason)

    val withAr = resolvePresentation(Platform.ANDROID, ready, arCoreAvailable = true)
    assertEquals(ArAvailability.supported(ArMode.SCENE_VIEWER), withAr.ar)
  }

  @Test
  fun iosWithoutUsdzFallsBackToPosterAndIsBlockedOnConversion() {
    val result = resolvePresentation(Platform.IOS, model(usdz = null, status = UsdzStatus.PROCESSING))
    assertEquals(InlineSource.Poster("https://cdn.example/poster.webp"), result.inline)
    assertTrue(result.ar.blockedOnConversion)

    val failed = resolvePresentation(Platform.IOS, model(usdz = null, status = UsdzStatus.FAILED))
    assertFalse(failed.ar.blockedOnConversion)
    assertFalse(failed.ar.supported)
  }

  @Test
  fun iosWithUsdzOffersQuickLook() {
    val result = resolvePresentation(Platform.IOS, model(usdz = "https://cdn.example/dish.usdz", status = UsdzStatus.READY))
    assertEquals(InlineSource.Usdz("https://cdn.example/dish.usdz"), result.inline)
    assertEquals(ArAvailability.supported(ArMode.QUICK_LOOK), result.ar)
  }

  @Test
  fun webPaths() {
    val ready = model(usdz = null, status = UsdzStatus.PENDING)
    assertEquals(ArMode.WEBXR, resolvePresentation(Platform.WEB_OTHER, ready, hasWebXr = true).ar.mode)
    assertFalse(resolvePresentation(Platform.WEB_OTHER, ready, isMobileWeb = false).ar.supported)
    assertFalse(resolvePresentation(Platform.WEB_OTHER, ready, isMobileWeb = true).ar.supported)
  }

  @Test
  fun cameraOrbitParsing() {
    val orbit = CameraOrbit.parse("30deg 60deg 120%")
    assertEquals(30.0, orbit.theta, 0.0)
    assertEquals(60.0, orbit.phi, 0.0)
    assertEquals(1.2, orbit.radius, 0.0001)

    val radians = CameraOrbit.parse("1.5708rad 0rad auto")
    assertEquals(90.0, radians.theta, 0.01)
    assertEquals(0.0, radians.phi, 0.0)
    assertEquals(1.05, radians.radius, 0.0)

    assertEquals(CameraOrbit(), CameraOrbit.parse(""))
  }

  @Test
  fun sceneViewerUrlEncodesEverything() {
    val url = ArmenusAr.sceneViewerUrl("https://cdn.example/a b.glb?v=1", title = "Z Burger & Co", allowScaling = false)
    assertEquals(
      "https://arvr.google.com/scene-viewer/1.0?file=https%3A%2F%2Fcdn.example%2Fa%20b.glb%3Fv%3D1&mode=ar_preferred&resizable=false&title=Z%20Burger%20%26%20Co",
      url,
    )
  }
}
