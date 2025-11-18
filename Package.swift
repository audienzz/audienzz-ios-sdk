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
        .package(url: "https://github.com/prebid/prebid-mobile-ios.git", from: "3.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "12.3.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-interactive-media-ads-ios.git", from: "3.18.4"),
    ],
    targets: [
        .target(
            name: "AudienzziOSSDK",
            dependencies: [
                .product(name: "PrebidMobile", package: "prebid-mobile-ios"),
                .product(name: "PrebidMobileGAMEventHandlers", package: "prebid-mobile-ios"),
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
