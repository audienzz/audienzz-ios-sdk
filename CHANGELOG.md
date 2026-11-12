# Changelog

## 0.4.6

- **Gallery ads (`AUGalleryAds`) for paged screens (ePaper).** Each
  `AUGalleryAdSlot(slotKey:adConfigId:pageIndex:)` requests its remote-config banner once the reader
  is within the ad config's new `config.preloadDistancePages` (default 2) of its page, instead of
  when the screen opens or when the page's cell is built. Feed the position with
  `updatePosition(_:)` (paging scroll view: `contentOffset.x / bounds.width`) and place the ad with
  `embed(_:in:)` (full width, centered vertically); the banner stays in a host view the gallery
  owns, so reusing cells never destroys it. Refresh is the ad config's `refreshTimeSeconds`,
  counted only while on screen. Leaving the gallery's screen and coming back keeps the ad
  (`keepsAdAcrossPages`), unless the ad config's new `config.refreshOnBack` is `true` (default
  `false`), which reloads it on return like any other banner.
- **Fix: a view controller passed as a screen is no longer retained.** `AUBannerView.setScreen` and
  `AURemoteConfigBannerView.setScreen` hold a `UIViewController` weakly (route keys stay strong): a
  screen that owns its banners was kept alive by them.
- **`AUBannerView.keepsAdAcrossPages`** (default `false`). When on, a banner that has loaded is
  only paused while its page is not the active one: the creative stays (no release, no blanking),
  no auction runs and no viewability or `placementVisible` is counted (an impression Google
  records meanwhile is recorded too, so the two agree); on return (page or foreground recovery) its refresh
  resumes with the remaining eligible interval instead of a forced new auction. For bridges'
  gallery (ePaper) slots that a reader leaves for an article and comes back to. Set before the
  first load.
- **Fluid GAM size for remote banners.** An ad config can set `gamConfig.includeFluid: true`. The
  banner then also asks GAM for the fluid size next to its fixed `gamConfig.adSizes`, so fluid
  creatives such as GAM native styles can serve into the same slot (full container width, height
  set by the creative). Prebid is unaffected and keeps bidding on `prebidConfig.adSizes`. Off when
  absent or not a JSON boolean. The host must give the container its width (as for full-width
  slots); a fixed creative served into a fluid slot is centered by Google.

## 0.4.5

- Every original-API GAM request now carries the reportable key-value `isIFAavailable` = `true` /
  `false`: whether a usable IDFA is available (ATT authorized, identifier not all zeros). It comes
  from the background IDFA cache, so the key is omitted until the first read after launch or
  activation completes. SDK-owned, like `au_sdk`. See `docs/ad-request-targeting.md`.
- New analytics event `placementVisible` (banners) for fill rate: sent once per auction when at
  least 1 pt of the slot is on screen with the app in the foreground after the auction ended,
  filled or not. Carries `auction_id` (same as `adImpression`), `slot_reload` and `ad_unit_code`.
  Never sent for a slot that does not appear; a refresh or leaving the page closes the auction.
- Analytics field `publisher_id` is renamed `sdk_id` (same ws-sdk-config id). Events queued by an
  older version are re-sent under the new name. Its value is the remote config's `sdkId`; before
  the config is available (or if it has none) it is the id passed to `configureRemote`.
- Remote config is fetched from ws-sdk-config `sdks/{sdkId}` (and `sdks/{sdkId}/ad-configs`)
  instead of `publishers/{id}`. Same response; a server without the new route (HTTP 404) falls
  back to the old one.
