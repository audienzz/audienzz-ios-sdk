Pod::Spec.new do |spec|
  spec.name     = 'AudienzziOSSDK'
  spec.version  = '0.0.5'
  spec.license  = { :type => 'Apache-2.0', :file => 'LICENSE' }
  spec.homepage = 'https://github.com/audienzz/audienzz-ios-sdk'
  spec.authors  = { 'Audienzz <tech@audienzz.ch>' => 'https://audienzz.ch' }
  spec.summary  = 'iOS implementation of the Audienzz SDK'
  spec.source   = { :git => 'https://github.com/audienzz/audienzz-ios-sdk.git', :branch => 'feature/lib' }

  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '16.0'

  spec.static_framework      = true
  spec.requires_arc          = true

  spec.source_files          = 'AudienzziOSSDK/**/*.swift'
  spec.exclude_files         = 'AudienzziOSSDK/AudienzziOSSDKTests/'

  spec.dependency 'PrebidMobile'
  spec.dependency 'PrebidMobileGAMEventHandlers'
  spec.dependency 'SQLite.swift', '~> 0.14.0'
  spec.dependency 'Google-Mobile-Ads-SDK'
  spec.dependency 'GoogleAds-IMA-iOS-SDK'
end
