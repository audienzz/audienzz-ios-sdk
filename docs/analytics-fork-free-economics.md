# Analytics economics with stock Prebid

The original GAM API in stock Prebid iOS returns a result and targeting, not the winning
`BidResponse` handle. We keep stock Prebid and omit unavailable metadata.

| Field | Current branch |
|---|---|
| `bidder_code` | `hb_bidder`; banner render attribution uses the GAM `Prebid` app event. |
| `price_bucket` | `hb_pb`, explicitly bucketed. |
| Exact bid `cpm` / `currency` | Absent on iOS original API. No assumed CHF or USD. |
| Render `cpm` / `currency` | Google paid-event value ×1,000 and its matching currency when available; `cpm_source=google_paid`. |
| `creative_id`, `ad_id` | Targeting metadata when actually supplied; otherwise absent, never `"0"`. |
| `auction_id` | SDK-generated for every accepted auction. |

Google's monetary value is per impression. Its currency must not be attached to a Prebid price
bucket. The callback can arrive after the impression callback; we do not manufacture another
impression or delay reporting while waiting. This is not a complete revenue ledger. Google paid
values can be estimates, depending on the SDK's reported precision.

A GAM response identifier is not a creative ID. Remote configuration describes placements, not
individual bids. Missing identifiers cannot be recovered from either of those sources.

Android can read its retained Prebid response and reports the actual winning price with `cur`
(`cpm_source=prebid_bid`). If it says USD while GAM reports CHF, preserve those source currencies;
reporting needs an explicit conversion rule, not a changed currency label.

The previous iOS implementation reported `hb_pb` as CPM, emitted zero placeholders, and could
combine it with Google's paid currency. This branch removes those misleading values. Exact iOS
Prebid economics can be added once the public original API exposes them.
