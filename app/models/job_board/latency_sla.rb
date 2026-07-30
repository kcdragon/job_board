module JobBoard
  # Detects a queue's latency SLA from explicit configuration or from the
  # within_* naming convention (e.g. "within_5_minutes" => 300).
  module LatencySla
    UNITS = { "second" => 1, "minute" => 60, "hour" => 3600, "day" => 86400 }.freeze

    # Seconds, or nil when the queue has no detectable SLA.
    def self.detect(queue_name)
      JobBoard.config.latency_warning_thresholds[queue_name.to_s] || from_name(queue_name)
    end

    # The latency-warning threshold: the detected SLA, else the global default.
    def self.threshold_for(queue_name)
      detect(queue_name) || JobBoard.config.latency_warning_threshold
    end

    # Queues with a detectable SLA first, strictest first; the rest alphabetical.
    def self.sort(queues)
      queues.sort_by do |queue|
        sla = detect(queue.name)
        [sla ? 0 : 1, sla || 0, queue.name]
      end
    end

    def self.from_name(queue_name)
      match = /\Awithin_(\d+)_(second|minute|hour|day)s?\z/i.match(queue_name.to_s)
      match && match[1].to_i * UNITS.fetch(match[2].downcase)
    end
    private_class_method :from_name
  end
end
