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
    end

    test "index renders an empty state without tasks" do
      get "/job_board/recurring_tasks"

      assert_response :success
      assert_match "No recurring tasks", response.body
    end
  end
end
