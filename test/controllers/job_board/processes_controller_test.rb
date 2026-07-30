require "test_helper"

module JobBoard
  class ProcessesControllerTest < ActionDispatch::IntegrationTest
    test "index renders the process tree with metadata" do
      supervisor = create_process(kind: "Supervisor(fork)", hostname: "box-1")
      create_process(kind: "Worker", supervisor: supervisor,
                     metadata: { "queues" => "default,mailers", "thread_pool_size" => 3 })

      get "/job_board/processes"

      assert_response :success
      assert_match "Supervisor(fork)", response.body
      assert_match "box-1", response.body
      assert_match "default,mailers", response.body
    end

    test "index flags stale processes" do
      create_process(last_heartbeat_at: 30.minutes.ago)

      get "/job_board/processes"

      assert_response :success
      assert_match "stale", response.body
    end

    test "index warns about orphaned claimed executions" do
      create_orphaned_claimed_job

      get "/job_board/processes"

      assert_response :success
      assert_match "claimed by processes that no longer exist", response.body
    end

    test "index renders an empty state without processes" do
      get "/job_board/processes"

      assert_response :success
      assert_match "No processes registered", response.body
    end
  end
end
