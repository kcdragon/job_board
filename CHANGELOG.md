# Changelog

## 0.1.0

Initial release.

- Queues overview with per-queue ready count, latency, failed count, and pause/resume.
- Latency-SLA aware: `within_*` queue names (e.g. `within_5_minutes`) set their own
  warning threshold and sort order; configurable per queue or globally.
- Jobs browsing by status (ready, scheduled, in progress, blocked, failed, finished)
  with queue/class filters, keyset pagination, and a job detail page.
- Failed job management: retry/discard individually or in bulk.
- Workers page: supervisor tree, heartbeat freshness, stale detection, orphaned-job warning.
- Recurring tasks page with last/next run times.
- Zero-dependency UI served by the engine itself, with polling auto-refresh.
- Optional HTTP Basic auth via `JobBoard.configure`.
