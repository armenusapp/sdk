Pod::Spec.new do |s|
  s.name             = 'armenus'
  s.version          = '0.1.0'
  s.summary          = 'Render restaurant dishes in 3D and place them on a table in AR.'
  s.homepage         = 'https://armenus.app'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Armenus' => 'support@armenus.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # System frameworks only; nothing vendored. ARKit is linked purely for
  # `ARWorldTrackingConfiguration.isSupported` and `ARQuickLookPreviewItem` —
  # no ARSession is ever created, so adding this plugin does not give a host
  # app a camera permission requirement.
  s.frameworks = 'ARKit', 'QuickLook', 'SceneKit', 'UIKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
