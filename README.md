Audienzz iOS SDK
========
## Overview

A mobile advertising SDK that combines header bidding capabilities from Prebid Mobile with Google's advertising ecosystem through a unified interface.
The implementation includes lazy loading functionality to optimize application performance by deferring ad initialization until needed.

## Underlying Technologies

### Prebid Mobile SDK

Prebid Mobile is an open-source framework that enables header bidding within mobile applications.
It conducts real-time auctions where multiple demand sources compete for ad inventory placement.

Functionality:

- Real-time auction management between demand partners
- Communication with Prebid Server for bid processing
- Support for banner, native, and video ad formats
- Ad rendering from winning auction results

### Google Ads SDK (Google Mobile Ads SDK)

The Google Mobile Ads SDK provides access to Google's advertising networks including AdMob and Google 
Ad Manager. It handles ad serving and mediation across multiple ad networks.

Functionality:

- Banner, interstitial, native, and rewarded video ad formats
- Network mediation through Google's platform
- Performance analytics and reporting
- Privacy compliance features

## Minimum Supported iOS Version

The Audienzz iOS SDK requires a minimum iOS version of **13.0** or higher.

Download using SPM
========

Open your project in XCode. Go to the file "Add package dependencies" and insert link to the github "https://github.com/audienzz/audienzz-ios-sdk.git"

## Quick Start

Follow these steps to get your first ad showing:

1. Install the SDK via Swift Package Manager (SPM)
   - Add package dependency: `https://github.com/audienzz/audienzz-ios-sdk.git`
2. Configure Info.plist
   - Add Google Mobile Ads App ID: key `GADApplicationIdentifier` with your GAM/AdMob app ID
   - Ensure ATS/networking permissions per your org policy if needed
3. Initialize in AppDelegate
   - Call `Audienzz.shared.configureSDK(companyId: ..., gadMobileAdsVersion: ...)`
   - Start Google Mobile Ads: `GADMobileAds.sharedInstance().start()`
   - Initialize GAM helpers: `AudienzzGAMUtils.shared.initializeGAM()`
4. Create an ad unit in your UI
   - Banner: `AUBannerView(configId:..., adSize:..., adFormats:[.banner])`
   - Interstitial: `AUInterstitialView(configId:..., adFormats:[.banner] or [.video])`
5. Bridge to GAM and load
   - Use `createAd(with: AdManagerRequest, ...)`
   - In `onLoadRequest`, call the corresponding GAM `load` API
6. Verify
   - See Verification section below for what to look for

## Initialize SDK

Initialize the SDK in your `AppDelegate`:

```swift
import AudienzziOSSDK
import GoogleMobileAds

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Audienzz.shared.configureSDK(
        companyId: "COMPANY_ID",
        gadMobileAdsVersion: GADGetStringFromVersionNumber(GADMobileAds.sharedInstance().versionNumber)
    )
    GADMobileAds.sharedInstance().start()
    AudienzzGAMUtils.shared.initializeGAM()
    return true
}
```

CompanyId is provided by Audienzz, usually - it is id of the company in ad console.

## Lazy Loading

Sometimes application doesn't need to load an ad once the screen (view controller)
is instantiated. Instead of that it might be more optimal to start loading when the ad is actually
presented to user.

It can be done by setting `isLazyLoad: true` parameter when creating ad views:

```swift
let bannerView = AUBannerView(
    configId: PREBID_CONFIG_ID,
    adSize: CGSize(width: 320, height: 50),
    adFormats: [.banner],
    isLazyLoad: true  // Enable lazy loading
)
```

In this way the `createAd()` or `fetchDemand()` will be postponed until the view is shown on the screen.

The `createAd()` method, available on classes like `AUBannerView` and `AUInterstitialView`, initiates the ad loading process.
When `lazyLoading` is enabled, the SDK intelligently delays this process until the ad view is about to become visible to the user,
optimizing resource usage and improving performance. 
It is done with view visibility detection which triggers ad loading when the view becomes visible.

