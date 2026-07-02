// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "AudienzziOSSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "AudienzziOSSDK",
            targets: ["AudienzziOSSDK"]
        )
    ],
    dependencies: [
        // Patched Prebid fork that surfaces exact winning-bid economics (cpm/currency/creative_id/
        // auction_id/ad_id) on the original (GAM) API for analytics. Fork of prebid-mobile-ios 3.3.1;
        // see branch audienzz-analytics-economics.
        .package(url: "https://github.com/audienzz/audienzz-ios-prebid-sdk-fork.git", exact: "3.3.1-audienzz.1"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", "0.14.1"..<"0.16.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-interactive-media-ads-ios.git", from: "3.18.4"),
    ],
    targets: [
        .target(
            name: "AudienzziOSSDK",
            dependencies: [
                .product(name: "PrebidMobile", package: "audienzz-ios-prebid-sdk-fork"),
                .product(name: "PrebidMobileGAMEventHandlers", package: "audienzz-ios-prebid-sdk-fork"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "GoogleInteractiveMediaAds", package: "swift-package-manager-google-interactive-media-ads-ios")
            ],
        ),
        .testTarget(
            name: "AudienzziOSSDKTests",
            dependencies: ["AudienzziOSSDK"],
        )
    ]
)
