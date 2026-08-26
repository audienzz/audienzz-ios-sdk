# Audienzz Analytics — Event Samples

One representative payload per event type, captured from the iOS DemoSwiftApp
(SDK `0.2.5`, `dev-analytics`, banner on `RemoteConfigViewController`).

Each event is a flat JSON object POSTed individually to
`https://api.adnz.co/api/ws-clickstream-collector/submit/batch`.

**Event flow per screen visit:**
`pageImpression` → `bidRequest` → `bidResponse` → (`bidWon` | `noBid`) →
`adImpression` → `viewability.start` → `viewability.success` (+ `adClick` on tap).

> `noBid` is not shown below — it did not fire in this capture (every auction won).
> Its shape matches `bidRequest` plus `result_code: "NO_BIDS"` and no economics.

---

## 1. pageImpression

Fires once per screen visit (`onScreenResumed`). Groups all following events via `page_impression_id`.

```json
{
  "event_type": "pageImpression",
  "attributes": {
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "c7d05c33-f3ed-4d95-bf68-43a1241fb2f9",
  "event_timestamp": "2026-07-13T11:43:07.383Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 0,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## 2. bidRequest

Fires when the ad unit starts a Prebid auction (`fetchDemand`).

```json
{
  "event_type": "bidRequest",
  "attributes": {
    "ad_subtype": "HTML",
    "ad_type": "BANNER",
    "ad_unit_code": "wuobgeuc",
    "ad_unit_id": "/96628199/de_audienzz.ch_v2/multi-size",
    "api_type": "ORIGINAL",
    "autorefresh": "false",
    "autorefresh_time": "0",
    "media_types": "[\"banner\"]",
    "refresh": "false",
    "sizes": "300x250",
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "71823d43-79b2-4bfd-8ac6-e1573948feb7",
  "event_timestamp": "2026-07-13T11:43:07.524Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 1,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## 3. bidResponse

Fires when the auction resolves with a winning bid (`result_code: "SUCCESS"`).
Carries full economics. (A no-bid routes to `noBid` with `result_code: "NO_BIDS"` and no economics.)

```json
{
  "event_type": "bidResponse",
  "attributes": {
    "ad_subtype": "HTML",
    "ad_type": "BANNER",
    "ad_unit_code": "wuobgeuc",
    "ad_unit_id": "/96628199/de_audienzz.ch_v2/multi-size",
    "api_type": "ORIGINAL",
    "auction_id": "0BFE4C82-2CF6-40C6-BAA9-6A6FC09F45C7",
    "autorefresh": "false",
    "autorefresh_time": "0",
    "bidder_code": "test",
    "cpm": "1.425",
    "creative_id": "123456789",
    "currency": "USD",
    "hb_format": "banner",
    "hb_size": "300x250",
    "media_type": "banner",
    "price_bucket": "1.42",
    "refresh": "false",
    "result_code": "SUCCESS",
    "size": "300x250",
    "sizes": "300x250",
    "slot_reload": "0",
    "time_to_respond": "220",
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "68d5e4f2-5327-4800-a734-0a5cc8c1776c",
  "event_timestamp": "2026-07-13T11:43:07.744Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 3,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## 4. bidWon

Fires only when the Prebid auction is won (`hb_bidder` present). Same economics as `bidResponse`.

```json
{
  "event_type": "bidWon",
  "attributes": {
    "ad_subtype": "HTML",
    "ad_type": "BANNER",
    "ad_unit_code": "wuobgeuc",
    "ad_unit_id": "/96628199/de_audienzz.ch_v2/multi-size",
    "api_type": "ORIGINAL",
    "auction_id": "0BFE4C82-2CF6-40C6-BAA9-6A6FC09F45C7",
    "autorefresh": "false",
    "autorefresh_time": "0",
    "bidder_code": "test",
    "cpm": "1.425",
    "creative_id": "123456789",
    "currency": "USD",
    "hb_format": "banner",
    "hb_size": "300x250",
    "media_type": "banner",
    "price_bucket": "1.42",
    "refresh": "false",
    "size": "300x250",
    "sizes": "300x250",
    "slot_reload": "0",
    "time_to_respond": "220",
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "c41fa1d3-de49-4997-ba02-8be5d1ab27b5",
  "event_timestamp": "2026-07-13T11:43:07.872Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 4,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## 5. adImpression

Fires when GAM records the impression. `bidder_code` reflects the actual render winner
(`google` = ad server rendered; a Prebid bidder = its line item rendered).

```json
{
  "event_type": "adImpression",
  "attributes": {
    "ad_subtype": "HTML",
    "ad_type": "BANNER",
    "ad_unit_code": "wuobgeuc",
    "ad_unit_id": "/96628199/de_audienzz.ch_v2/multi-size",
    "api_type": "ORIGINAL",
    "auction_id": "0BFE4C82-2CF6-40C6-BAA9-6A6FC09F45C7",
    "bidder_code": "google",
    "cpm": "1.425",
    "creative_id": "123456789",
    "currency": "USD",
    "hb_format": "banner",
    "hb_size": "300x250",
    "media_type": "banner",
    "price_bucket": "1.42",
    "size": "300x250",
    "slot_reload": "0",
    "time_to_respond": "220",
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "73e92dc2-6e91-4f67-8446-7d9bd816d047",
  "event_timestamp": "2026-07-13T11:43:09.086Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 7,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## 6. viewability.start

Fires when the creative first crosses ≥50% visible. Adds `tracker_version`.
`bidder_code` matches `adImpression` (same render winner).

```json
{
  "event_type": "viewability.start",
  "attributes": {
    "ad_subtype": "HTML",
    "ad_type": "BANNER",
    "ad_unit_code": "wuobgeuc",
    "ad_unit_id": "/96628199/de_audienzz.ch_v2/multi-size",
    "api_type": "ORIGINAL",
    "auction_id": "0BFE4C82-2CF6-40C6-BAA9-6A6FC09F45C7",
    "bidder_code": "google",
    "cpm": "1.425",
    "creative_id": "123456789",
    "currency": "USD",
    "hb_format": "banner",
    "hb_size": "300x250",
    "media_type": "banner",
    "price_bucket": "1.42",
    "size": "300x250",
    "slot_reload": "0",
    "time_to_respond": "220",
    "tracker_version": "1.0.0",
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "8b5570ac-cbb8-4683-9ae4-96893af2b654",
  "event_timestamp": "2026-07-13T11:43:09.093Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 8,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## 7. viewability.success

Fires once after ≥50% visible for 1 continuous second (terminal per creative).

```json
{
  "event_type": "viewability.success",
  "attributes": {
    "ad_subtype": "HTML",
    "ad_type": "BANNER",
    "ad_unit_code": "wuobgeuc",
    "ad_unit_id": "/96628199/de_audienzz.ch_v2/multi-size",
    "api_type": "ORIGINAL",
    "auction_id": "0BFE4C82-2CF6-40C6-BAA9-6A6FC09F45C7",
    "bidder_code": "google",
    "cpm": "1.425",
    "creative_id": "123456789",
    "currency": "USD",
    "hb_format": "banner",
    "hb_size": "300x250",
    "media_type": "banner",
    "price_bucket": "1.42",
    "size": "300x250",
    "slot_reload": "0",
    "time_to_respond": "220",
    "tracker_version": "1.0.0",
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "515d578b-5e20-417a-a7c5-c7bb71d2b3b4",
  "event_timestamp": "2026-07-13T11:43:10.131Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 9,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## 8. adClick

Fires on user tap. Same `attributes` as `adImpression` (render-winner `bidder_code` + economics).

```json
{
  "event_type": "adClick",
  "attributes": {
    "ad_subtype": "HTML",
    "ad_type": "BANNER",
    "ad_unit_code": "wuobgeuc",
    "ad_unit_id": "/96628199/de_audienzz.ch_v2/multi-size",
    "api_type": "ORIGINAL",
    "auction_id": "0BFE4C82-2CF6-40C6-BAA9-6A6FC09F45C7",
    "bidder_code": "google",
    "cpm": "1.425",
    "creative_id": "123456789",
    "currency": "USD",
    "hb_format": "banner",
    "hb_size": "300x250",
    "media_type": "banner",
    "price_bucket": "1.42",
    "size": "300x250",
    "slot_reload": "0",
    "time_to_respond": "220",
    "transport": "xhr",
    "website_id": "35"
  },
  "app_package_name": "ch.audienzzios.DemoSwiftApp1",
  "app_title": "DemoSwiftApp",
  "app_version": "1.0",
  "browser_name": "WKWebView",
  "company_id": "1",
  "device_category": "Smartphone",
  "device_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "36d98662-537f-4466-9a70-8324810b694b",
  "event_timestamp": "2026-07-13T11:47:51.821Z",
  "locale": "en-UA",
  "os_name": "iOS",
  "page_impression_id": "c84df571-169d-4dea-b3ad-ae52b74dc895",
  "screen_height": 874,
  "screen_name": "RemoteConfigViewController",
  "screen_width": 402,
  "sdk_name": "ios",
  "sdk_version": "0.2.5",
  "session_id": "381377ba-5392-4f1c-b9ea-5b66681bb0f5",
  "session_seq": 58,
  "session_start_timestamp": 1783942975510,
  "source": "ios-sdk",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  "viewport_height": 874,
  "viewport_width": 402,
  "visitor_id": "7a822d13-2f8b-420f-a882-94798ec68052",
  "zone_offset_seconds": 10800
}
```

---

## Not captured in this run

- **noBid** — fires instead of `bidResponse`+`bidWon` when the auction returns no
  usable bid. Same envelope + `attributes` as `bidRequest`, plus `result_code: "NO_BIDS"`;
  no economics (`cpm`/`currency`/`creative_id`/`auction_id`).