## API Reference

This section provides a detailed reference for the public API of the Audienzz SDK.

### AUAdFormat

`AUAdFormat` indicates which formats an ad unit supports. Some ad views (like `AUBannerView`) can request banner or outstream video; interstitials can be banner and/or video.

| Case      | Description                         | Typical Views                   |
|-----------|-------------------------------------|---------------------------------|
| `.banner` | HTML/MRAID banner creatives         | `AUBannerView`, `AUInterstitialView` |
| `.video`  | Outstream or interstitial video     | `AUBannerView`, `AUInterstitialView`, `AURewardedView` |
| `.native` | Native format assets (list-card UI) | `AUNativeView`, `AUNativeBannerView` |

Notes:
- For `AUBannerView`, use `[.banner]` for display or `[.video]` for outstream video in a banner slot. Multiformat is supported via `[.banner, .video]` when appropriate.
- If you only serve display banners with `AUBannerView`, you can simply pass `[.banner]`.

### `AUBannerView`

Ad view used for displaying banner and video ads.

**Properties:**

| Name               | Type                        | Description                                      |
|--------------------|-----------------------------|--------------------------------------------------|
| `videoParameters`  | `AUVideoParameters?`        | Video ad parameters (optional).                  |
| `bannerParameters` | `AUBannerParameters?`       | Banner ad parameters (optional).                 |
| `adUnitConfiguration` | `AUAdUnitConfigurationType!`| Ad unit configuration object.                    |
| `onLoadRequest`    | `((AnyObject) -> Void)?`    | Callback triggered when a GAM request is ready.  |

**Constructors:**

| Name                   | Parameters                                                                                      | Description                                                                                              |
|------------------------|-------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| `AUBannerView` | `configId: String`, `adSize: CGSize`, `adFormats: [AUAdFormat]`, `isLazyLoad: Bool` | Creates a new `AUBannerView` with specified ad formats. ConfigId - refers to prebid config id |
| `AUBannerView` | `configId: String`, `adSize: CGSize`, `adFormats: [AUAdFormat]`                                 | Creates a new `AUBannerView`. ConfigId - refers to prebid config id                              |

**Methods:**

| Name                     | Description                                                |
|--------------------------|------------------------------------------------------------|
| `createAd(with:gamBanner:eventHandler:)` | Prepares and requests an ad. |
| `addAdditionalSize(sizes:)` | Adds additional supported sizes. |
| `setImpOrtbConfig(ortbConfig:)` | Sets custom OpenRTB config. |
| `getImpOrtbConfig()` | Gets current OpenRTB config. |

### `AUInterstitialView`

Ad view used for displaying interstitial (full-screen) ads.

**Properties:**

| Name               | Type                        | Description                                      |
|--------------------|-----------------------------|--------------------------------------------------|
| `videoParameters`  | `AUVideoParameters?`        | Video ad parameters (optional).                  |
| `bannerParameters` | `AUBannerParameters?`       | Banner ad parameters (optional).                 |
| `onLoadRequest`    | `((AnyObject) -> Void)?`    | Callback triggered when a GAM request is ready.  |

**Constructors:**

| Name                         | Parameters                                                       | Description                                                                                                         |
|------------------------------|------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `AUInterstitialView` | `configId: String`, `adFormats: [AUAdFormat]`, `isLazyLoad: Bool` | Creates a new `AUInterstitialView` with specified ad formats. ConfigId - refers to prebid config id      |
| `AUInterstitialView` | `configId: String`, `adFormats: [AUAdFormat]`, `isLazyLoad: Bool`, `minWidthPerc: Int`, `minHeightPerc: Int` | Creates a new `AUInterstitialView` with a minimum size in percentage. ConfigId - refers to prebid config id |
| `AUInterstitialView` | `configId: String`, `adFormats: [AUAdFormat]`                                               | Creates a new `AUInterstitialView`. ConfigId - refers to prebid config id                                   |

