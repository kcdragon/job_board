# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
bundle exec rake test                                        # full suite
bundle exec rake test TEST=test/models/job_board/page_test.rb  # one file
bundle exec ruby -Itest test/models/job_board/page_test.rb -n /keyset/  # one test by name

bundle exec rubocop        # lint (run after implementing a plan); rubocop -a to autocorrect

# Demo app with seeded data (http://localhost:3000/job_board):
cd test/dummy && bin/rails db:prepare db:seed && bin/rails server

gem build job_board.gemspec   # package; the maintainer runs `gem push` himself — never publish
```

**Always run `bundle exec rubocop` after implementing a plan** and fix what it flags
(`rubocop -a` autocorrects the safe ones) so changes land clean. Config is `.rubocop.yml`,
inheriting `rubocop-rails-omakase` with a few house overrides: methods after `private` are
**not** extra-indented (`Layout/IndentationConsistency: normal`) but do get a blank line after
the modifier (`Layout/EmptyLinesAroundAccessModifier: around`), and array literals use no
inner spaces.

## What this is

A mountable Rails engine gem (`isolate_namespace JobBoard`) providing a monitoring dashboard
for Solid Queue. Published to rubygems as `job_board`; repo is github.com/kcdragon/job_board.
Runtime dependencies are only `rails >= 7.1` and `solid_queue >= 1.1` — both version floors are
load-bearing (`SolidQueue::Queue#latency` appeared in 1.1.0; `Data.define` in ProcessTree needs
Ruby >= 3.2).

## Architecture

**No ActiveRecord models of its own.** The engine reads and writes exclusively through
`SolidQueue::*` models, so hosts with a separate queue database work for free. Everything in
`app/models/job_board/` is a PORO:

- `JobsQuery` — each status tab is driven by its own execution table (`ReadyExecution`,
  `ScheduledExecution`, `ClaimedExecution`, `BlockedExecution`, `FailedExecution`; finished =
  `Job.finished`), never by `Job#status` (which fires up to 5 queries per job). Status is known
  per tab, so there are zero N+1s by construction.
- `Page` — hand-rolled keyset pagination: `id DESC`, `?before=<id>` cursor, fetch limit+1.
- `LatencySla` — parses latency SLAs from Gusto-style `within_N_units` queue names; drives both
  the red-latency threshold and queue sort order (strictest SLA first, then alphabetical).
- `QueueList` — partitions queues into active/inactive by newest job age vs
  `config.queue_activity_window` (default 30 days). Paused queues always count as active.
- `ProcessTree`, `JobRow`, `JobPresenter` — supervisor tree, uniform index-row facade,
  detail-page wrapper.

**Zero-dependency UI.** The engine serves its own CSS/JS through an allowlisted
`AssetsController` with a 1-year cache keyed on `?v=#{JobBoard::VERSION}` — bumping the version
is what busts browser caches (hard-refresh during development). Auto-refresh is vanilla JS that
re-fetches the page and swaps `[data-poll-region]` innerHTML; it skips hidden tabs (this looks
like a broken poller when testing in an occluded automation browser — it isn't), skips paginated
pages, and preserves `details[data-persist]` open state across swaps. `button_to` +
a delegated `data-confirm` handler replace Turbo/UJS.

**Configuration** is a singleton (`JobBoard.config` / `JobBoard.configure`). Tests that mutate
it must capture the original value and restore it in `ensure` — defaults are not `nil` for
every option.

## Hard-won constraints (violating these breaks hosts or tests)

- Assets MUST live in `lib/job_board/assets/`, not `app/assets/` — engines auto-append
  `app/assets/*` to the host's asset pipeline paths, and a logical `application.css` collides
  with the host's own in propshaft apps, breaking their `assets:precompile`.
- `SolidQueue::Job.create!` auto-creates a ready or scheduled execution via `after_create`.
  Seeds and test factories must backdate that execution (`update_columns(created_at:)`) or
  `strip_executions(job)` before attaching a different execution type. Creating a job with a
  `concurrency_key` also auto-acquires its Semaphore.
- `ClaimedExecution#discard` raises `UndiscardableError` — controllers guard so in-progress
  jobs are never offered discard.
- `SolidQueue::Job.scheduled` is misleading (`where(finished_at: nil)`); query
  `ScheduledExecution` directly.
- ERB: text nodes between `<% case %>` and the first `<% when %>` are a syntax error — use
  if/elsif chains in views.
- `lib/` is not reloaded by the dummy dev server; restart it after changing anything there.
- Queue names containing `/` can't be paused through the UI (route constraint limitation),
  and `SolidQueue::Queue.all` is a DISTINCT over the whole jobs table (accepted v1 scale risk).

## Testing setup

Minitest + a full Rails app in `test/dummy` (sqlite3). `test_helper.rb` boots the dummy env and
loads `test/dummy/db/schema.rb` — a verbatim copy of solid_queue's `queue_schema.rb` template.
`test/support/solid_queue_fixtures.rb` provides factories (`create_ready_job`,
`create_failed_job`, `create_process`, …) that create Solid Queue rows directly — no workers
run during tests. `test/dummy/db/seeds.rb` builds a realistic demo dataset, including queues
that breach their SLA and long-dead queues for the inactive section.

## Releasing

Bump `lib/job_board/version.rb` (this also cache-busts assets), add a CHANGELOG entry,
`gem build job_board.gemspec`. The maintainer pushes the gem and expects to do so himself.

If the change has a UI component, include a screenshot in the CHANGELOG entry —
capture it yourself, do not ask the maintainer for one. Commit the PNG under `doc/`
with the version in its filename (e.g. `doc/throughput-0.4.0.png`) and reference it
with a repo-relative path (`![...](doc/throughput-0.4.0.png)`); the
CHANGELOG renders on GitHub, where that resolves. `doc/` is intentionally outside the
gemspec `files` glob, so images ship on GitHub but don't bloat the packaged gem. To
capture: boot the demo app (`cd test/dummy && bin/rails db:prepare db:seed &&
bin/rails server`) and screenshot the relevant view with headless Chrome via Playwright
(`channel: "chrome"` reuses the installed browser — no Chromium download). For a
live/polling widget, drive real activity while the page is open (e.g. a `bin/rails
runner` loop inserting `SolidQueue::Job` rows) so the capture shows data, not an empty
"collecting…" state.
