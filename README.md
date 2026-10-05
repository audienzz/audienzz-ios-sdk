> **Upgrade notice:** the remote interstitial's `load()` / `preload()` / `showAtOpportunity()`
> are **removed**, replaced by `prefetch` / `show` / `prefetchAndShow`. See
> [Migrating](#migrating-from-load--preload--showatopportunity) and the [CHANGELOG](CHANGELOG.md).

Audienzz iOS SDK
========

## Quick integration (remote config + `pageImpression`)

Initialize once, report navigation, and keep one owner per placement. Remote configuration controls
banner sizes, lazy loading and refresh; you do not need your own refresh timers.

**Start here for RemoteBanners and remote interstitials.** Follow steps 1–5 in order. The Original
and Rendering API examples later in this document are separate, advanced integrations.
Ask Audienzz for your **publisher ID** and **banner/interstitial configuration IDs**; use your own
Google Mobile Ads **app ID**. GAM ad-unit paths and Prebid placement IDs come from remote config.

### 1. Install

This guide targets iOS SDK **0.4.3**, with a minimum deployment target of **iOS 15.0**.
Swift Package Manager: add `https://github.com/audienzz/audienzz-ios-sdk.git` and select `0.4.3`.
CocoaPods: `pod 'AudienzziOSSDK', '~> 0.4.3'`.

Add your GAM/AdMob app ID to `Info.plist` under `GADApplicationIdentifier`.
In GAM, leave each banner ad unit's **refresh rate unset**; Audienzz owns refresh.

### 2. Initialize once, from app startup

Run your CMP and forward its result through `AUTargeting.shared` before initializing or creating
ads — see [Consent](#consent). Call this from your shared app startup flow after consent, before
loading ads on any entry route:

```swift
import AudienzziOSSDK
import GoogleMobileAds

@MainActor
func initializeAds() async throws {
    AudienzzRemoteConfig.shared.configureRemote(
        remoteUrl: URL(string: "https://api.adnz.co/api/ws-sdk-config/public/v1/")!,
        publisherId: "YOUR_PUBLISHER_ID"
    )
    try await Audienzz.shared.configureWithRemoteSDK()
    MobileAds.shared.start()
    AudienzzGAMUtils.shared.initializeGAM()
}
```

Await this once and handle errors in your startup flow; keep app content available on failure.
Do not load remote banners before their configuration is available. Initialization can fall back
to default Prebid settings if configuration retrieval fails; that does not create missing remote
placements. Use publisher and placement IDs from the same configuration environment.

### 3. Report navigation, before loading the page's ads

```swift
// Your navigation callback, including the initial destination:
Audienzz.shared.pageImpression(destinationViewController)
```

The report releases the previous page's banners and gives this visit its analytics identity.
Recommended startup order: **initialization → page report → ad creation/load**. Report only the
visible destination, not controllers your navigator pre-creates off screen.

| Situation | Report a new page? |
|---|---|
| First visible screen, navigation, tab change, back, or a new article | **Yes**, including destinations with no ads; report before loading their ads |
| App background → foreground | **No** — native recovery refreshes the active page's banners |
| SDK interstitial dismissal | **No** — native recovery handles it |
| Layout, render/rebuild, scrolling, or an ad callback | **No** |

A manual `pageImpression` call always starts a new visit, even for the same screen key.
Automatic recovery keeps `page_impression_id`, `au_page_seq` and `au_slot`; replacement requests
advance `hb_refresh_count`. Visibility and publisher pauses still apply. Interstitial events keep
the page captured at prefetch. Actual navigation during an interstitial still needs a page report.

Do not report unconditionally from `viewWillAppear` / `viewDidAppear`: these can also run after an
interstitial closes. The automatic return behavior described here requires iOS SDK `0.4.2` or newer.

### 4. Place a remote banner

Retain the remote owner as a **property**; adding its inner ad to a container does not retain it.

```swift
final class ArticleViewController: UIViewController {
    @IBOutlet private weak var bannerContainer: UIView!
    private let banner = AURemoteConfigBannerView(adConfigId: "YOUR_BANNER_CONFIG_ID")

    // Your router calls this once per actual navigation visit, after SDK startup.
    // This is an app-defined hook, not a UIKit lifecycle override.
    func pageBecameCurrent() {
        loadViewIfNeeded()
        Audienzz.shared.pageImpression(self)
        view.layoutIfNeeded()
        banner.load(in: bannerContainer, rootViewController: self)
    }

    deinit { banner.destroy() }
}
```

The call above implements step 3 too; do not report the same visit a second time from the router.
Give the container a real width before loading; omit `size` for backend adaptive sizing. The SDK
updates its height after creative sizing, so do not keep adding height constraints in callbacks.
Lazy loading defaults to `true` with a `200pt` prefetch margin; both are backend-controlled.

For SwiftUI/custom routes sharing a controller, call `banner.setScreen(routeInstanceKey)` before
loading and report that same key instead of the controller. Keep keys distinct for separate route
instances. Destroy an owner when its placement is permanently removed; keep it alive through
ordinary page returns. For custom covers, pair `pauseSmartRefresh()` with `resumeSmartRefresh()`.

Periodic refresh uses backend `config.refreshTimeSeconds`: missing/null or `0` means **no
periodic refresh**, and an explicit value such as `7` or `30` is respected.
The clock starts after loading completes and advances only while the banner is attached, on the
active page, in the foreground, allowed by the viewport gate, and not paused or covered by an SDK
interstitial or a reported overlay. Hidden time does not count; returning resumes the remaining
time. With `7`, the next request starts after **seven eligible seconds**, then needs time to load.
Navigation/foreground/interstitial recovery is separate from this timer. See [Smart Refresh](#smart-refresh).

### 5. Show an interstitial

Retain one owner per placement as a property of its presenting scope:

```swift
private let interstitial = AURemoteConfigInterstitial(adConfigId: "YOUR_INTERSTITIAL_CONFIG_ID")

// At a prefetch opportunity: cache one ad, never present.
interstitial.prefetch { result in
    if case .failure(let error) = result { print(error) }
}

// Later, at a display opportunity: show now if ready, otherwise skip.
let submitted = interstitial.show(from: self, eligible: canShowAd)

// Alternative flow: request and present as soon as ready.
if canShowAd {
    interstitial.prefetchAndShow(from: self) { result in
        if case .failure(let error) = result { print(error) }
    }
}
```

These are separate event-handler actions, not three calls to run together. `canShowAd` is your
frequency-cap and screen-policy decision. Observe delegate callbacks / `onPresentationError` for
presentation outcomes. Repeated prefetches share an outstanding load or retain the ready ad.
Keep the owner through dismissal and call `destroy()` when finished. See
[interstitial details](#interstitial-ad-remote-config).

### Verify the integration

- Open the app directly on an ad screen: report one page before its first ad request.
- Scroll a banner off-screen and back: periodic refresh pauses, then counts the remaining eligible time.
- Navigate to an ad-free screen and back: the hidden page stops requesting; each visit gets a new PI.
- Background/restore the app and show/dismiss an interstitial: eligible banners recover without a
  new PI. Try `prefetch()` → `show()` twice with the same interstitial owner.

---

## Overview

A mobile advertising SDK that combines header bidding capabilities from Prebid Mobile with Google's advertising ecosystem through a unified interface.
The implementation includes lazy loading functionality to optimize application performance by deferring ad initialization until needed.

> ### ⚠️ Important
>
> - **You report every screen.** Call `Audienzz.shared.pageImpression(...)` on every screen, sheet or popup that can show an ad — including ad-free destinations, because reporting those is what releases the previous screen's banners. There is no automatic tracking: it was removed so that every platform behaves the same way, and so that a screen the SDK cannot see (SwiftUI, a custom router) is not a special case. See [Screen reporting](#step-2--screen-reporting).
> - **Page ownership always applies.** Navigation pauses/releases the previous page’s banners regardless of Smart Refresh v2. The opt-in `smartRefreshV2` flag (or `Audienzz.shared.smartRefreshV2Override`) selects the stricter directional viewport gate only. See [Smart Refresh](#smart-refresh).

## How screens & ads work (read this first)

The SDK is **screen-aware**: it knows which screen is active and which ads belong to it, and drives
each ad's lifecycle (page impressions + smart refresh) for you. Understanding this model is the key
to integrating correctly.

- **A screen** is whatever you report: a `UIViewController`, a SwiftUI destination, a sheet. You
  tell the SDK when one becomes current with `Audienzz.shared.pageImpression(...)` — see
  [Screen reporting](#step-2--screen-reporting).
- **An ad belongs to the screen it is placed in.** Each banner resolves its host view controller by
  walking the responder chain, and screens are matched by **object identity**, so two tabs, or two
  instances of the same screen class, are distinct. The host is pinned once resolved, so the
  association never drifts. When the responder chain cannot distinguish your screens (SwiftUI, or
  several screens in one controller), tag each banner with the same key you report:
  `banner.setScreen("home")`.
- **Lifecycle:** when a screen becomes active, its banners (re)load; when you leave it, they pause;
  returning reloads them, independently of Smart Refresh v2. This stops off-screen slots from auctioning and
  gives each visit a fresh, viewable ad.
- **Report ad-free destinations too.** A settings screen with no ads still has to be reported —
  that report is what releases the banners of the screen the reader just left. Skipping it leaves
  them auctioning for a screen nobody is looking at.

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

The Audienzz iOS SDK requires a minimum iOS version of **15.0** or higher.

Download using SPM
========

Open your project in XCode. Go to the file "Add package dependencies" and insert link to the github "https://github.com/audienzz/audienzz-ios-sdk.git"

## Quick Start

Use the [five-step remote integration above](#quick-integration-remote-config--pageimpression).
It includes consent/startup ordering, page reporting, banner ownership and interstitial presentation.
The manual APIs below are reference material for apps that supply their own Prebid/GAM configuration;
they do not fetch remote placement settings or replace the remote startup flow.

## Consent

The SDK does **not** gate itself on user consent — that's the app's responsibility.
Run your CMP (consent) flow and forward the result **before** you call
either SDK initialization method or load any ads:

1. Show your CMP and obtain the user's choice.
2. Forward the consent signals (GDPR subject, TCF consent string, purpose
   consents) via `AUTargeting.shared`.
3. **Then** initialize using the [remote startup flow](#2-initialize-once-from-app-startup),
   report the current page and load ads. Manual integrations use `configureSDK(...)` instead.

Initializing or loading ads before consent will request ads without the consent
signals.

## Initialize SDK

For a **manual configuration only**, call this once after your CMP flow has completed. Remote
integrations use `configureWithRemoteSDK()` from the quick guide instead; do not run both flows.

```swift
import AudienzziOSSDK
import GoogleMobileAds

func initializeManualAds() {
    Audienzz.shared.configureSDK(
        companyId: "COMPANY_ID",
        gadMobileAdsVersion: nil
    )
    MobileAds.shared.start()
    AudienzzGAMUtils.shared.initializeGAM()
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

### Prefetch Margin

The correct prefetch mechanism depends on the scroll container your ad lives in:

| Container | Prefetch mechanism | How to configure |
|---|---|---|
| `UIScrollView` / `UITableView` (non-cell) | Distance-based (pt) | `prefetchMarginPoints` on the ad view |
| `UITableView` / `UICollectionView` cells | Item-count-based | `UITableView.prefetchDataSource` / `UICollectionView.isPrefetchingEnabled` |

**Why they differ:** In a plain `UIScrollView` all views are laid out in the hierarchy upfront. The SDK observes `contentOffset` via KVO and can detect "this view is now within N pt of the visible area" at exactly the right scroll position.

In a `UITableView` or `UICollectionView`, cells are created and laid out on-demand — just before they scroll into view. By the time `createAd()` is called from `cellForRow(at:)`, the cell is already within ~a row height of the viewport.

**More precisely, the margin saturates rather than stops working.** Raising it above the dequeue distance changes nothing — the lead time is capped by when UIKit creates the cell, so 200, 600 and 2000 pt behave identically. Lowering it still works: `prefetchMarginPoints = 0` inside a cell does exactly what it says, and suppresses auctions for cells the reader dequeues but never scrolls to.

Lazy and eager loading **converge** in a cell, but they are not equivalent. They coincide only when the container dequeues the cell inside the margin *and* the ad is eligible at that moment. They diverge when:

- the margin is `0` or smaller than the dequeue distance — lazy then waits and eager does not;
- the table or collection view is configured to prefetch further ahead, which can put a dequeued cell outside the margin;
- the slot is not yet eligible when the cell appears — lazy re-evaluates, eager has already requested.

By default, lazy loading starts **200 pt before** the view enters the viewport. You can customise this with `prefetchMarginPoints`:

```swift
let bannerView = AUBannerView(
    configId: PREBID_CONFIG_ID,
    adSize: CGSize(width: 320, height: 50),
    adFormats: [.banner],
    isLazyLoad: true
)

// Default — start loading 200 pt before the view enters the viewport
// bannerView.prefetchMarginPoints = 200

// Custom margin — start loading 600 pt ahead
bannerView.prefetchMarginPoints = 600

// Exact visibility — load only when the view is actually on screen
bannerView.prefetchMarginPoints = 0
```

#### UITableView / UICollectionView cells

To start the auction earlier in a cell, the main lever is making the cell exist earlier — the table/collection prefetch APIs. `isLazyLoad = false` additionally removes the viewport condition entirely, which matters when the cell is dequeued outside the margin or is not yet eligible:

```swift
// In cellForRow(at:) — load immediately on cell creation
let bannerView = AUBannerView(
    configId: PREBID_CONFIG_ID,
    adSize: CGSize(width: 320, height: 50),
    adFormats: [.banner],
    isLazyLoad: false  // Load on cell creation — same timing as a saturated prefetch margin
)

// UICollectionView: enable prefetching so cells are created further ahead of the viewport
collectionView.isPrefetchingEnabled = true
```

#### React Native and other cross-platform hosts

The saturation above applies to **native** `UITableView`/`UICollectionView` only. React Native's `FlatList` is JS-level windowing over a plain `RCTScrollView` — not a `UITableView` or `UICollectionView` — so the ad view is mounted well ahead of the viewport and the distance-based margin applies normally. There, `prefetchMarginPoints` is the effective lever, and the 200 pt default is usually what binds.

If raising it does not move the auction earlier, the ad component is not mounting early enough: raise the list's `windowSize` / `initialNumToRender` rather than the margin. Saturation does return if the list recycles native views (e.g. FlashList) or if `removeClippedSubviews` is enabled on iOS, where it is off by default.

#### Remote-config banners

`AURemoteConfigBannerView` takes both delivery settings from the ad config only — **ad config → SDK default**. There is no app-side override: a placement behaves the same in every app and on every platform, and is tuned in the backend.

| Setting | Ad config field (`config`) | Default |
|---|---|---|
| Lazy loading | `lazyLoad` | `true` — the auction waits for the viewport |
| Prefetch margin | `prefetchDistanceDp` | `200` pt |

A refreshed ad config that changes either value replaces the banner on the next `load(...)` rather than coalescing into the old one.

> **Default is lazy.** A remote-config banner waits until the slot comes within the prefetch margin. This is deliberate: a publisher who builds several below-fold placements on entering an article would otherwise buy fills the reader may never approach, and an unrendered fill cannot become an impression. Set `lazyLoad: false` on the ad config for slots that are always on screen.

## Smart Refresh

> Eligible-time refresh requires iOS SDK `0.4.3` or newer.

Periodic refresh counts **only time when the banner is eligible to refresh**: its page is active,
the app is foregrounded, the viewport gate allows it, and no attachment, cover or publisher hold
blocks it. Pausing preserves accrued time. With a 10-second interval, 6 eligible seconds followed
by 40 hidden seconds leave 4 eligible seconds before the next request. A fresh interval starts
after each request completes; time spent loading does not count.

Remote banners read `config.refreshTimeSeconds` from the backend: missing/null or `0` means **no
periodic refresh** for that placement, and positive values are honored without the former
30-second minimum. An explicit backend value of `30` still means 30 eligible seconds. Initial
prefetch, explicit page changes, foreground recovery and interstitial-dismissal recovery keep
their existing behavior. No publisher timer is needed.

Enable it by setting `smartRefresh = true` on any `AUBannerView`:

```swift
let bannerView = AUBannerView(
    configId: PREBID_CONFIG_ID,
    adSize: CGSize(width: 320, height: 50),
    adFormats: [.banner],
    isLazyLoad: true
)
bannerView.smartRefresh = true
```

> **Note:** `smartRefresh` has no effect if `autorefreshTime` is not set on the ad unit configuration (i.e. no auto-refresh interval is defined).

### Smart Refresh v2 (screen-aware) — opt-in

Smart Refresh v2 selects a stricter viewport gate. It is **off by default**; when disabled, the
classic viewport gate applies. Page ownership and navigation recovery apply in both modes.

**Directional visibility gate.** A refresh runs only while the ad's **top edge is fully on screen** and **at least 50% of the ad is visible**. It pauses the moment the top scrolls off (even 1px) or more than half the ad drops below the fold — a stricter, less "wasteful" rule than a plain visible-percentage threshold. The **initial load is unaffected** (the ad still loads as early as possible via lazy/prefetch).

**Page-aware pause & reload applies in both modes.** Report the destination with `pageImpression`
before loading its ads. Leaving releases the previous page's banners; returning starts a new visit
and reloads eligible slots. App foreground and SDK interstitial dismissal instead recover the
current page without a new analytics visit, as described in the quick guide.

Optionally, set `Audienzz.shared.blankOnScreenReload = true` to clear the slot (keeping its size, so no layout shift) while a screen-change reload is in progress. The slot is blanked as soon as the page is left, so returning to it never shows the previous screen's creative — you see an empty slot until the fresh ad renders, rather than the old ad followed by a blank. If no replacement auction can start, the previous creative is left in place rather than leaving the slot empty with nothing on the way. Default is off.

Enable it per publisher from the backend remote config (`smartRefreshV2: true` on the publisher config), or locally in the app (the local override wins):

```swift
// Select the v2 viewport gate regardless of the backend flag.
Audienzz.shared.smartRefreshV2Override = true
```

> **Note:** v2 still requires `smartRefresh = true` and an `autorefreshTime` on each banner — the flag switches *which* refresh model runs, not whether refresh is enabled.
## Analytics

The SDK reports an ad-event clickstream to the Audienzz backend automatically. **Every ad-level
event fires on its own** once the SDK is initialized — you do not wire up bid, impression, click, or
viewability tracking yourself. Report each navigation visit, including ad-free destinations
([Screen reporting](#step-2--screen-reporting)).

### What gets collected

| Event | When it fires |
|---|---|
| `pageImpression` | A navigation visit is reported explicitly, including ad-free screens; app resume is not a new visit |
| `bidRequest` | A Prebid bid request is sent for a slot (also on each auto-refresh) |
| `bidResponse` | Prebid returns a result |
| `bidWon` | A Prebid bid wins — carries `auction_id`, `bidder_code` and available targeting metadata; unavailable exact bid price/currency and IDs are omitted |
| `noBid` | The auction returned no usable bid |
| `adImpression` | The ad is rendered on screen — carries `bidder_code` (the demand that rendered) |
| `adClick` | The user taps the ad |
| `viewability.start` | The ad first becomes ≥ 50% visible; once for that creative/auction, even after scrolling away and back |
| `viewability.success` | The ad stays ≥ 50% visible for 1 continuous second |

Banner, interstitial and rewarded ads on the Original API are all covered.

### Step 1 — Initialize the SDK

Analytics uses the **publisher ID** from remote configuration as `publisher_id`; the collector
resolves company and website IDs. Direct integrations can supply the publisher through
`configureAnalytics`. See [the analytics contract](docs/analytics-contract.md).

### Step 2 — Screen reporting

**You report every screen.** Call `pageImpression` when a screen becomes current. Each call fires a
`pageImpression` analytics event with a fresh page-impression id that tags every ad event of that
visit. It also drives page ownership in **both** refresh modes: entering a screen reloads its
banners and leaving releases them. Smart Refresh v2 only changes viewport eligibility.

```swift
// Your navigation callback, before loading the destination's ads.
// Do not report unconditionally from viewWillAppear/viewDidAppear.
Audienzz.shared.pageImpression(destinationViewController)

// A screen with no controller to point at (a SwiftUI destination, a custom router).
Audienzz.shared.pageImpression("home")

// A controller, but your own analytics name for it.
Audienzz.shared.pageImpression(self, name: "article/detail")
```

**Call it for ad-free destinations too.** A settings screen that carries no ads still ends the
previous screen's visit; without that report the banners you just navigated away from keep
auctioning.

**There is no automatic screen tracking.** The `viewDidAppear` observer that used to do this was
removed: it could not see SwiftUI destinations or custom routers, so those were a separate
integration anyway, and having two mechanisms meant a screen could be counted twice or not at all.
Every platform now behaves identically — the app always reports.

> **Migrating.** `Audienzz.shared.onScreenResumed(...)` is now `pageImpression(...)` with the same
> arguments, and `Audienzz.shared.autoScreenTracking` is removed. If you relied on automatic
> tracking, add a `pageImpression` call to each screen; nothing reports itself any more.

For a banner on a route the responder chain cannot identify, tag it with the same route-instance
key you report **before loading**. This is required in both refresh modes; otherwise the banner
resolves to the host view controller and will not match your route key:

```swift
let banner = AUBannerView(configId: "…", adSize: …, adFormats: [.banner])
banner.setScreen("home")                  // AURemoteConfigBannerView.setScreen("home") likewise
// …on navigation to that screen, before creating its ads:
Audienzz.shared.pageImpression("home")    // reloads banners tagged "home"; pauses the rest
```

The key is matched **by value**, so the string reported to `pageImpression` and the one passed to
`setScreen` just have to be equal.

Notes:
- An app-owned sheet or popover that covers a screen is a screen: report it, and report the screen underneath
  again when it is dismissed. SDK interstitials are handled automatically; do not report their dismissal.
- `setScreen` isn't needed for `UIViewController`-hosted banners (those are matched by the responder
  chain), only where several screens share one controller.
- There is **no `onPause`/teardown counterpart**. If no screen is ever reported, ad events still send
  without a page-impression id; the SDK does not invent a visit.

### Demand-source attribution (`bidder_code`) — optional GAM setup

`adImpression` reports `bidder_code` = the demand that actually rendered. To distinguish a winning
**Prebid** line item from **Google/ad-server** demand, the SDK listens for a GAM **app event named
`Prebid`**. For this to be accurate, your **GAM Prebid line item must be configured to send an app
event with the key `Prebid`** (an ad-ops / Google Ad Manager setup — no code on your side). Without
it, rendered ads are attributed to the ad server (`bidder_code = "google"`).

### Privacy

The SDK includes the device advertising id and standard device/app metadata with each event.
Configure your app's consent (GDPR/TCF) as usual via `AUTargeting`; the same consent signals that
govern Prebid apply.

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
| `adUnitConfiguration` | `AUAdUnitConfigurationType!`| Ad unit configuration object.                 |
| `onLoadRequest`    | `((AnyObject) -> Void)?`    | Callback triggered when a GAM request is ready.  |
| `prefetchMarginPoints` | `CGFloat`              | Distance in points before the view enters the viewport that starts the Prebid demand fetch. Only effective when `isLazyLoad = true`. **Default:** `200`. Inside `UITableView`/`UICollectionView` cells the margin saturates — raising it has no effect, lowering it (e.g. `0`) still does. See [Prefetch Margin](#prefetch-margin). |
| `smartRefresh`     | `Bool`                      | When `true`, pauses auto-refresh while the ad is off-screen and force-refreshes when it returns to viewport if the refresh interval has elapsed. **Default:** `false`. |

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
| `AUInterstitialView` | `configId: String`, `isLazyLoad: Bool` | Creates a new `AUInterstitialView`. ConfigId - refers to prebid config id      |
| `AUInterstitialView` | `configId: String`, `isLazyLoad: Bool`, `minWidthPerc: Int`, `minHeightPerc: Int` | Creates a new `AUInterstitialView` with a minimum size in percentage. ConfigId - refers to prebid config id |
| `AUInterstitialView` | `configId: String`                                               | Creates a new `AUInterstitialView` (lazy). ConfigId - refers to prebid config id                                   |

An interstitial's formats and API frameworks are not arguments: they are backend-controlled (`prebidConfig.format` / `prebidConfig.apis`), and a hand-built `AUInterstitialView` requests banner + video with MRAID 1/2/3 + OMID 1. The `api` of its `bannerParameters` / `videoParameters` is ignored. See [docs/interstitial-capabilities.md](docs/interstitial-capabilities.md).

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
| `isSdkInitialized`                       | `Bool`                               | `true` if the SDK is initialized.                                   |

**Methods:**

| Name                                | Parameters                                                                                               | Description                                  |
|-------------------------------------|----------------------------------------------------------------------------------------------------------|----------------------------------------------|
| `configureSDK`                     | `companyId: String`, `gadMobileAdsVersion: String? = nil` | Initializes the SDK. A Publisher Provided Identifier is generated, persisted and attached to every Google Ad Manager request automatically — see [PPIDManager](#ppidmanager) to supply your own instead. |
`setSchainObject` | `schain: String` | Method used to set Schain object for all ad requests. For example on usage refer to [AppDelegate](Examples/DemoSwiftApp/DemoSwiftApp/AppDelegate.swift)|
### `AUTargeting`

This object is used to set targeting parameters for ad requests.

**Properties:**

| Name                    | Type                       | Description                                                         |
|-------------------------|----------------------------|---------------------------------------------------------------------|
| `shared`                | `AUTargeting`              | Shared instance of the targeting object.                            |
| `subjectToGDPR`         | `Bool?`                    | Whether the user is subject to GDPR.                                |
| `gdprConsentString`     | `String?`                  | The GDPR consent string.                                            |
| `subjectToCOPPA`        | `Boolean?`                 | Whether the user is subject to COPPA.                               |
| `contentUrl`            | `String?`                  | Deep-link URL for the app screen displaying the ad.                 |
| `publisherName`         | `String?`                  | The name of the publisher.                                          |
| `location`              | `CLLocation?`              | The user's location.                                                |
| `eids`                  | `[[String: Any]]?`         | External user identity links.                                       |
| `userExt`               | `[String: AnyHashable]?`   | User exchange-specific extensions.                                  |

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

### `PPIDManager`

**Methods:**

| Name                                | Parameters                                       | Description                                    |
|-------------------------------------|--------------------------------------------------|------------------------------------------------|
| `setPublisherPPID`                          | `_ ppid: String?`                        | Supply your own PPID (e.g. a hashed e-mail). Takes precedence over the SDK-generated one; pass `nil` to clear and fall back to it. |
| `getPPID`                                   |                                          | The PPID currently being sent: your PPID if set, otherwise the SDK-generated UUID. `nil` only when consent is missing. |

A PPID is **always** sent with ad requests — the SDK generates one (a UUID,
persisted locally and rotated every 12 months) whenever you haven't supplied
your own. There is no enable/disable switch in the SDK: a missing PPID costs
frequency capping and cross-session targeting. One backend switch suppresses it:

| Publisher config field | Effect when `false` | Absent |
|---|---|---|
| `ppidEnabled` | No PPID is sent at all, including one you supplied | Enabled |


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

// Configure storeUrl. You should obtain the url from AppStore 
AUTargeting.shared.storeURL = "https://apps.apple.com/app/id0000000000"

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

### Multi-Size Banner

GAM can serve ads at any of the sizes you declare on the `AdManagerBannerView`. When the winning creative — whether from Prebid or a GAM direct campaign — renders at a size different from the primary declared size, the SDK automatically resizes the banner. There are two requirements on the client side.

#### 1. Declare additional sizes correctly

Use `AUBannerView.validAdSizes(for:)` instead of `NSValue(cgSize:)` when assigning `validAdSizes`. The raw `NSValue(cgSize:)` initializer wraps a plain `CGSize` rather than an `AdSize` struct, which causes GAM to silently ignore all additional sizes and only ever serve the primary size.

```swift
// ❌ Wrong — additional sizes are silently ignored by GAM
gamBannerAdView.validAdSizes = [
    NSValue(cgSize: CGSize(width: 300, height: 250)),
    NSValue(cgSize: CGSize(width: 300, height: 600)),
]

// ✅ Correct — properly encoded AdSize values
gamBannerAdView.validAdSizes = AUBannerView.validAdSizes(for: [
    CGSize(width: 300, height: 250),
    CGSize(width: 300, height: 600),
])
```

#### 2. Update container constraints when the size changes

When GAM serves at a size different from the primary `adSize`, the SDK calls `onAdSizeChanged` with the actual rendered dimensions. Use this callback to update your container constraints so the ad is neither clipped nor surrounded by blank space.

```swift
// Keep references to the constraints you want to update
var bannerHeightConstraint: NSLayoutConstraint!

// Set up your layout
bannerHeightConstraint = adContainerView.heightAnchor.constraint(equalToConstant: 250)
NSLayoutConstraint.activate([
    adContainerView.widthAnchor.constraint(equalToConstant: 300),
    bannerHeightConstraint,
])

// React to the actual rendered size
audienzzBannerView.onAdSizeChanged = { [weak self] newSize in
    self?.bannerHeightConstraint.constant = newSize.height
    UIView.animate(withDuration: 0.2) {
        self?.view.layoutIfNeeded()
    }
}
```

> **Note:** `AURemoteConfigBannerView` handles constraint updates automatically — no `onAdSizeChanged` wiring is needed when using remote configuration.

---

### Interstitial Ad
Here is minimum example of configuring and loading interstitial ad:

```swift
// Create an interstitial ad view. Its formats and API frameworks are backend-controlled.
let audienzzInterstitialView = AUInterstitialView(
    configId: PREBID_CONFIG_ID,        // Prebid configuration ID provided by Audienzz
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

## Remote Configuration Integration

The SDK supports a simplified integration using remote configuration. This allows you to manage ad units (GAM IDs, Prebid Config IDs, sizes, etc.) from the backend, requiring only a simple configuration ID in your app.

### Initialize SDK with Remote Configuration

Follow [quick integration steps 1–3](#quick-integration-remote-config--pageimpression): initialize
once after consent, report the current destination, then load its ads.

### Banner Ad (Remote Config)

Use `AURemoteConfigBannerView` to load a banner defined by a remote configuration ID.
Keep the remote banner as a **view-controller property**. `load(in:)` mounts its inner ad in the
container; it does not retain the remote owner. A temporary local owner is released before the
asynchronous Google load can run.

```swift
final class ArticleViewController: UIViewController {
    // Connect this outlet to the container in your storyboard/layout.
    @IBOutlet private weak var adContainerView: UIView!
    private let banner = AURemoteConfigBannerView(adConfigId: "YOUR_CONFIG_ID")

    // App-defined hook: called by your router for actual navigation, after SDK startup.
    // Do not also report the same visit elsewhere.
    func pageBecameCurrent() {
        loadViewIfNeeded()
        Audienzz.shared.pageImpression(self)
        view.layoutIfNeeded()
        banner.load(in: adContainerView, rootViewController: self)
    }

    deinit {
        banner.destroy()
    }
}
```

Identical `load` calls reuse the existing banner; `pageImpression` owns reactivation on return.
The SDK updates the container height when the creative size changes, so do not add a new height
constraint from each `bannerViewDidReceiveAd` callback. Report the new page on every destination,
including screens without ads, so banners from the previous page are released.

**Fixed Size Banner:**
For a configuration without adaptive sizing, pass the desired fixed size (e.g., 320x50) to `load`:

```swift
banner.load(in: adContainerView, size: CGSize(width: 320, height: 50), rootViewController: self)
```

**Adaptive Banner:**
If the remote configuration has adaptive banners enabled, simply omit the `size` parameter. The SDK will automatically calculate the optimal banner height based on the container view's width and the adaptive strategy defined in the backend configuration (e.g., `fullWidth` or `customWidth`):

```swift
banner.load(in: adContainerView, rootViewController: self)
```

### Interstitial Ad (Remote Config)

Use `AURemoteConfigInterstitial` to load an interstitial defined by a remote configuration ID.

Three verbs, and the verb decides whether anything is presented:

| Method | What it does |
| --- | --- |
| `prefetch(completion:)` | Obtains and retains one ad. Never presents. |
| `show(from:eligible:)` | Presents ready inventory at this opportunity, or reports why it could not. Never schedules a presentation for later. |
| `prefetchAndShow(from:completion:)` | Presents when the load completes, or presents inventory already in hand. |

```swift
// Retain one owner per placement outside transient page views.
let interstitial = AURemoteConfigInterstitial(adConfigId: "YOUR_CONFIG_ID")
interstitial.delegate = self
interstitial.onPresentationError = { print("Presentation failed: \($0)") }
interstitial.prefetch { result in
    // Update readiness/error UI here; this callback can never present anything.
    if case .failure(let error) = result { print(error) }
}

// At a later eligible transition, after evaluating the publisher's frequency cap:
let submitted = interstitial.show(from: self, eligible: publisherAllowsAd)
// false: this opportunity was skipped — nothing is replayed when loading finishes.
// true: submitted to Google; delegate/error callbacks report the outcome.
```

If you want the ad shown as soon as it arrives, ask for that by name:

```swift
interstitial.prefetchAndShow(from: self) { result in
    if case .failure(let error) = result { print(error) }
}
```

### Migrating from `load` / `preload` / `showAtOpportunity`

`load(completion:)` is **removed**. It meant "prepare inventory" in one release and "prepare and
then present" in the next, so a method call no longer tells you whether the reader will be
interrupted. Map by what your code actually relied on:

| Before | Now |
| --- | --- |
| `load { … }` used only to prepare inventory | `prefetch { … }`, then `show(from:)` at your opportunity |
| `load { … }` relied on for immediate display | `prefetchAndShow(from:) { … }` |
| `automaticallyShowOnLoad = false` + `load { … }` | `prefetch { … }` |
| `preload { … }` | `prefetch { … }` |
| `showAtOpportunity(from:eligible:)` | `show(from:eligible:)` |
| `show(from:)` | `show(from:)` — same call; it now reports a skipped opportunity instead of presenting blindly |

`automaticallyShowOnLoad` is removed with it: the behaviour it selected is now the difference
between two method names. Objective-C callers use `prefetchWithCompletion:` and
`prefetchAndShowWithCompletionFrom:completion:`.

## Sticky Ads

`AUStickyAdWrapperView` reserves a fixed area in your layout and keeps the ad view visible as the user scrolls past it. The child ad slides within that reserved area — sticking to the top of the viewport — then scrolls off once the reserved space has fully passed the viewport.

This is useful for billboard-height placements (e.g. 300×600) inside a scrollable page, where you want the ad to remain in view for as long as possible without overlapping other content.

### How it works

- You reserve `maxHeight` points in your layout by adding `AUStickyAdWrapperView` as a normal subview with Auto Layout constraints. Its intrinsic height is `maxHeight` — no height constraint required.
- The wrapper observes `UIScrollView.contentOffset` via KVO and repositions the child ad using `CGAffineTransform`, avoiding layout passes on every scroll tick.
- When the wrapper is fully above or below the visible viewport, the child snaps to its natural position. When the wrapper is partially in view, the child slides to stay on screen.

### Basic usage (manual banner)

```swift
// 1. Create your ad view as usual
let audienzzBannerView = AUBannerView(
    configId: "YOUR_PREBID_CONFIG_ID",
    adSize: CGSize(width: 300, height: 600),
    adFormats: [.banner]
)

let gamBannerView = AdManagerBannerView(adSize: GADAdSizeMediumRectangle)
gamBannerView.adUnitID = "YOUR_GAM_AD_UNIT_ID"
gamBannerView.rootViewController = self

audienzzBannerView.bannerParameters = AUBannerParameters()
audienzzBannerView.createAd(
    with: AdManagerRequest(),
    gamBanner: gamBannerView,
    eventHandler: AUBannerEventHandler(adUnitId: "YOUR_GAM_AD_UNIT_ID", gamView: gamBannerView)
)
audienzzBannerView.onLoadRequest = { request in
    guard let r = request as? Request else { return }
    gamBannerView.load(r)
}

// 2. Wrap the ad view
let stickyWrapper = AUStickyAdWrapperView(
    adView: audienzzBannerView,
    maxHeight: 600,         // Reserve 600 pt in the layout
    scrollView: scrollView  // The UIScrollView driving the page
)

// 3. Add to your layout — treat it like any other UIView
contentStackView.addArrangedSubview(stickyWrapper)
// or with manual constraints:
// view.addSubview(stickyWrapper)
// NSLayoutConstraint.activate([
//     stickyWrapper.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//     stickyWrapper.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//     stickyWrapper.topAnchor.constraint(equalTo: previousView.bottomAnchor),
// ])
```

### Usage with remote config banner

`AURemoteConfigBannerView` works as the child view without any changes — pass it directly to `AUStickyAdWrapperView`:

```swift
let remoteBanner = AURemoteConfigBannerView(adConfigId: "YOUR_CONFIG_ID")

let stickyWrapper = AUStickyAdWrapperView(
    adView: remoteBanner,
    maxHeight: 600,
    scrollView: scrollView
)
contentStackView.addArrangedSubview(stickyWrapper)

// Load the remote banner after the wrapper is in the view hierarchy
remoteBanner.load(in: stickyWrapper, rootViewController: self)
```

### Attaching to the scroll view later

If the `UIScrollView` is not available at initialisation time (for example, when building the layout inside `viewDidLoad` before the scroll view's frame is set), pass `nil` and call `attachToScrollView(_:)` later:

```swift
let stickyWrapper = AUStickyAdWrapperView(adView: audienzzBannerView, maxHeight: 600)
// ...add to hierarchy...

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    stickyWrapper.attachToScrollView(scrollView)
}
```

### Cleanup

`AUStickyAdWrapperView` invalidates its KVO observation automatically in `deinit`. If you remove the wrapper from the view hierarchy before it is deallocated — for example, when reusing a container — call `detachFromScrollView()` explicitly:

```swift
stickyWrapper.detachFromScrollView()
stickyWrapper.removeFromSuperview()
```

### Configuration reference

| Property | Type | Default | Description |
|---|---|---|---|
| `maxHeight` | `CGFloat` | `600` | Total height reserved in the layout. The child ad slides within this space. |
| `stickyTopOffset` | `CGFloat?` | `nil` | Y offset from the top of the scroll viewport where the ad sticks. `nil` uses the scroll view's top safe-area inset. |
| `isEnabled` | `Bool` | `true` | Toggle sticky behaviour. When `false`, the child stays at its natural position (offset 0). |

---

## Troubleshooting

### Unfilled ads
In order to handle unfilled ads it is advised to build your logic around `onAdFailedToLoad()` method.
There you receive `LoadAdError` object, which contains details about the error. When it has code:1 and message "No ad to show" - it is an unfilled ad.

### Banner is clipped or shows at the wrong height

**Symptom:** A multi-size banner is clipped to the primary declared height, or shows blank space when a smaller size is served. The ad is otherwise functional (impression and click tracking work correctly).

**Cause — incorrect `validAdSizes` encoding.** Setting `validAdSizes` using the plain `NSValue(cgSize:)` initializer causes GAM to silently discard all additional sizes and only serve the primary `adSize`. As a result, creatives that require a taller slot are clipped by the container.

```swift
// ❌ This looks correct but silently breaks multi-size serving
gamBannerAdView.validAdSizes = [NSValue(cgSize: CGSize(width: 300, height: 600))]
```

**Fix:** Use `AUBannerView.validAdSizes(for:)`, which encodes sizes as proper `AdSize` values that GAM understands:

```swift
// ✅ Correct
gamBannerAdView.validAdSizes = AUBannerView.validAdSizes(for: [
    CGSize(width: 300, height: 250),
    CGSize(width: 300, height: 600),
])
```

**Cause — container constraints not updated on size change.** Even after fixing the encoding, if your container has a fixed-height constraint sized to the primary ad slot, a taller creative will still be clipped. Wire up `onAdSizeChanged` on the `AUBannerView` to update the constraint whenever GAM serves at a different size (see the **Multi-Size Banner** example above).

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


## Refresh ownership and custom load completion

Original GAM display and native banners (`AUBannerView` and `AUNativeBannerView`) use an Audienzz-owned refresh controller. Prebid receives no refresh interval. Configure the GAM ad unit with its own refresh rate unset so it does not run a second schedule.

The refresh interval starts when Google finishes loading, including a no-fill response. Only a transient Google load failure triggers bounded retries. A Prebid timeout still proceeds to Google and does not retry a successfully filled Google slot. There is one Google load outstanding per banner view: after a page transition, its stale terminal callback is discarded before the replacement begins. This can defer a page replacement until the old Google load finishes.

Set the Google delegate before `createAd`. Passing an `AdManagerBannerView` installs the SDK's delegate wrapper automatically; `AUBannerEventHandler` can identify a Google banner inside a custom container. If the SDK cannot observe your custom ad-server view, report its terminal callback exactly once:

```swift
banner.notifyAdLoadCompleted(rendered: true)  // a creative is on screen
banner.notifyAdLoadCompleted()               // no-fill, or a permanent configuration failure
banner.notifyAdLoadCompleted(retryableFailure: true) // transient ad-server failure
```

`rendered` says whether a creative is actually on screen, and only a rendered one takes over the
slot's identity in the delivery trace — a no-fill ends the request without replacing what the user
is still looking at. Do not report these manually for a GAM banner already observed by the SDK. `stopAutoRefresh()` is a durable publisher block; only `resumeAutoRefresh()` clears it. Page, foreground, attachment and visibility blocks are independent, and visibility itself is two separate reasons: what the SDK measures from the view hierarchy, and what a host that does its own detection reports through `pauseSmartRefresh()` / `resumeSmartRefresh()`. Only the host can clear its own — the SDK cannot see a Flutter or React Native overlay drawn above the platform view, so nothing it measures is allowed to override that pause. First loads retain prefetch behavior; periodic refresh requires attachment and the configured visibility gate. Deferred first loads/page replacements recover when their applicable blocks clear.

The shared configuration's other consumers (custom native, multiformat, instream, interstitial and rewarded APIs) retain their configurable **demand** cadence through `AUConfiguredDemandRefresh`, without a Prebid timer. Their cadence ends at the demand handoff, not at a publisher-owned renderer's completion; they do not infer fast retries from Prebid results. Their page ownership is captured when the configured view is created, so report `pageImpression` first. This distinction does not change Prebid Rendering banner APIs, which remain a separate integration surface.


### Remote interstitial presentation behavior

Set `presentationViewController` and `delegate` before prefetching. A `prefetch` completion reports
loading only and can never present; `onPresentationError` reports preflight and Google presentation
errors, and — because it has no return value to inspect — the guards that cancel a
`prefetchAndShow`. `onLifecycleEvent` exposes correlated Google load/show milestones for publisher
analytics, including `opportunitySkipped` with a `reason`.

Repeated prefetches for one owner coalesce onto the request in flight and reuse valid ready
inventory, so a second call costs nothing. Repeated presentation calls cannot show twice or start a
parallel request. Supply the publisher's current frequency-cap decision as `eligible`; an unready,
inactive, ineligible or concurrent presentation skips that opportunity **without scheduling a
future show** — that is what `prefetchAndShow` is for, and it has to be asked for by name. Keep one
owner per logical placement. `show` returns whether presentation was submitted; delegate/error
callbacks report its outcome. Call UIKit-facing APIs on the main thread. The presentation exclusion
covers SDK remote interstitial owners; publishers must also account for other fullscreen content.

A ready or presenting ad is never replaced by another load. An ad expires after one hour, and no
presentation is replayed later if the app was inactive when loading finished. `destroy()` cancels
pending loads; destruction during a presentation is deferred until dismissal/failure.

Remote interstitial requests carry the same global GAM targeting as the other original API paths
(`AUTargeting.shared.addGlobalTargeting`), alongside the PPID.

Fullscreen `AUInterstitialView` and `AURewardedView` demand is one-shot and independent of page,
attachment, viewport and banner refresh. Their shared configuration cannot turn on a periodic
fullscreen timer. A page report never replaces their prefetched inventory.

### Automatic request counters

Original and remote banners include `au_page_seq`, `au_slot` and `hb_refresh_count` in GAM
custom targeting. Interstitials include only `au_page_seq` and `hb_refresh_count`; they never
consume a banner position. See [the request targeting contract](docs/ad-request-targeting.md)
for page resets, automatic slot ordering and request-count semantics. No new publisher parameter is required.

### Analytics environments and publisher identity

Remote initialization supplies the ws-sdk-config `publisher_id` automatically (including Flutter).
The collector resolves company and website IDs. Analytics defaults to `environment=production`;
set `test` or `staging` before initializing a non-production app. Our examples use `test`.
See [the analytics contract](docs/analytics-contract.md) for configuration, currency provenance,
missing Prebid metadata and release requirements. These additions require the upcoming native
releases; current published native pins do not provide them.
