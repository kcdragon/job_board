require "test_helper"

module JobBoard
  class LatencyThresholdTest < ActiveSupport::TestCase
    include JobBoard::ApplicationHelper

    teardown do
      JobBoard.config.latency_warning_thresholds = {}
      JobBoard.config.latency_warning_threshold = 60
    end

    test "within_* queue names carry their own threshold" do
      assert_equal 30, latency_threshold_for("within_30_seconds")
      assert_equal 300, latency_threshold_for("within_5_minutes")
      assert_equal 3600, latency_threshold_for("within_1_hour")
      assert_equal 86400, latency_threshold_for("within_24_hours")
      assert_equal 60, latency_threshold_for("within_1_minute")
    end

    test "other queue names fall back to the global default" do
      assert_equal 60, latency_threshold_for("default")
      assert_equal 60, latency_threshold_for("within_reason")

      JobBoard.config.latency_warning_threshold = 120
      assert_equal 120, latency_threshold_for("default")
    end

    test "explicit per-queue configuration beats the naming convention" do
      JobBoard.config.latency_warning_thresholds = { "within_1_hour" => 10 }

      assert_equal 10, latency_threshold_for("within_1_hour")
      assert_equal 300, latency_threshold_for("within_5_minutes")
    end

    test "sort puts detectable SLAs first, strictest first, then alphabetical" do
      queues = %w[zebra within_1_hour alpha within_30_seconds within_5_minutes]
        .map { |name| SolidQueue::Queue.new(name) }

      assert_equal %w[within_30_seconds within_5_minutes within_1_hour alpha zebra],
        LatencySla.sort(queues).map(&:name)
    end

    test "sort treats configured thresholds as detectable SLAs" do
      JobBoard.config.latency_warning_thresholds = { "critical" => 10 }
      queues = %w[alpha critical within_5_minutes].map { |name| SolidQueue::Queue.new(name) }

      assert_equal %w[critical within_5_minutes alpha], LatencySla.sort(queues).map(&:name)
    end

    test "sort breaks SLA ties alphabetically" do
      JobBoard.config.latency_warning_thresholds = { "b_queue" => 300, "a_queue" => 300 }
      queues = %w[b_queue within_5_minutes a_queue].map { |name| SolidQueue::Queue.new(name) }

      assert_equal %w[a_queue b_queue within_5_minutes], LatencySla.sort(queues).map(&:name)
    end
  end
end
