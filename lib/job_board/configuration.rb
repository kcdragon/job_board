# frozen_string_literal: true

module JobBoard
  class Configuration
    # nil, or { name: "...", password: "..." } to protect the UI with HTTP Basic auth.
    attr_accessor :http_basic_auth

    # Seconds between page auto-refreshes. nil or 0 disables polling.
    attr_accessor :poll_interval

    # Rows per page on job lists.
    attr_accessor :per_page

    # Heartbeat age after which a process is flagged stale.
    # nil falls back to SolidQueue.process_alive_threshold.
    attr_accessor :stale_process_threshold

    # Queues with no job enqueued inside this window (seconds or an
    # ActiveSupport::Duration) are collapsed into an "Inactive queues"
    # section on the queues page. Paused queues always stay visible.
    # nil shows every queue in one table.
    attr_accessor :queue_activity_window

    # Seconds of latency after which a queue is highlighted as breaching.
    # Per-queue override: latency_warning_thresholds["queue_name"] = seconds.
    # Queues named in the within_* convention (e.g. "within_5_minutes") get
    # their threshold parsed from the name automatically.
    attr_accessor :latency_warning_threshold
    attr_accessor :latency_warning_thresholds

    def initialize
      @http_basic_auth = nil
      @poll_interval = 5
      @per_page = 25
      @stale_process_threshold = nil
      @queue_activity_window = 30.days
      @latency_warning_threshold = 60
      @latency_warning_thresholds = {}
    end
  end
end
