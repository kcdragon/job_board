# frozen_string_literal: true

require "test_helper"

module JobBoard
  class RecurringTasksControllerTest < ActionDispatch::IntegrationTest
    test "index lists recurring tasks with schedule and next run" do
      create_recurring_task(key: "nightly_cleanup", schedule: "0 3 * * *",
                            class_name: "SampleJob", queue_name: "maintenance")

      get "/job_board/recurring_tasks"

      assert_response :success
      assert_match "nightly_cleanup", response.body
      assert_match "0 3 * * *", response.body
      assert_match "maintenance", response.body
      assert_match "from now", response.body
      assert_match 'title="Every day at 03:00"', response.body
    end

    test "index renders an empty state without tasks" do
      get "/job_board/recurring_tasks"

      assert_response :success
      assert_match "No recurring tasks", response.body
    end

    test "index sorts tasks by next run time, soonest first" do
      create_recurring_task(key: "a_yearly", schedule: "0 0 1 1 *")
      create_recurring_task(key: "m_hourly", schedule: "0 * * * *")
      create_recurring_task(key: "z_minutely", schedule: "* * * * *")

      get "/job_board/recurring_tasks"

      assert_response :success
      order = %w[z_minutely m_hourly a_yearly].map { |key| response.body.index(key) }
      assert_equal order.sort, order, "tasks out of expected next-run order"
    end

    test "run enqueues the task's job immediately and records the run" do
      create_recurring_task(key: "nightly_cleanup", schedule: "0 3 * * *", class_name: "SampleJob")

      post "/job_board/recurring_tasks/nightly_cleanup/run"

      assert_redirected_to "/job_board/recurring_tasks"
      job = SolidQueue::Job.last
      assert_equal "SampleJob", job.class_name
      assert job.ready_execution.present?, "job should be ready to run now"
      assert_equal "nightly_cleanup", SolidQueue::RecurringExecution.last.task_key
      follow_redirect!
      assert_match "Enqueued &quot;nightly_cleanup&quot;", response.body
    end

    test "run shows an alert when the task no longer exists" do
      post "/job_board/recurring_tasks/deleted_task/run"

      assert_redirected_to "/job_board/recurring_tasks"
      follow_redirect!
      assert_match "no longer exists", response.body
      assert_equal 0, SolidQueue::Job.count
    end

    test "running twice at the same instant enqueues only once" do
      create_recurring_task(key: "nightly_cleanup", schedule: "0 3 * * *", class_name: "SampleJob")

      freeze_time do
        post "/job_board/recurring_tasks/nightly_cleanup/run"
        post "/job_board/recurring_tasks/nightly_cleanup/run"
      end

      assert_equal 1, SolidQueue::Job.count
      follow_redirect!
      assert_match "was not enqueued", response.body
    end

    test "task keys with dots survive routing" do
      create_recurring_task(key: "cleanup.daily", schedule: "0 3 * * *", class_name: "SampleJob")

      post "/job_board/recurring_tasks/cleanup.daily/run"

      assert_redirected_to "/job_board/recurring_tasks"
      assert_equal 1, SolidQueue::Job.count
    end
  end
end
