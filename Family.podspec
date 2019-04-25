Pod::Spec.new do |s|
  s.name             = "Family"
  s.summary          = "A child view controller framework that makes setting up your parent controllers as easy as pie."
  s.version          = "0.14.10"
  s.homepage         = "https://github.com/zenangst/Family"
  s.license          = 'MIT'
  s.author           = { "Christoffer Winterkvist" => "christoffer@winterkvist.com" }
  s.source           = {
    :git => "https://github.com/zenangst/Family.git",
    :tag => s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/zenangst'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '9.2'

  s.requires_arc = true
  s.ios.source_files = 'Sources/{iOS+tvOS,iOS,Shared}/**/*'
  s.tvos.source_files = 'Sources/{iOS+tvOS,tvOS,Shared}/**/*'
  s.macos.source_files = 'Sources/{macOS,Shared}/**/*'

  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.2' }
end
