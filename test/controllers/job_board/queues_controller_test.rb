# frozen_string_literal: true

require "test_helper"

module JobBoard
  class QueuesControllerTest < ActionDispatch::IntegrationTest
    test "index lists queues with size, latency, and paused state" do
      freeze_time do
        3.times { create_ready_job(queue: "critical", created_at: 90.seconds.ago) }
        SolidQueue::Queue.find_by_name("critical").pause

        get "/job_board/queues"

        assert_response :success
        assert_match "critical", response.body
        assert_match 'title="90 seconds"', response.body
        assert_match "Paused", response.body
      end
    end

    test "index shows per-queue failed counts linking to the failed tab" do
      create_ready_job(queue: "critical")
      2.times { create_failed_job(queue: "critical") }

      get "/job_board/queues"

      assert_response :success
      assert_match %r{<a class="failed-count" href="[^"]*status=failed[^"]*">2</a>}, response.body
    end

    test "index sorts queues by SLA strictness, then alphabetically" do
      %w[reports within_1_hour within_30_seconds alerts].each { |q| create_ready_job(queue: q) }

      get "/job_board/queues"

      assert_response :success
      order = %w[within_30_seconds within_1_hour alerts reports]
              .map { |name| response.body.index(">#{name}</a>") }
      assert_equal order.sort, order, "queues out of expected order"
    end

    test "index shows when each queue last received a job" do
      freeze_time do
        create_ready_job(queue: "critical", created_at: 10.minutes.ago)

        get "/job_board/queues"

        assert_response :success
        assert_match "Last enqueued", response.body
        assert_match "10m ago", response.body
      end
    end

    test "index shows all queues in one table when the activity window is disabled" do
      original = JobBoard.config.queue_activity_window
      JobBoard.config.queue_activity_window = nil
      create_ready_job(queue: "busy")
      strip_executions(create_job!(queue: "dormant", created_at: 90.days.ago, finished_at: 90.days.ago))

      get "/job_board/queues"

      assert_response :success
      assert_no_match(/Inactive queues/, response.body)
      assert_match ">dormant</a>", response.body
    ensure
      JobBoard.config.queue_activity_window = original
    end

    test "index collapses queues idle beyond the default window into an inactive section" do
      create_ready_job(queue: "busy")
      strip_executions(create_job!(queue: "dormant", created_at: 90.days.ago, finished_at: 90.days.ago))

      get "/job_board/queues"

      assert_response :success
      assert_match "Inactive queues (1)", response.body
      assert response.body.index(">dormant</a>") > response.body.index("<details"),
             "dormant queue should be inside the inactive <details> section"
      assert response.body.index(">busy</a>") < response.body.index("<details"),
             "busy queue should stay in the active table"
    end

    test "index keeps paused idle queues in the active table" do
      create_ready_job(queue: "busy")
      strip_executions(create_job!(queue: "mothballed", created_at: 90.days.ago, finished_at: 90.days.ago))
      SolidQueue::Queue.find_by_name("mothballed").pause

      get "/job_board/queues"

      assert_response :success
      assert_no_match(/Inactive queues/, response.body)
      assert_match ">mothballed</a>", response.body
    end

    test "root shows the queues page" do
      get "/job_board"
      assert_response :success
      assert_match "Queues", response.body
    end

    test "pause creates a solid queue pause" do
      create_ready_job(queue: "default")

      post "/job_board/queues/default/pause"

      assert_redirected_to "/job_board/queues"
      assert SolidQueue::Queue.find_by_name("default").paused?
    end

    test "resume removes the pause" do
      SolidQueue::Queue.find_by_name("default").pause

      delete "/job_board/queues/default/pause"

      assert_redirected_to "/job_board/queues"
      assert_not SolidQueue::Queue.find_by_name("default").paused?
    end

    test "queue names with dots survive routing" do
      SolidQueue::Queue.find_by_name("mailers.high").pause
      delete "/job_board/queues/mailers.high/pause"

      assert_not SolidQueue::Queue.find_by_name("mailers.high").paused?
    end
  end
end
