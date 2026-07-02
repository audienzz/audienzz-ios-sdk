Pod::Spec.new do |spec|
    spec.name     = 'AudienzziOSSDK'
    spec.version  = '0.2.5'
    spec.license  = { :type => 'Apache-2.0', :file => 'LICENSE' }
    spec.homepage = 'https://github.com/audienzz/audienzz-ios-sdk'
    spec.authors  = { 'Audienzz <tech@audienzz.ch>' => 'https://audienzz.ch' }
    spec.summary  = 'iOS implementation of the Audienzz SDK'
    spec.source   = { :git => 'https://github.com/audienzz/audienzz-ios-sdk.git',
                      :tag => '0.2.5' }

    spec.swift_version         = '5.0'
    spec.ios.deployment_target = '13.0'

    spec.static_framework      = true
    spec.requires_arc          = true

    spec.source_files          = 'Sources/**/*.swift'
    spec.exclude_files         = 'Tests', 'Examples'

    # NOTE (CocoaPods only): these pull stock PrebidMobile from the CocoaPods trunk. Unlike the
    # SPM build (Package.swift), CocoaPods integrations do NOT use our patched Prebid fork
    # (github.com/audienzz/audienzz-ios-prebid-sdk-fork, tag 3.3.1-audienzz.1), because a pod
    # dependency cannot override the source of a transitive pod — only the app's Podfile can, via
    # `pod 'PrebidMobile', :git => '...fork...'`. Consequence for CocoaPods users: analytics still
    # works, but the exact bid economics (cpm/currency/creative_id/auction_id/ad_id) stay empty
    # (only the hb_* keyword subset is available). SPM users get the full economics.
    # Long-term fix: upstream a PR exposing the winning bid on Prebid's BidInfo, then drop the fork.
    spec.dependency 'PrebidMobile', '~> 3.0'
    spec.dependency 'PrebidMobileGAMEventHandlers', '~> 3.0'
    spec.dependency 'SQLite.swift', '~> 0.14'
    spec.dependency 'Google-Mobile-Ads-SDK', '~> 13.0'
    spec.dependency 'GoogleAds-IMA-iOS-SDK', '~> 3.26'
end
