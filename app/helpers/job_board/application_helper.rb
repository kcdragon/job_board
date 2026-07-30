module JobBoard
  module ApplicationHelper
    def status_badge(status)
      tag.span(status.to_s.humanize, class: "badge badge--#{status}")
    end

    def time_ago(time)
      return tag.span("–", class: "muted") if time.blank?

      time = Time.zone.parse(time) if time.is_a?(String)
      tag.time("#{duration((Time.current - time).abs)} #{time.future? ? "from now" : "ago"}",
        title: time.iso8601, datetime: time.iso8601)
    end

    def duration(seconds)
      seconds = seconds.to_i
      return "0s" if seconds <= 0

      parts = { "d" => 86400, "h" => 3600, "m" => 60, "s" => 1 }.filter_map do |unit, size|
        value, seconds = seconds.divmod(size)
        "#{value}#{unit}" if value.positive?
      end
      parts.first(2).join(" ")
    end

    # Latency (seconds) above which a queue counts as breaching. Resolution order:
    # explicit per-queue config, a threshold parsed from a within_* style name,
    # then the global default.
    def latency_threshold_for(queue_name)
      LatencySla.threshold_for(queue_name)
    end

    def format_json(value)
      value = JSON.parse(value) if value.is_a?(String)
      JSON.pretty_generate(value)
    rescue JSON::ParserError, JSON::GeneratorError
      value.to_s
    end
  end
end
