require "test_helper"

module JobBoard
  class JobPresenterTest < ActiveSupport::TestCase
    def presenter_for(job)
      JobPresenter.new(
        SolidQueue::Job
          .includes(:ready_execution, :scheduled_execution, :claimed_execution,
                    :blocked_execution, :failed_execution)
          .find(job.id)
      )
    end

    test "exposes the ActiveJob payload fields" do
      job = create_job!(arguments: [42, { "user_id" => 7 }])

      presenter = presenter_for(job)

      assert_equal [42, { "user_id" => 7 }], presenter.arguments
      assert_equal 0, presenter.executions_count
      assert presenter.enqueued_at.present?
    end

    test "handles a job with a blank payload" do
      job = create_ready_job
      job.update_columns(arguments: nil)

      presenter = presenter_for(job)

      assert_equal({}, presenter.payload)
      assert_nil presenter.arguments
    end

    test "exposes error details for failed jobs" do
      job = create_failed_job(error_class: "RuntimeError", message: "boom",
                              backtrace: ["line one", "line two"])

      presenter = presenter_for(job)

      assert_equal :failed, presenter.status
      assert_equal "RuntimeError", presenter.error.exception_class
      assert_equal "boom", presenter.error.message
      assert_equal ["line one", "line two"], presenter.error.backtrace
    end

    test "exposes the claiming process for in-progress jobs" do
      process = create_process
      job = create_claimed_job(process: process)

      presenter = presenter_for(job)

      assert_equal :claimed, presenter.status
      assert_equal process.id, presenter.process.id
    end

    test "scheduled_at prefers the scheduled execution" do
      job = create_scheduled_job(scheduled_at: 2.hours.from_now)

      presenter = presenter_for(job)

      assert_in_delta 2.hours.from_now.to_f, presenter.scheduled_at.to_f, 5
    end
  end
end
