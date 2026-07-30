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
      @latency_warning_threshold = 60
      @latency_warning_thresholds = {}
    end
  end
end
