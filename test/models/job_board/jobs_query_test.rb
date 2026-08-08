# frozen_string_literal: true

require "test_helper"

module JobBoard
  class JobsQueryTest < ActiveSupport::TestCase
    test "each status pulls from its own execution table" do
      ready = create_ready_job
      scheduled = create_scheduled_job
      claimed = create_claimed_job
      blocked = create_blocked_job
      failed = create_failed_job
      finished = create_finished_job

      {
        "ready" => [ready, :ready], "scheduled" => [scheduled, :scheduled],
        "in_progress" => [claimed, :claimed], "blocked" => [blocked, :blocked],
        "failed" => [failed, :failed], "finished" => [finished, :finished]
      }.each do |status, (job, row_status)|
        rows = JobsQuery.new(status: status).page.to_a
        assert_equal [job.id], rows.map(&:id), "status #{status}"
        assert_equal row_status, rows.first.status
      end
    end

    test "queue filter works for execution-table and job-table backed statuses" do
      create_ready_job(queue: "a")
      create_ready_job(queue: "b")
      create_failed_job(queue: "a")
      create_failed_job(queue: "b")

      assert_equal 1, JobsQuery.new(status: "ready", queue_name: "a").page.to_a.size
      assert_equal 1, JobsQuery.new(status: "failed", queue_name: "b").page.to_a.size
      assert_equal 0, JobsQuery.new(status: "ready", queue_name: "missing").page.to_a.size
    end

    test "class filter joins to the jobs table" do
      create_ready_job(class_name: "SampleJob")
      create_ready_job(class_name: "FailingJob")

      rows = JobsQuery.new(status: "ready", class_name: "FailingJob").page.to_a

      assert_equal ["FailingJob"], rows.map(&:class_name)
    end

    test "counts returns one entry per status honoring filters" do
      create_ready_job(queue: "a")
      create_ready_job(queue: "b")
      create_failed_job(queue: "a")

      counts = JobsQuery.new(status: "ready", queue_name: "a").counts

      assert_equal 1, counts["ready"]
      assert_equal 1, counts["failed"]
      assert_equal 0, counts["finished"]
      assert_equal JobsQuery::STATUSES.sort, counts.keys.sort
    end

    test "rows expose status-specific fields" do
      process = create_process
      create_claimed_job(process: process)
      create_failed_job(error_class: "Net::ReadTimeout", message: "timed out")

      claimed_row = JobsQuery.new(status: "in_progress").page.to_a.first
      assert_equal process.id, claimed_row.process.id

      failed_row = JobsQuery.new(status: "failed").page.to_a.first
      assert_equal "Net::ReadTimeout", failed_row.error_class
      assert_equal "timed out", failed_row.error_message
    end

    test "failed_jobs_relation returns only failed jobs matching filters" do
      failed_a = create_failed_job(queue: "a")
      create_failed_job(queue: "b")
      create_ready_job(queue: "a")

      relation = JobsQuery.new(status: "failed", queue_name: "a").failed_jobs_relation

      assert_equal [failed_a.id], relation.pluck(:id)
    end

    test "rows are ordered newest first and paginate with before" do
      old = create_failed_job
      newer = create_failed_job

      page = JobsQuery.new(status: "failed").page(limit: 1)
      assert_equal [newer.id], page.to_a.map(&:id)
      assert page.more?

      older_page = JobsQuery.new(status: "failed").page(before: page.next_before, limit: 1)
      assert_equal [old.id], older_page.to_a.map(&:id)
    end
  end
end