**Methods:**

| Name                     | Description                                                |
|--------------------------|------------------------------------------------------------|
| `createAd(with:adUnitID:)` | Prepares and requests an ad. |
| `setImpOrtbConfig(ortbConfig:)` | Sets custom OpenRTB config. |
| `getImpOrtbConfig()` | Gets current OpenRTB config. |

### `AURewardedView`

Ad view used for displaying rewarded video ads.

**Properties:**

| Name               | Type                        | Description                                      |
|--------------------|-----------------------------|--------------------------------------------------|
| `videoParameters`  | `AUVideoParameters?`        | Video ad parameters (optional).                  |
| `onLoadRequest`    | `((AnyObject) -> Void)?`    | Callback triggered when a GAM request is ready.  |

**Constructors:**

| Name                   | Parameters                                                                                      | Description                                                                                              |
|------------------------|-------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| `AURewardedView` | `configId: String` | Creates a new `AURewardedView`. ConfigId - refers to prebid config id |

**Methods:**

| Name                     | Description                                                |
|--------------------------|------------------------------------------------------------|
| `createAd(with:adUnitID:)` | Prepares and requests an ad. |

### `AUBannerParameters`

This class is used to set banner-specific parameters.

**Constructors:**

| Name                       | Parameters | Description                               |
|----------------------------|------------|-------------------------------------------|
| `AUBannerParameters` |            | Creates a new `AUBannerParameters`. |

**Properties:**

| Name                              | Type                         | Description                                      |
|-----------------------------------|------------------------------|--------------------------------------------------|
| `api`                             | `[AUApiType]?` | The list of supported API frameworks.            |
| `interstitialMinWidthPercentage`  | `Int?`                       | The minimum width percentage for interstitials.  |
| `interstitialMinHeightPercentage` | `Int?`                       | The minimum height percentage for interstitials. |
| `adSizes`                         | `[CGSize]?`       | The set of ad sizes.                             |

### `AUVideoParameters`

This class is used to configure video-specific parameters for an ad request.

**Constructors:**

| Name                      | Parameters            | Description                                                                  |
|---------------------------|-----------------------|------------------------------------------------------------------------------|
| `AUVideoParameters` | `mimes: [String]` | Creates a new `AUVideoParameters` with a list of supported MIME types. |

**Properties:**

| Name             | Type                                    | Description                                                                    |
|------------------|-----------------------------------------|--------------------------------------------------------------------------------|
| `api`            | `[AUApiType]?`            | The list of supported API frameworks.                                          |
| `maxBitrate`     | `Int?`                                  | The maximum bitrate in Kbps.                                                   |
| `minBitrate`     | `Int?`                                  | The minimum bitrate in Kbps.                                                   |
| `maxDuration`    | `Int?`                                  | The maximum video ad duration in seconds.                                      |
| `minDuration`    | `Int?`                                  | The minimum video ad duration in seconds.                                      |
| `mimes`          | `[String]?`                         | The list of supported content MIME types.                                      |
| `playbackMethod` | `[AUVideoPlaybackMethodType]?` | The allowed playback methods.                                                  |
| `protocols`      | `[AUVideoProtocolsType]?`      | The supported video bid response protocols.                                    |
| `startDelay`     | `AUVideoStartDelay?`           | The start delay in seconds for pre-roll, mid-roll, or post-roll ad placements. |
| `placement`      | `AUPlacement?`            | The placement type for the impression.                                         |
| `linearity`      | `Int?`                                  | The linearity of the ad.                                                       |
| `adSize`         | `CGSize?`                       | The size of the ad.                                                            |

### `Audienzz`

This object contains methods to initialize the SDK and configure global settings.

**Properties:**

| Name                                     | Type                                    | Description                                                                             |
|------------------------------------------|-----------------------------------------|-----------------------------------------------------------------------------------------|
| `shared`                                 | `Audienzz`                                   | Shared instance of the Audienzz SDK.                        |
| `isSdkInitialized`                       | `Bool`                               | `true` if the SDK is initialized.                                                       |

