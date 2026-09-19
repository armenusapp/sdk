// swift-tools-version: 5.9
import PackageDescription

/*
 Two targets on purpose.

 `ArmenusCore` is Foundation only: the API client, the wire types and the
 presentation rules. It compiles and tests on macOS, so the logic every app
 depends on is verified without a device or a simulator.

 `Armenus` adds the iOS surface — the SceneKit viewer, the disk cache, the
 Quick Look AR handoff and a SwiftUI wrapper — and re-exports the core, so an
 app writes `import Armenus` once.
 */
let package = Package(
  name: "Armenus",
  platforms: [.iOS(.v15), .macOS(.v12)],
  products: [
    .library(name: "Armenus", targets: ["Armenus"]),
    .library(name: "ArmenusCore", targets: ["ArmenusCore"]),
  ],
  targets: [
    .target(name: "ArmenusCore", path: "swift/Sources/ArmenusCore"),
    .target(name: "Armenus", dependencies: ["ArmenusCore"], path: "swift/Sources/Armenus"),
    .testTarget(
      name: "ArmenusTests",
      dependencies: ["Armenus"],
      path: "swift/Tests/ArmenusTests",
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "ArmenusCoreTests",
      dependencies: ["ArmenusCore"],
      path: "swift/Tests/ArmenusCoreTests"
    ),
  ]
)
