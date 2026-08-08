require "test_helper"

module JobBoard
  class AssetsControllerTest < ActionDispatch::IntegrationTest
    test "serves the stylesheet with long-lived caching" do
      get "/job_board/assets/application.css"

      assert_response :success
      assert_equal "text/css", response.media_type
      assert_match "max-age=31556952", response.headers["Cache-Control"]
      assert_match "--bg", response.body
    end

    test "serves the javascript" do
      get "/job_board/assets/application.js"

      assert_response :success
      assert_equal "text/javascript", response.media_type
      assert_match "data-poll-region", response.body
    end

    test "serves the throughput chart stylesheet" do
      get "/job_board/assets/throughput_chart.css"

      assert_response :success
      assert_equal "text/css", response.media_type
      assert_match ".throughput-chart", response.body
    end

    test "serves the throughput chart javascript" do
      get "/job_board/assets/throughput_chart.js"

      assert_response :success
      assert_equal "text/javascript", response.media_type
      assert_match "throughput-chart", response.body
    end

    test "unknown assets are not found" do
      get "/job_board/assets/other.css"
      assert_response :not_found
    end

    test "path traversal is rejected by the route constraint" do
      get "/job_board/assets/..%2f..%2fconfig%2froutes.rb"
      assert_response :not_found
    rescue ActionController::RoutingError
      assert true
    end
  end
end