**Methods:**

| Name                                | Parameters                                                                                               | Description                                  |
|-------------------------------------|----------------------------------------------------------------------------------------------------------|----------------------------------------------|
| `configureSDK`                     | `companyId: String`, `gadMobileAdsVersion: String? = nil` | Initializes the SDK.                         |

### `AUTargeting`

This object is used to set targeting parameters for ad requests.

**Properties:**

| Name                    | Type                       | Description                                                         |
|-------------------------|----------------------------|---------------------------------------------------------------------|
| `shared`                | `AUTargeting`              | Shared instance of the targeting object.                                  |
| `subjectToGDPR`         | `Bool?`                    | Whether the user is subject to GDPR.                               |
| `gdprConsentString`     | `String?`                  | The GDPR consent string.                                            |
| `subjectToCOPPA`        | `Boolean?`                 | Whether the user is subject to COPPA.                               |
| `contentUrl`            | `String?`                  | Deep-link URL for the app screen displaying the ad.                                  |
| `publisherName`         | `String?`                  | The name of the publisher.                                          |
| `location`              | `CLLocation?`              | The user's location.                                              |
| `eids`                  | `[[String: Any]]?`         | External user identity links.                                           |
| `userExt`               | `[String: AnyHashable]?`   | User exchange-specific extensions.                                           |

**Methods:**

| Name                                | Parameters                                       | Description                                    |
|-------------------------------------|--------------------------------------------------|------------------------------------------------|
| `addUserKeyword`                    | `keyword: String`                                | Adds a user keyword.                           |
| `addUserKeywords`                   | `keywords: Set<String>`                          | Adds a set of user keywords.                   |
| `removeUserKeyword`                 | `keyword: String`                                | Removes a user keyword.                        |
| `clearUserKeywords`                 |                                                  | Clears all user keywords.                      |
| `addUserData`                       | `key: String, value: String`                     | Adds user data.                            |
| `updateUserData`                    | `key: String, value: Set<String>`                | Updates user data.                         |
| `addAppKeyword`                     | `keyword: String`                                | Adds an app keyword.                           |
| `addAppKeywords`                    | `keywords: Set<String>`                          | Adds a set of app keywords.                   |
| `removeAppKeyword`                  | `keyword: String`                                | Removes an app keyword.                        |
| `clearAppKeywords`                  |                                                  | Clears all app keywords.                      |
| `addAppExtData`                     | `key: String, value: String`                     | Adds app extended data.                            |
| `updateAppExtData`                  | `key: String, value: Set<String>`                | Updates app extended data.                         |
| `removeAppExtData`                  | `key: String`                                    | Removes app extended data.                         |
| `clearAppExtData`                   |                                                  | Clears all app extended data.                      |
| `addBidderToAccessControlList`      | `bidderName: String`                             | Adds a bidder to the access control list.      |
| `removeBidderFromAccessControlList` | `bidderName: String`                             | Removes a bidder from the access control list. |
| `clearAccessControlList`            |                                                  | Clears the access control list.                |
| `getPurposeConsent`                 | `index: Int`                                     | Gets the purpose consent for a given index.    |
| `getGlobalOrtbConfig`               |                                                  | Gets the global ORTB configuration.            |
| `setGlobalOrtbConfig`               | `ortbConfig: String`                             | Sets the global ORTB configuration.            |
| `addGlobalTargeting`                | `key: String, value: String`                     | Adds single key-value targeting.            |
| `addGlobalTargeting`                | `key: String, values: Set<String>`               | Adds single key with multiple values targeting.            |
| `removeGlobalTargeting`             | `key: String`                                    | Removes targeting for specific key.            |
| `clearGlobalTargeting`              |                                                  | Clears all global targeting.            |

### Targeting & Advanced Configuration