- Fix app hangs from analytics reading the IDFA on the main thread
  ([#62](https://github.com/audienzz/audienzz-ios-sdk/issues/62)). `advertisingIdentifier` is a
  blocking XPC call to `lsd` even when ATT is not authorized, and it was made for every analytics
  event. It is now read in the background at initialization and on every app activation, dropped
  when the app backgrounds (so a revocation in Settings is never reported), and events only take
  the cached value; events logged before the first read completes omit `device_id`.
- Analytics no longer blocks on the main thread to resolve the WebView user agent when an event is
  mapped off main, which could deadlock against the main thread logging an event.

## 0.4.4

- **Behavior change: a remote banner without a refresh interval no longer refreshes.** When the ad
  config's `refreshTimeSeconds` is missing or `null`, the banner now has no periodic refresh (same
  as `0`) instead of the 10-second fallback introduced in 0.4.3. Explicit backend values are
  unchanged. Initial prefetch and page/foreground/interstitial recovery reloads still apply.
- Fix backend app volume being ignored: the publisher config's `gamConfig.appVolume` is now read
  (the SDK looked for `setAppVolume`, which the backend never sends, so ads always started muted).
  The legacy `setAppVolume` key is still accepted.

## 0.4.3

- Banner periodic refresh now counts only eligible time, preserving the remaining interval across
  visibility, attachment, app, page, cover and publisher holds. Loading time is excluded.
- Remote banners use backend `config.refreshTimeSeconds`, defaulting to 10 seconds when absent/null.
  Positive intervals are honored without the old Prebid clamp; 0 disables periodic refresh.
  Initial prefetch and explicit page/foreground/interstitial recovery are unchanged.

## 0.4.0 (unreleased) — breaking: interstitial formats and API frameworks are backend-controlled

- **Publisher key-values and the SDK's never clear each other.** Prebid iOS deletes every `hb_` key
  before bidding; the SDK now puts back everything it removed (a publisher's `hb_` keys too) except
  the bid keys Prebid set, on every original ad type (rewarded, native and multiformat included).
  Global targeting and the SDK's keys are applied to a copy per auction: the publisher's request is
  no longer modified, and global key-values added or removed later reach the next refresh (they
  were frozen at `createAd`).
- `prebidConfig.format` (`banner` / `video` / `bannerAndVideo`, default `bannerAndVideo`) and
  `prebidConfig.apis` (default `[3, 5, 6, 7]`) now decide what every interstitial requests.
  Validated, and resolved once per accepted load. See `docs/interstitial-capabilities.md`.
- **Removed:** `AUInterstitialView(configId:adFormats:)`, `(configId:adFormats:isLazyLoad:)` and
  `(configId:adFormats:isLazyLoad:minWidthPerc:minHeightPerc:)`. Use `(configId:)`,
  `(configId:isLazyLoad:)` and `(configId:isLazyLoad:minWidthPerc:minHeightPerc:)`.
- An interstitial's `bannerParameters.api`, `videoParameters.api` and `impOrtbConfig` `api` /
  format keys are ignored; their other settings are kept.
- Remote interstitials now always declare `banner.api` (they sent none) and request playable video
  parameters when video is asked for; their analytics subtype follows the requested format.

## Unreleased — breaking interstitial presentation change

**Before upgrading from 0.3.2: audit every `AURemoteConfigInterstitial.load()` call.**
Previously it only loaded inventory. It now presents immediately after a successful load by default,
matching the Android remote interstitial. A call made early to prefetch can therefore display an ad
at that earlier point. Invoke default `load()` only at a publisher-approved presentation opportunity.

To keep the previous load-then-show behavior, opt out **before** loading:

```swift
let ad = AURemoteConfigInterstitial(adConfigId: "placement")
ad.automaticallyShowOnLoad = false
ad.load { result in
    // Loading only. Handle result; call show(from:) at your chosen opportunity.
}
```

Alternatively, use `preload(completion:)`, which never auto-presents, followed by
`showAtOpportunity(from:eligible:)`. A missed opportunity is skipped, never replayed at load completion.
Do not combine these with a second load or a queued automatic show. Apply publisher frequency limits.

This default change applies to the native remote interstitial API. Flutter's explicit load/show
bridge and React Native's `manualControl` flow retain their own presentation contracts.

Remote interstitials now emit Audienzz bid request/response/outcome and Google impression/click events.
A Prebid bid win is an auction result, not proof of the final Google render winner. Render winner and
revenue fields remain absent without evidence. These events require normal Audienzz analytics setup;
they do not change GAM's Ad Exchange render-rate calculation.
