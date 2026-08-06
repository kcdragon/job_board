# Job Board

A mountable Rails engine that gives you a dashboard for [Solid Queue](https://github.com/rails/solid_queue):
queue latency at a glance, jobs by status, failed-job management, worker health, and recurring tasks.

## Features

- **Queues** — every queue with its ready-job count, **current latency** (how long the oldest
  ready job has been waiting), and pause/resume controls.
- **Jobs** — browse by status (ready, scheduled, in progress, blocked, failed, finished) with
  queue and class filters, keyset pagination that stays fast on huge tables, and a detail page
  showing arguments, timestamps, and the full error with backtrace.
- **Failed job management** — retry or discard individual jobs, or all failed jobs matching the
  current filters (batched, safe for large sets).
- **Workers** — the supervisor → worker/dispatcher/scheduler tree with heartbeat freshness,
  stale-process badges, per-worker in-progress jobs, and a warning when claimed jobs have been
  orphaned by a dead process.
- **Recurring tasks** — each task's cron schedule (hover for a plain-English description),
  last run, and next run, sorted soonest-first, with a **Run now** button to trigger any
  task outside its schedule.
- **Zero dependencies** — the engine serves its own CSS and ~40 lines of vanilla JS. No
  importmap, sprockets, propshaft, or Node requirement. Pages auto-refresh every few seconds.

## Installation

Add the gem:

```ruby
gem "job_board"
```

Mount the engine:

```ruby
# config/routes.rb
mount JobBoard::Engine => "/job_board"
```

That's it — visit `/job_board`.

## Authentication

The dashboard ships with no forced authentication. Two options:

**Constraint-based mounting** (recommended when you have app auth, e.g. Devise):

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount JobBoard::Engine => "/job_board"
end
```

**Built-in HTTP Basic auth:**

```ruby
# config/initializers/job_board.rb
JobBoard.configure do |config|
  config.http_basic_auth = {
    name: Rails.application.credentials.dig(:job_board, :user),
    password: Rails.application.credentials.dig(:job_board, :password)
  }
end
```

## Configuration

```ruby
JobBoard.configure do |config|
  config.poll_interval = 5              # seconds between auto-refreshes; nil or 0 disables
  config.per_page = 25                  # rows per page on job lists
  config.stale_process_threshold = nil  # heartbeat age before a process is flagged stale;
                                        # nil uses SolidQueue.process_alive_threshold (5 min)
  config.http_basic_auth = nil          # see Authentication above
  config.queue_activity_window = 30.days # collapse queues with nothing enqueued in
                                         # that window into "Inactive queues";
                                         # nil shows everything in one table

  # Latency (seconds) above which a queue is highlighted as breaching:
  config.latency_warning_threshold = 60                      # global default
  config.latency_warning_thresholds = { "critical" => 10 }   # per-queue overrides
end
```

### Latency-SLA queue names

If you name queues after their latency target — the `within_*` convention from
[Gusto's Sidekiq scaling write-up](https://engineering.gusto.com/scaling-sidekiq-at-gusto-3f9e3279e63) —
Job Board parses the threshold straight from the name, no configuration needed:

| Queue | Highlighted red when latency exceeds |
|---|---|
| `within_30_seconds` | 30 seconds |
| `within_5_minutes` | 5 minutes |
| `within_1_hour` | 1 hour |
| `within_24_hours` | 24 hours |

Explicit `latency_warning_thresholds` entries still win over the naming convention.

The queues page also sorts by SLA: queues with a detectable latency target come first
(strictest at the top), and everything else follows alphabetically.

### Hiding inactive queues

Because Solid Queue derives the queue list from the jobs table, a queue keeps showing
up as long as *any* job row with its name exists — including queues you retired long
ago. Each queue's **Last enqueued** column shows when it last received a job, and
queues with nothing enqueued in the last **30 days** (configurable) collapse into a
one-click **Inactive queues** section at the bottom of the page — out of the way but
never invisible, since a quiet queue can be a symptom rather than noise. Paused
queues always stay in the main table regardless of idleness, because a pause is
deliberate state someone needs to see.

```ruby
JobBoard.configure do |config|
  config.queue_activity_window = 7.days # tighter window
  # or nil to always show every queue in one table
end
```

Also worth knowing: if the lingering rows are preserved finished jobs, Solid Queue's
dispatcher normally clears them after `SolidQueue.clear_finished_jobs_after` (default
1 day) — stale names often mean that cleanup isn't running, or that old failed jobs
are still waiting to be retried or discarded. Dealing with those makes retired queues
disappear entirely.

## Notes

- **Separate queue database**: works automatically. Job Board reads and writes exclusively
  through the `SolidQueue::*` models, which connect to whatever database
  `config.solid_queue.connects_to` points at.
- **Latency** is computed the same way Solid Queue itself defines it: seconds since the oldest
  ready execution in the queue was enqueued (0 for an empty queue). Scheduled and failed jobs
  don't count against latency.
- **`preserve_finished_jobs = false`** hosts will see an explanatory empty state on the
  Finished tab, since finished jobs are deleted immediately.
- **Discarding is permanent** — Solid Queue deletes the job row entirely; there is no trash.
  In-progress jobs can't be discarded.
- Queue names containing `/` can't be paused through the UI (route limitation).

## Development

```sh
bundle install
bundle exec rake test

# Run the demo app with seeded data:
cd test/dummy
bin/rails db:prepare db:seed
bin/rails server
# open http://localhost:3000/job_board

# Optionally start real workers against the seeded jobs:
bin/rails solid_queue:start
```

## License

MIT.
