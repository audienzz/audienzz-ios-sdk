# Clickstream analytics contract

The cross-platform contract is maintained in
[audienzz-android-sdk/docs/analytics-contract.md](https://github.com/audienzz/audienzz-android-sdk/blob/feature/durable-analytics-batching/docs/analytics-contract.md).

Current branch additions: top-level `publisher_id`, `environment`, `os_version`; company/website
mapping moves to the collector; plain-decimal CPM with source-specific currency; unknown IDs
omitted; iOS impressions guarded per creative. Stock Prebid iOS cannot expose exact bid economics,
so those fields remain absent. Attribute values remain JSON strings.

New native SDK releases must ship before updating bridge pins. Dart/JS updates alone do not apply
native analytics fixes. See the contract for page-impression ownership, durable batched delivery,
legacy payload handling and outstanding client/backend checks.

Ad events retain the `page_impression_id` and screen name captured at request start. A new page
impression (including returning to a screen) creates a new ID; refreshes keep the current visit ID.
An interstitial prefetched on A and shown on B keeps A's ID throughout. Report the page before
loading ads; a request made before the first page report has no page ID. No manual ID propagation
is needed in Dart/JS. These guarantees require the matching native release.

The batching branch persists events immediately on the native utility worker, then POSTs at
the publisher's `analyticsBatchSize` or after 5 seconds. Missing, null, blank, invalid or nonpositive
values default to 10; positive integers are capped at 15. Numeric strings are tolerated. The field
is cached with publisher configuration and read before each send, including pending retries.
Batches are also capped at 128 KiB; one request runs at a time with at
least 2 seconds between starts. Failures remain durable and retry with jitter/Retry-After.
The 20 MiB store preserves existing events on overflow and retains rejected singletons in
quarantine. See the cross-platform contract above for retention, limits and required whole-batch
acknowledgement / event-ID deduplication on the collector. No Dart/JS queue is needed. Flutter
requires a small config-forwarding update because it fetches publisher config in Dart; RN uses
native remote initialization. Release the matching native SDKs before updating bridge pins.

September 29 lifecycle corrections on this branch:

- Banner measurement is cancelled on page release, destruction or a received replacement, and
  interrupted while hidden/backgrounded. A repeated callback for the same known Google response
  keeps the original measurement. Each replacement must earn its own success.
- Original fullscreen handlers retain the loaded ad's page/auction context. Remote interstitials
  now report viewability; rewarded viewability carries the same context as its impression.
- No-bid responses retain their auction ID; success without a bidder becomes `NO_BIDS`.
  First-load Google banner impressions report `slot_reload=0`.
- Repeated `viewability.start` after interrupted exposure is intentional; success is once per
  creative. Explicit same-screen page reports still create new visits; use one navigation owner.

`event_timestamp` remains the original creation time on disk recovery/retry. Old unsent events
are not expired or rewritten. Diagnostics show restored count and oldest event timestamp, and
send logs show the batch's oldest timestamp. Tests replay a September 25 payload unchanged and
verify that reopening the store after acknowledgement cannot resend it. Ambiguous delivery can
still repeat an event ID; collector deduplication is required. These changes do not establish the
cause of the historical September 25 traffic without sample payloads/event IDs.

Validation: 334 iOS and 306 Android tests pass. Reverting iOS fullscreen attribution to the mutable
owner, or removing the same-response load guard, fails the targeted regression tests; restoring
the fixes passes. See the [cross-platform review](https://github.com/audienzz/audienzz-android-sdk/blob/feature/durable-analytics-batching/docs/analytics-review-2026-09-29.md).
No live-device/collector validation was performed for these lifecycle fixes.
