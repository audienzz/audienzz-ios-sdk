# Changelog

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
