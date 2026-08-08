require "test_helper"

module JobBoard
  class MetricsControllerTest < ActionDispatch::IntegrationTest
    test "without a since it returns a baseline of zeros and a timestamp" do
      create_ready_job

      get "/job_board/metrics"

      assert_response :success
      body = response.parsed_body
      assert_equal 0, body["enqueued"]
      assert_equal 0, body["completed"]
      assert body["now"].present?
    end

    test "with a since it counts jobs that became ready and finished in the window" do
      create_ready_job(created_at: 2.seconds.ago)
      # Enqueued before the window, finished inside it — counts only as completed.
      strip_executions(create_job!(created_at: 30.seconds.ago, finished_at: 2.seconds.ago))

      get "/job_board/metrics", params: { since: 5.seconds.ago.iso8601(3) }

      assert_response :success
      body = response.parsed_body
      assert_equal 1, body["enqueued"]
      assert_equal 1, body["completed"]
    end

    test "a malformed since is treated as a fresh baseline" do
      create_ready_job(created_at: 2.seconds.ago)

      get "/job_board/metrics", params: { since: "not-a-timestamp" }

      assert_response :success
      assert_equal 0, response.parsed_body["enqueued"]
    end
  end
end
