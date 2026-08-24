# Analytics economics — fork-free tradeoff

The SDK builds against **stock PrebidMobile** (no Audienzz Prebid fork). This keeps
SPM and CocoaPods on the public `prebid-mobile-ios` release and removes the fork as a
maintenance burden. The cost is that a few bid-economics fields on the analytics events
cannot be sourced accurately through the public Prebid **original API** and are reported
as stubs.

## What we report, and from where

| Field | Value shipped | Source (fork-free) |
|-------|---------------|--------------------|
| `bidder_code` | accurate | `hb_bidder` targeting keyword; `google` when the ad server rendered |
| `price_bucket` / `cpm` | **bucketed** (e.g. `1.42`) | `hb_pb` targeting keyword |
| `size` / `hb_size` | accurate | `hb_size` |
| `media_type` / `hb_format` | accurate | `hb_format` |
| `auction_id` | accurate | SDK-minted per auction |
| `currency` | `null` (backfilled from GMA paid event **if it fires**) | `GADAdValue.currencyCode` |
| `creative_id` | **`"0"`** | not available |
| `ad_id` | **`"0"`** | `hb_adid` when present, else `"0"` |

## Why `creative_id`, `ad_id`, currency, and exact `cpm` are not available

The real values (`crid`, `adid`, `cur`, exact `price`) exist only inside Prebid's parsed
`BidResponse`/`ORTBBid`. The **original API** path we use
(`AdUnit.fetchDemand(adObject:)`) builds that `BidResponse`, attaches the `hb_*` targeting
keywords to the GAM request, then **discards the handle** — it returns only a `ResultCode`
plus the targeting keywords. Stock `BidInfo`'s public surface is
`resultCode / targetingKeywords / exp / nativeAdCacheId / events`; it exposes no
`winningBid` and no `BidResponse`.

Sources checked and ruled out:

- **Targeting keywords** — carry `hb_bidder`, `hb_pb` (bucketed), `hb_size`, `hb_format`,
  `hb_partner`, `hb_cache_*`. No `crid`, no `*creative_id`, and (bidder-dependent) often no
  `hb_adid`. Verified on-device.
- **GAM** — `GADResponseInfo` exposes only an opaque `responseIdentifier`, an empty
  `extras`, and the mediation adapter name (`GADMAdapterGoogleAdMobAds`) + a `pubid`
  mapping. There is no served-creative-id API on iOS. Verified on-device.
- **Backend remote config** (`ws-sdk-config`) — publisher/ad-unit-level, 24h cached.
  `crid`/`adid` are per-impression auction-time values, so they cannot come from config.
- **Stock Prebid public API** — `BidResponse.winningBid.price` is public and exact, but the
  original API never returns a `BidResponse` handle, so it is unreachable on our path.
  `Bid.bid` (the `ORTBBid` holding `crid`/`adid`) is a Swift generic — not `@objc`/KVC —
  so the runtime-reflection trick used for `bidRequester` does not work here.

## The only clean way to get them

The Audienzz Prebid fork adds a `winningBid` economics accessor to `BidInfo` and a
`fetchDemand(adObject:completionBidInfo:)` overload, returning the `BidResponse` instead of
discarding it — giving exact `cpm`, `currency`, `creative_id`, and `ad_id`. The same change
has been proposed upstream to `prebid/prebid-mobile-ios`; if it lands in a stock release we
can populate these fields without any fork.

Until then, this build ships fork-free with the stubs above. Everything else in the
analytics funnel (event sequence, `auction_id` consistency, render-winner attribution,
bucketed cpm) is accurate.
