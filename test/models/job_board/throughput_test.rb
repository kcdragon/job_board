# frozen_string_literal: true

require "test_helper"

module JobBoard
  class ThroughputTest < ActiveSupport::TestCase
    test "a nil since is a baseline with zero counts and a current timestamp" do
      create_ready_job
      create_finished_job

      snapshot = Throughput.snapshot(since: nil)

      assert_equal 0, snapshot[:enqueued]
      assert_equal 0, snapshot[:completed]
      assert snapshot[:now].present?
    end

    test "enqueued counts immediate jobs and scheduled jobs whose ready time is in the window" do
      freeze_time do
        create_ready_job(created_at: 3.seconds.ago) # immediate, ready now
        create_scheduled_job(scheduled_at: 2.seconds.ago)          # scheduled ready time in window
        create_scheduled_job(scheduled_at: 1.hour.from_now)        # not yet ready — excluded
        create_ready_job(created_at: 30.seconds.ago)               # ready before the window — excluded

        snapshot = Throughput.snapshot(since: 5.seconds.ago)

        assert_equal 2, snapshot[:enqueued]
      end
    end

    test "completed counts jobs finished within the window" do
      freeze_time do
        create_finished_job(finished_at: 2.seconds.ago)
        create_finished_job(finished_at: 10.seconds.ago)          # finished before the window — excluded

        snapshot = Throughput.snapshot(since: 5.seconds.ago)

        assert_equal 1, snapshot[:completed]
      end
    end

    test "the window is half-open: exclusive at since, inclusive at now" do
      freeze_time do
        create_ready_job(created_at: 5.seconds.ago)               # exactly at since — excluded
        create_ready_job(created_at: Time.current)                # exactly at now — included

        snapshot = Throughput.snapshot(since: 5.seconds.ago)

        assert_equal 1, snapshot[:enqueued]
      end
    end
  end
end
