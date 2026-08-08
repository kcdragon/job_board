# frozen_string_literal: true

require "test_helper"

module JobBoard
  class JobsControllerTest < ActionDispatch::IntegrationTest
    test "index renders every status tab" do
      create_ready_job
      create_scheduled_job
      create_claimed_job
      create_blocked_job
      create_failed_job
      create_finished_job

      JobsQuery::STATUSES.each do |status|
        get "/job_board/jobs", params: { status: status }
        assert_response :success, "status #{status}"
        assert_match "SampleJob", response.body
      end
    end

    test "index rejects unknown statuses" do
      get "/job_board/jobs", params: { status: "nonsense" }
      assert_response :not_found
    end

    test "index filters by queue and class" do
      create_ready_job(queue: "a", class_name: "SampleJob")
      create_ready_job(queue: "b", class_name: "FailingJob")

      get "/job_board/jobs", params: { status: "ready", queue_name: "a" }

      assert_response :success
      assert_match "SampleJob", response.body
      assert_no_match(/FailingJob/, response.body)
    end

    test "index paginates with the before cursor" do
      jobs = 3.times.map { create_ready_job }
      JobBoard.config.per_page = 2

      get "/job_board/jobs", params: { status: "ready" }
      assert_match "Older", response.body

      get "/job_board/jobs", params: { status: "ready", before: jobs[0].ready_execution.id + 1 }
      assert_response :success
      assert_match "##{jobs[0].id}", response.body
    ensure
      JobBoard.config.per_page = 25
    end

    test "show renders job details" do
      job = create_ready_job

      get "/job_board/jobs/#{job.id}"

      assert_response :success
      assert_match job.active_job_id, response.body
    end

    test "show renders error details for a failed job" do
      job = create_failed_job(error_class: "Net::ReadTimeout", message: "it timed out",
                              backtrace: ["app/jobs/failing_job.rb:5"])

      get "/job_board/jobs/#{job.id}"

      assert_response :success
      assert_match "Net::ReadTimeout", response.body
      assert_match "it timed out", response.body
      assert_match "failing_job.rb:5", response.body
    end

    test "retry moves a failed job back to ready" do
      job = create_failed_job

      post "/job_board/jobs/#{job.id}/retry"

      assert_response :redirect
      job.reload
      assert_nil job.failed_execution
      assert job.ready_execution.present?
    end

    test "retry on a non-failed job is refused" do
      job = create_ready_job

      post "/job_board/jobs/#{job.id}/retry"

      assert_response :redirect
      assert_equal 1, SolidQueue::ReadyExecution.where(job_id: job.id).count
    end

    test "discard destroys a failed job entirely" do
      job = create_failed_job

      delete "/job_board/jobs/#{job.id}/discard"

      assert_response :redirect
      assert_not SolidQueue::Job.exists?(job.id)
      assert_not SolidQueue::FailedExecution.exists?(job_id: job.id)
    end

    test "discard on an in-progress job is refused" do
      job = create_claimed_job

      delete "/job_board/jobs/#{job.id}/discard"

      assert_response :redirect
      assert SolidQueue::Job.exists?(job.id)
      assert SolidQueue::ClaimedExecution.exists?(job_id: job.id)
    end

    test "retry_all retries only failed jobs matching the filters" do
      in_scope = create_failed_job(queue: "a")
      out_of_scope = create_failed_job(queue: "b")

      post "/job_board/jobs/retry_all", params: { queue_name: "a" }

      assert_response :redirect
      assert in_scope.reload.ready_execution.present?
      assert out_of_scope.reload.failed_execution.present?
    end

    test "discard_all discards only failed jobs matching the filters" do
      in_scope = create_failed_job(class_name: "FailingJob")
      out_of_scope = create_failed_job(class_name: "SampleJob")

      post "/job_board/jobs/discard_all", params: { class_name: "FailingJob" }

      assert_response :redirect
      assert_not SolidQueue::Job.exists?(in_scope.id)
      assert SolidQueue::Job.exists?(out_of_scope.id)
    end
  end
end
