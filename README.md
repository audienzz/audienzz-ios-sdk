Audienzz iOS SDK
========

A wrapper for [Prebid Mobile SDK](https://github.com/prebid/prebid-mobile-ios) with support of
ads lazy loading.

Download using SPM
========

Open your project in XCode. Go to the file "Add package dependencies" and insert link to the github "https://github.com/audienzz/audienzz-ios-sdk.git"


Getting started
=======

Initialize SDK
-------
First of all, SDK needs to be intialized with context in AppleDelegate.
import AudienzziOSSDK and import GoogleMobileAds

```swift
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Audienzz.shared.configureSDK(audienzzKey: "companyID",
                                     gadMobileAdsVersion: GADGetStringFromVersionNumber(GADMobileAds.sharedInstance().versionNumber))
        
        // Initialize GoogleMobileAds SDK
        GADMobileAds.sharedInstance().start()
        AudienzzGAMUtils.shared.initializeGAM()
        return true
    }
}
```

Lazy Loading
-------
Sometimes application doesn't need to load an ad once the screen.
is instantiated. Instead of that it might be more optimal to start loading when the ad is actually
presented to user, for example scroll reached the required view.

```
AUBannerView(configId: storedImpDisplayBanner, adSize: adSize, adFormats: [.banner], isLazyLoad: true)
```

Examples
========

You can find more examples of practical implementation here:

[Examples](AudienzziOSSDK/Examples/DemoSwiftApp)

License
========

    Copyright 2024 Audienzz AG.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
       http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
