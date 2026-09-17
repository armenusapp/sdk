import XCTest
@testable import ArmenusCore

final class PresentationTests: XCTestCase {
  private func model(usdz: String?, status: UsdzStatus, poster: String? = "https://cdn.example/poster.webp") -> EmbedModel {
    EmbedModel(
      id: "m1",
      glbUrl: "https://cdn.example/dish.glb",
      usdzUrl: usdz,
      usdzStatus: status,
      posterUrl: poster,
      physicalSizeM: 0.3,
      glbBytes: 1_000_000,
      viewSettings: ModelViewSettings(
        cameraOrbit: "0deg 75deg 105%",
        cameraTarget: "auto auto auto",
        fieldOfView: "auto",
        exposure: 1,
        shadowIntensity: 1,
        autoRotate: true,
        arScale: 1))
  }

  func testNoModelHasNothingToShow() {
    let result = resolvePresentation(platform: .iOS, model: nil)
    XCTAssertEqual(result.inline, .none)
    XCTAssertFalse(result.ar.supported)
    XCTAssertFalse(result.ar.blockedOnConversion)
    XCTAssertNotNil(result.ar.reason)
  }

  func testIOSWithoutUsdzFallsBackToPosterAndIsBlockedOnConversion() {
    let result = resolvePresentation(platform: .iOS, model: model(usdz: nil, status: .processing))
    XCTAssertEqual(result.inline, .poster(url: "https://cdn.example/poster.webp"))
    XCTAssertFalse(result.ar.supported)
    XCTAssertTrue(result.ar.blockedOnConversion)
  }

  func testIOSWithFailedConversionIsNotBlocked() {
    let result = resolvePresentation(platform: .iOS, model: model(usdz: nil, status: .failed))
    XCTAssertEqual(result.inline, .poster(url: "https://cdn.example/poster.webp"))
    XCTAssertFalse(result.ar.supported)
    XCTAssertFalse(result.ar.blockedOnConversion)
  }

  func testIOSWithoutUsdzOrPosterHasNothing() {
    let result = resolvePresentation(platform: .iOS, model: model(usdz: nil, status: .pending, poster: nil))
    XCTAssertEqual(result.inline, .none)
  }

  func testIOSWithUsdzRendersUsdzAndOffersQuickLook() {
    let result = resolvePresentation(
      platform: .iOS, model: model(usdz: "https://cdn.example/dish.usdz", status: .ready))
    XCTAssertEqual(result.inline, .usdz(url: "https://cdn.example/dish.usdz"))
    XCTAssertEqual(result.ar, .supported(.quickLook))
  }

  func testAndroidRendersGlbRegardlessOfArCore() {
    let ready = model(usdz: nil, status: .pending)
    let withoutAr = resolvePresentation(platform: .android, model: ready, arCoreAvailable: false)
    XCTAssertEqual(withoutAr.inline, .glb(url: "https://cdn.example/dish.glb"))
    XCTAssertFalse(withoutAr.ar.supported)

    let withAr = resolvePresentation(platform: .android, model: ready, arCoreAvailable: true)
    XCTAssertEqual(withAr.ar, .supported(.sceneViewer))
  }

  func testWebPaths() {
    let ready = model(usdz: nil, status: .pending)
    XCTAssertEqual(
      resolvePresentation(platform: .webOther, model: ready, hasWebXR: true).ar.mode, .webXR)
    XCTAssertFalse(
      resolvePresentation(platform: .webOther, model: ready, isMobileWeb: false).ar.supported)
    XCTAssertFalse(
      resolvePresentation(platform: .webOther, model: ready, isMobileWeb: true).ar.supported)
  }

  func testCameraOrbitParsing() {
    let orbit = CameraOrbit(parsing: "30deg 60deg 120%")
    XCTAssertEqual(orbit.theta, 30)
    XCTAssertEqual(orbit.phi, 60)
    XCTAssertEqual(orbit.radius, 1.2, accuracy: 0.0001)

    let radians = CameraOrbit(parsing: "1.5708rad 0rad auto")
    XCTAssertEqual(radians.theta, 90, accuracy: 0.01)
    XCTAssertEqual(radians.phi, 0)
    XCTAssertEqual(radians.radius, 1.05)

    let fallback = CameraOrbit(parsing: "")
    XCTAssertEqual(fallback, CameraOrbit())
  }
}
