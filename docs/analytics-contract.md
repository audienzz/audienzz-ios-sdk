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
25 events or after 5 seconds. Batches are capped at 128 KiB; one request runs at a time with at
least 2 seconds between starts. Failures remain durable and retry with jitter/Retry-After.
The 20 MiB store preserves existing events on overflow and retains rejected singletons in
quarantine. See the cross-platform contract above for retention, limits and required whole-batch
acknowledgement / event-ID deduplication on the collector. No Dart/JS queue changes are required.