You can set targeting parameters globally (for all ad units) using `AUTargeting`, or per ad unit using the `adUnitConfiguration` property on each ad view.

**Usage examples:**
```swift
// Privacy
AUTargeting.shared.subjectToGDPR = true
AUTargeting.shared.gdprConsentString = "<TCF_v2_consent_string>"
AUTargeting.shared.subjectToCOPPA = false

// User keywords and data (go to OpenRTB user object)
AUTargeting.shared.addUserKeyword("sports")
AUTargeting.shared.addUserKeywords(["subscriber", "premium"])
AUTargeting.shared.addUserData(key: "age", value: "25")
AUTargeting.shared.updateUserData(key: "interests", value: ["tech", "news"])

// App keywords and custom app data (go to OpenRTB app object)
AUTargeting.shared.addAppKeyword("breaking_news")
AUTargeting.shared.addAppKeywords(["ios", "swift"])
AUTargeting.shared.addAppExtData(key: "edition", value: "ch")
AUTargeting.shared.updateAppExtData(key: "sections", value: ["home", "sports"])

// Location (optional)
AUTargeting.shared.location = CLLocation(latitude: 47.3769, longitude: 8.5417)

// Global ORTB config (advanced). Provide a JSON string with ORTB fields you need.
AUTargeting.shared.setGlobalOrtbConfig(ortbConfig: "{" +
    "\"user\":{\"yob\":1999}," +
    "\"regs\":{\"coppa\":0}" +
"}")

// Programmatic global targeting via helper (automatically merges into global ORTB)
AUTargeting.shared.addGlobalTargeting(key: "site_category", value: "news")
AUTargeting.shared.addGlobalTargeting(key: "audiences", values: ["sports_fans", "subscribers"]) 
```

## Examples

### Banner Ad 
Here is minimum example of configuring and loading banner ad:

```swift
// Create a banner ad view with a specified width and height (for example 320 width and 50 height)
let audienzzBannerView = AUBannerView(
    configId: PREBID_CONFIG_ID,        // Prebid configuration ID provided by Audienzz
    adSize: CGSize(width: 320, height: 50),  // Banner size (320x50 points)
    adFormats: [.banner],              // Specify that this ad unit supports banner format
    isLazyLoad: true                   // Enable lazy loading for better performance
)

// Create Google Ad Manager(GAM) ad view - this is the actual view that will display the ad
let gamBannerAdView = AdManagerBannerView(adSize: GADAdSizeBanner)

// Set GAM ad unit id path to the GAM ad view - this identifies your ad unit in GAM
gamBannerAdView.adUnitID = GAM_AD_UNIT_ID_PATH
// Set the root view controller for proper ad presentation and user interaction handling
gamBannerAdView.rootViewController = self
// Set delegate to handle ad lifecycle events (load, fail, click, etc.)
gamBannerAdView.delegate = self

// Create banner parameters for AUBannerView - these configure the banner ad request
let audienzzBannerParameters = AUBannerParameters()

// Set parameters to the banner ad view - attach the configuration to the ad view
audienzzBannerView.bannerParameters = audienzzBannerParameters

// Create ad by providing gamBannerAdView and event handler, then call createAd method to start loading the ad
audienzzBannerView.createAd(
    with: AdManagerRequest(),          // Create a new GAM request object
    gamBanner: gamBannerAdView,       // Pass the GAM banner view for ad display
    eventHandler: AUBannerEventHandler(  // Create event handler to manage ad events
        adUnitId: GAM_AD_UNIT_ID_PATH,   // GAM ad unit ID for tracking
        gamView: gamBannerAdView         // Reference to the GAM view
    )
)

// Handle the result of prebid bid request and then load ad with GAM request returned after prebid bid request
audienzzBannerView.onLoadRequest = { gamRequest in
    // Safely cast the request to the correct type, with error handling
    guard let request = gamRequest as? Request else {
        print("Failed request unwrap")
        return
    }
    // Load the ad using the enhanced GAM request that includes prebid data
    gamBannerAdView.load(request)
}
```

