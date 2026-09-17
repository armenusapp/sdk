require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "armenus-sdk-react-native"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.license      = package["license"]
  s.authors      = { "Armenus" => "support@armenus.app" }
  s.homepage     = "https://armenus.app"
  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/armenusapp/sdk.git", :tag => "v#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # SceneKit and QuickLook are system frameworks; nothing is vendored. ARKit is
  # linked only for `ARWorldTrackingConfiguration.isSupported` and
  # `ARQuickLookPreviewItem` — no ARSession is ever created, so an app adding
  # this SDK does not gain a camera permission requirement.
  s.frameworks   = "ARKit", "QuickLook", "SceneKit", "UIKit"

  install_modules_dependencies(s)
end
