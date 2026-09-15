# Changelog

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