### Interstitial Ad
Here is minimum example of configuring and loading interstitial ad:

```swift
// Create an interstitial ad view with specified ad formats
let audienzzInterstitialView = AUInterstitialView(
    configId: PREBID_CONFIG_ID,        // Prebid configuration ID provided by Audienzz
    adFormats: [.banner],              // Specify that this ad unit supports banner format (for interstitial)
    isLazyLoad: true                   // Enable lazy loading for better performance
)

// Create ad by providing ad unit ID - this initiates the prebid auction
audienzzInterstitialView.createAd(
    with: AdManagerRequest(),          // Create a new GAM request object
    adUnitID: GAM_AD_UNIT_ID_PATH     // GAM ad unit ID for the interstitial
)

// Handle the result of prebid bid request and then load ad with GAM request returned after prebid bid request
audienzzInterstitialView.onLoadRequest = { [weak self] gamRequest in
    // Use weak self to prevent retain cycles in the closure
    guard let self = self else { return }
    
    // Safely cast the request to the correct type, with error handling
    guard let request = gamRequest as? AdManagerRequest else {
        print("Failed request unwrap")
        return
    }
    
    // Load the interstitial ad using the enhanced GAM request that includes prebid data
    AdManagerInterstitialAd.load(
        with: GAM_AD_UNIT_ID_PATH,     // GAM ad unit ID for the interstitial
        request: request               // Enhanced request with prebid data
    ) { ad, error in
        guard let self = self else { return }  // Check self again in completion handler
        
        if let error = error {
            // Handle loading error - log the error for debugging
            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
        } else if let ad = ad {
            // Ad loaded successfully - set up presentation and event handling
            ad.fullScreenContentDelegate = self  // Set delegate for full-screen events
            self.audienzzInterstitialView.connectHandler(  // Connect Audienzz event handler
                AUInterstitialEventHandler(adUnit: ad)     // Create handler for ad events
            )
            ad.present(from: self)     // Present the interstitial ad to the user
        }
    }
}
```

You can find more examples of practical implementation here:

[Demo App](AudienzziOSSDK/Examples/DemoSwiftApp)

## Troubleshooting

### Unfilled ads
In order to handle unfilled ads it is advised to build your logic around `onAdFailedToLoad()` method.
There you receive `LoadAdError` object, which contains details about the error. When it has code:1 and message "No ad to show" - it is an unfilled ad.

## Glossary / Terminology

- Prebid Config ID: Identifier of the Prebid impression configuration defined on your Prebid Server (aka stored request ID). Used as `configId` across ad views.
- GAM Ad Unit ID: The Google Ad Manager ad unit path (e.g., "/12345/my_app/banner_top"). Used when calling GAM `load` APIs.
- ORTB / OpenRTB: Open standard specification for programmatic ad requests and responses. The SDK builds ORTB requests for demand. You can customize parts of the request via targeting APIs.
- GPID: Google Publisher Provided Identifier. Optional identifier you can set per ad unit for downstream reporting and targeting.

## Verification

Use this checklist to verify your integration:

- Initialization
  - Confirm `Audienzz.shared.configureSDK(...)` runs without errors
  - Ensure `GADMobileAds.sharedInstance().start()` is called
- Network
  - Observe a Prebid request to your Prebid Server endpoint
  - Observe a GAM request (gampad) with Prebid key-values appended
- Rendering
  - Banner: A creative renders without errors in console
  - Interstitial/Rewarded: Fullscreen presentation appears and dismisses correctly
- Targeting
  - If you added keywords/data, verify the key-values in the GAM request inspector
- Troubleshooting
  - No Fill: Handle gracefully and move on to the next refresh/opportunity
  - Check device logs for any Prebid/GAM errors

---

## License

    Copyright 2025 Audienzz AG.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
       http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
