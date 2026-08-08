# frozen_string_literal: true

require "test_helper"

module JobBoard
  class AuthenticationTest < ActionDispatch::IntegrationTest
    teardown do
      JobBoard.config.http_basic_auth = nil
    end

    test "pages are open when no basic auth is configured" do
      get "/job_board/queues"
      assert_response :success
    end

    test "configured basic auth rejects missing credentials" do
      JobBoard.config.http_basic_auth = { name: "admin", password: "secret" }

      get "/job_board/queues"

      assert_response :unauthorized
    end

    test "configured basic auth accepts valid credentials" do
      JobBoard.config.http_basic_auth = { name: "admin", password: "secret" }

      get "/job_board/queues", headers: {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret")
      }

      assert_response :success
    end

    test "configured basic auth rejects wrong credentials" do
      JobBoard.config.http_basic_auth = { name: "admin", password: "secret" }

      get "/job_board/queues", headers: {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "nope")
      }

      assert_response :unauthorized
    end
  end
end
