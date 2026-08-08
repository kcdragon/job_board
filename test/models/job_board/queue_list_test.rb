# frozen_string_literal: true

require "test_helper"

module JobBoard
  class QueueListTest < ActiveSupport::TestCase
    test "a nil window keeps every queue active" do
      create_ready_job(queue: "fresh")
      create_dormant_queue("stale", age: 90.days)

      list = QueueList.build(window: nil)

      assert_equal %w[fresh stale], list.active.map(&:name)
      assert_empty list.inactive
    end

    test "the window defaults to 30 days" do
      assert_equal 30.days, Configuration.new.queue_activity_window
    end

    test "queues idle longer than the window are inactive" do
      create_ready_job(queue: "fresh")
      create_dormant_queue("stale", age: 30.days)

      list = QueueList.build(window: 7.days)

      assert_equal %w[fresh], list.active.map(&:name)
      assert_equal %w[stale], list.inactive.map(&:name)
    end

    test "a queue active exactly at the window boundary stays active" do
      freeze_time do
        create_dormant_queue("boundary", age: 7.days)

        list = QueueList.build(window: 7.days)

        assert_equal %w[boundary], list.active.map(&:name)
      end
    end

    test "paused queues stay active no matter how idle" do
      create_dormant_queue("mothballed", age: 30.days)
      SolidQueue::Queue.find_by_name("mothballed").pause

      list = QueueList.build(window: 7.days)

      assert_equal %w[mothballed], list.active.map(&:name)
      assert_empty list.inactive
    end

    test "build defaults to the configured window" do
      original = JobBoard.config.queue_activity_window
      JobBoard.config.queue_activity_window = 7.days
      create_dormant_queue("stale", age: 10.days)

      assert_equal %w[stale], QueueList.build.inactive.map(&:name)
    ensure
      JobBoard.config.queue_activity_window = original
    end

    test "last_enqueued_at maps each queue to its newest job" do
      freeze_time do
        create_ready_job(queue: "reports", created_at: 2.hours.ago)
        create_ready_job(queue: "reports", created_at: 10.minutes.ago)

        list = QueueList.build

        assert_equal 10.minutes.ago, list.last_enqueued_at["reports"]
      end
    end

    test "SLA-then-alphabetical sort is preserved within each partition" do
      %w[reports alerts within_30_seconds].each { |q| create_ready_job(queue: q) }
      %w[old_reports old_alerts].each { |q| create_dormant_queue(q, age: 90.days) }

      list = QueueList.build(window: 7.days)

      assert_equal %w[within_30_seconds alerts reports], list.active.map(&:name)
      assert_equal %w[old_alerts old_reports], list.inactive.map(&:name)
    end

    private

    # A queue whose only trace is an old finished job.
    def create_dormant_queue(name, age:)
      strip_executions(create_job!(queue: name, created_at: age.ago, finished_at: age.ago))
    end
  end
end
