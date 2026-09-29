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

The batching branch persists events immediately on the native utility worker, then groups by
`attributes.auction_id`. Each group sends after two seconds without another new event for that
auction, or upon reaching the publisher's `analyticsBatchSize`. Missing, null, blank, invalid or nonpositive
values default to 10; positive integers are capped at 15. Numeric strings are tolerated. The field
is cached with publisher configuration and read before each send, including pending retries.
Batches are also capped at 128 KiB; one request runs at a time with at
least 2 seconds between starts. Failures remain durable and retry with jitter/Retry-After.
Every POST contains one auction's events. Missing/blank auction IDs, including page impressions,
use a separate debounced bucket. Other auctions cannot extend a group's debounce. Late events
start a new window, and new events are never appended to an existing retry attempt. Background
flushes and restart recovery make only already-queued events due early; foreground/connectivity
do not bypass debounce. Due restored/fresh groups alternate, selecting the oldest due auction
within each lane. Even matching auction IDs stay in separate restored/fresh groups so a large
backlog cannot bury newly generated events. Failed HTTP plans retain priority and backoff;
pacing, in-flight HTTP and backoff can delay the POST.
The 20 MiB pending-delivery quota preserves already owed events on overflow. Quarantined
rejections use a separate diagnostic budget of 100 events / 1 MiB; older/oversized rejected
payloads are durably discarded, never counted as delivered. No pending deliverable event is
pruned. Known HTTP successes with a failed local acknowledgement retry only the disk write
with 2/4/8/16/32/60-second capped backoff; other persisted events may proceed. Those accepted
IDs remain durable until local acknowledgement, so a process restart can still replay them.
See the cross-platform contract above for retention, limits and required whole-batch
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

Producer/lifecycle baseline: 334 iOS and 306 Android tests passed. Reverting iOS fullscreen attribution to the mutable
owner, or removing the same-response load guard, fails the targeted regression tests; restoring
the fixes passes. See the [cross-platform review](https://github.com/audienzz/audienzz-android-sdk/blob/feature/durable-analytics-batching/docs/analytics-review-2026-09-29.md).
No live-device/collector validation was performed for these lifecycle fixes.

Auction-debounce baseline: the full suites passed with 342 iOS / 314 Android tests. Tests
cover independent auction deadlines, late arrivals during HTTP, the no-auction bucket, cap
accounting, fair selection, durable recovery and retry isolation. Removing grouping/latest-arrival
debounce fails the corresponding regressions.

The follow-up review adds the missing flush-spacing regression, tests fairness with 60 restored
auctions and with new events in the same restored auction, and exercises persistent local
acknowledgement failure plus replay after process death. Real-file tests verify separate
quarantine capacity and bounded retention across reopen/compaction. Deliberately reverting
flush filtering, fairness, local-only acknowledgement retry, or quarantine limits fails their
corresponding tests on both platforms. Foreground/page-impression semantics are unchanged.

Final follow-up full suites: **349 iOS / 321 Android tests passed**, zero failures, after restoring
all mutation probes. Native versions and bridge code are unchanged; no live-device/collector
validation was performed for this follow-up.
