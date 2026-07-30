require "test_helper"

module JobBoard
  class QueueLatencyTest < ActiveSupport::TestCase
    test "latency is seconds since the oldest ready execution was enqueued" do
      freeze_time do
        create_ready_job(queue: "critical", created_at: 2.minutes.ago)
        create_ready_job(queue: "critical", created_at: 30.seconds.ago)

        assert_equal 120, SolidQueue::Queue.new("critical").latency
      end
    end

    test "latency is zero for an empty queue" do
      assert_equal 0, SolidQueue::Queue.new("empty").latency
    end

    test "latency only considers the queue's own ready executions" do
      freeze_time do
        create_ready_job(queue: "slow", created_at: 1.hour.ago)
        create_ready_job(queue: "fast", created_at: 5.seconds.ago)

        assert_equal 5, SolidQueue::Queue.new("fast").latency
      end
    end

    test "scheduled and failed jobs do not affect latency" do
      freeze_time do
        create_scheduled_job(queue: "q", scheduled_at: 1.hour.from_now)
        create_failed_job(queue: "q")

        assert_equal 0, SolidQueue::Queue.new("q").latency
      end
    end
  end
end
