module JobBoard
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :authenticate

    layout "job_board/application"

    private
      def authenticate
        credentials = JobBoard.config.http_basic_auth
        return unless credentials

        authenticate_or_request_with_http_basic("JobBoard") do |name, password|
          ActiveSupport::SecurityUtils.secure_compare(name, credentials[:name].to_s) &
            ActiveSupport::SecurityUtils.secure_compare(password, credentials[:password].to_s)
        end
      end

      def stale_threshold
        JobBoard.config.stale_process_threshold || SolidQueue.process_alive_threshold
      end
  end
end
